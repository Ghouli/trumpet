defmodule Trumpet.Stocks do
  alias Trumpet.Bot
  alias Trumpet.Commands
  require Logger

  def round_number(nil, _), do: nil
  def round_number(number, accuracy) do
    number
    |> Decimal.new
    |> Decimal.round(accuracy)
  end

  def parse_stock_response(nil) do
    "Not found."
  end

  def parse_stock_response(data) do
    stock = data["basicQuote"]
    if stock["price"] != nil do
      id = stock["id"] |> String.split(":")
      name = stock["name"]
      price = stock["price"] |> round_number(2)
      exchange = "#{stock["primaryExchange"]}, "
      currency = stock["issuedCurrency"]
      price_ch = stock["priceChange1Day"] |> round_number(2)
      percent_ch = stock["percentChange1Day"] |> round_number(2)
      percent_string =
        case String.starts_with?("#{percent_ch}", "-") do
          true  -> "\x0305#{percent_ch}%\x0F"
          false -> "\x0303+#{percent_ch}%\x0F"
        end
      volume =
        case is_nil(stock["volume"]) do
          true  -> data["detailedQuote"]["volume"]
          false -> stock["volume"]
      end
      epoch = stock["lastUpdateEpoch"]
      offset = stock["timeZoneOffset"]
      last_update = epoch
                    |> Commands.unix_to_datetime
                    |> Timex.shift(hours: offset)
                    |> Timex.format!("{h24}:{m} {D}.{M}.{YYYY}")
      ext_hrs_market = get_after_hrs_market(id)
      year_low = stock["lowPrice52Week"]
      year_high = stock["highPrice52Week"]
      year_change =
        case stock["totalReturn1Year"] == nil do
          true -> ""
          false -> stock["totalReturn1Year"] |> round_number(2)
        end
      year_change =
        case String.starts_with?("#{year_change}", "-") do
          true  -> "\x0305#{year_change}%\x0F"
          false -> "\x0303+#{year_change}%\x0F"
        end
      year_string =
        case stock["totalReturn1Year"] == nil do
          true -> ""
          false -> "return: #{year_change}, "
        end
      "#{name}, #{exchange}#{price} #{currency} #{price_ch} (#{percent_string}), volume: #{volume}, " <>
      "52w #{year_string}range: #{year_low} - #{year_high}, last update: #{last_update}#{ext_hrs_market}"
      #"52w return: #{year_change}, range: #{year_low} - #{year_high}, last update: #{last_update}#{ext_hrs_market}"
    end
  end

  def get_after_hrs_market(id) do
    if Enum.at(id, 1) == "US" do
      response = HTTPoison.get!("http://finance.google.com/finance/info?q=#{Enum.at(id, 0)}")
      if response.status_code == 200 do
        data = response.body |> String.trim_leading("\n//") |> Poison.Parser.parse! |> List.first
        keys = ["lt", "elt", "el", "ec", "ecp"]
        if keys |> Enum.all?(&(Map.has_key?(data, &1))) do
          last_trade = data["lt"] |> Timex.parse!("{Mshort} {D}, {h12}:{m}{AM} {Zabbr}")
          last_pre_market = data["elt"] |> Timex.parse!("{Mshort} {D}, {h12}:{m}{AM} {Zabbr}")
          if Timex.before?(last_trade, last_pre_market) do
            prefix =
              case Timex.diff(last_pre_market, last_trade, :hours) >= 12 do
                true  -> "pre"
                false -> "post"
              end
            pre_market_price = data["el"]
            pre_market_change = data["ec"]
            pre_market_percentage = "#{data["ecp"]}%"
            pre_market_time = last_pre_market |> Timex.format!("{h24}:{m} {D}.{M}")
            pre_market_percentage =
            case String.starts_with?(pre_market_percentage, "-") do
               true  -> pre_market_percentage
               false -> "+#{pre_market_percentage}"
            end
            "; #{prefix}-market: #{pre_market_price} #{pre_market_change} (#{pre_market_percentage}), #{pre_market_time}"
          end
        end
      end
    else
      ""
    end
  end

  def get_stock_response([]) do
    "Not found."
  end

  def get_stock_response(stocks) do
    stock = stocks
            |> List.first
            |> String.split("quote/")
            |> Enum.reverse
            |> List.first
            |> String.replace("\" ", "")
    url = "https://www.bloomberg.com/markets/api/quote-page/#{stock}?locale=en"
    response = HTTPoison.get!(url).body |> Poison.Parser.parse!
    case is_nil(response["basicQuote"]) do
      true  -> "Not found."
      false -> case is_nil(response["basicQuote"]["price"]) do
                 true  -> stocks |> List.delete_at(0) |> get_stock_response
                 false -> response
               end
    end
  end

  def get_stock_msg(stocks) do
    case stocks != nil do
      true ->
        stocks |> get_stock_response |> parse_stock_response
      false -> "Not found."
    end
  end

  def get_stocks(search_result) do
    search_result
    |> Floki.find("cite")
    |> Floki.text
    |> String.replace("https://", "")
    |> String.split("www")
    |> List.delete_at(0)
    |> Enum.reject(fn (item) -> !String.contains?(item, "/quote/") end)
  end

  def get_quote(arg) do
    HTTPoison.get!("https://www.google.fi/search?q=#{arg}+bloomberg.com").body
    |> Codepagex.to_string!(:iso_8859_15)
    |> get_stocks
    |> get_stock_msg
  end

  def get_index(arg) do
    arg ++ ["index"]
    |> Enum.join("+")
    |> get_quote()
  end

  def get_stock(arg) do
    arg ++ ["stock"]
    |> Enum.join("+")
    |> get_quote()
  end
end
