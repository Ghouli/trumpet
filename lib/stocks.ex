defmodule Trumpet.Stocks do
  alias Trumpet.Bot
  require Logger

  def parse_stock_response(nil) do
    "Not found."
  end

  def parse_stock_response(data) do
    stock = data["basicQuote"]
    if stock["price"] != nil do
      name = stock["name"]
      price = stock["price"] |> Decimal.new |> Decimal.round(2)
      exchange =
        cond do
          stock["primaryExchange"] != "" -> "#{stock["primaryExchange"]}, "
          true -> ""
        end
      currency = stock["issuedCurrency"]
      price_ch = stock["priceChange1Day"] |> Decimal.new |> Decimal.round(2)
      percent_ch = stock["percentChange1Day"] |> Decimal.new |> Decimal.round(2)
      percent_string = "#{percent_ch}%"
      if String.first(percent_string) != "-" do
        percent_string = "+#{percent_string}"
      end
      volume = stock["volume"]
      if volume == nil do
        volume = data["detailedQuote"]["volume"]
      end
      epoch = stock["lastUpdateEpoch"]
      offset = stock["timeZoneOffset"]
      last_update = epoch
                  |> Bot.unix_to_datetime
                  |> Timex.shift(hours: offset)
                  |> Timex.format!("{h24}:{m} {D}.{M}.{YYYY}")
      "#{name}, #{exchange}#{price} #{currency} #{price_ch} (#{percent_string}), volume: #{volume}, last update: #{last_update}"
    end
  end

  def get_stock_response([]) do
    nil
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
    cond do
      response["basicQuote"] == nil -> "Not found."
      response["basicQuote"] != nil ->
        if response["basicQuote"]["price"] == nil do
          response = stocks
                     |> List.delete_at(0)
                     |> get_stock_response
        end
        response
      true -> "Not found."
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
