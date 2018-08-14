defmodule Trumpet.Stocks do
  defmodule Stock do
    defstruct name: "",
              price: "",
              exchange: "",
              currency: "",
              price_change: "",
              percent_change: "",
              volume: "",
              last_update_local: "",
              ext_hours_market: "",
              year_low: "",
              year_high: "",
              year_range: "",
              year_change: "",
              morningstar: ""
  end
  alias Poison.Parser
  alias Trumpet.Utils
  require Logger

  defp get_percent_change(json) do
    change = round_by(json["percentChange1Day"], 2)

    case String.starts_with?("#{change}", "-") do
      true -> "(\x0305#{change}%\x0F)"
      false -> "(\x0303+#{change}%\x0F)"
    end
  end

  defp get_volume(data) do
    case is_nil(data["basicQuote"]["volume"]) do
      true -> data["detailedQuote"]["volume"]
      false -> data["basicQuote"]["volume"]
    end
  end

  defp get_last_update_local(json) do
    json["lastUpdateEpoch"]
    |> Utils.unix_to_datetime()
    |> Timex.shift(hours: json["timeZoneOffset"])
    |> Timex.format!("{h24}:{m} {D}.{M}.{YYYY}")
  end

  defp get_year_change(nil), do: ""

  defp get_year_change(year_return) do
    year_return = round_by(year_return, 2)

    case String.starts_with?("#{year_return}", "-") do
      true -> "52w return: \x0305#{year_return}%\x0F, "
      false -> "52w return: \x0303+#{year_return}%\x0F, "
    end
  end

  defp get_year_range(nil, nil), do: ""

  defp get_year_range(year_low, year_high) do
    "range: #{year_low} - #{year_high}, "
  end

  defp round_by(float, by), do: Utils.round_by(float, by)

  def construct_stock(data) do
    json = data["basicQuote"]

    %Stock{
      name: json["name"],
      price: round_by(json["price"], 2),
      exchange: json["primaryExchange"],
      currency: json["issuedCurrency"],
      price_change: round_by(json["priceChange1Day"], 2),
      percent_change: get_percent_change(json),
      volume: get_volume(data),
      last_update_local: get_last_update_local(json),
      ext_hours_market: get_after_hrs_market(json),
      year_low: json["lowPrice52Week"],
      year_high: json["highPrice52Week"],
      year_range: get_year_range(json["lowPrice52Week"], json["highPrice52Week"]),
      year_change: get_year_change(json["totalReturn1Year"]),
      morningstar: get_morningstar(json)
    }
  end

  def parse_stock_response(nil), do: "Not found."
  def parse_stock_response("Not found."), do: ""

  def parse_stock_response(data) do
    if data["basicQuote"]["price"] != nil do
      stock = construct_stock(data)

      "#{stock.name}, #{stock.exchange}, #{stock.price} #{stock.currency} " <>
        "#{stock.price_change} #{stock.percent_change}, volume: #{stock.volume}, " <>
        "#{stock.year_change}#{stock.year_range}last update: " <>
        "#{stock.last_update_local}#{stock.ext_hours_market} #{stock.morningstar}"
    end
  end

  def get_morningstar(json) do
    id =
      json["id"]
      |> String.split(":")
      |> List.first()
      |> String.downcase()

    name = json["name"]

    result =
      "#{id} #{name} quote morningstar"
      |> Utils.google_search()
      |> List.first()

    url = String.downcase(result.url)

    case String.ends_with?(url, "quote.html") && String.contains?(url, id) do
      true -> Utils.url_shorten("#{url}\#sal-components-financials")
      false -> ""
    end
  end

  def get_after_hrs_market(id) do
    if Enum.at(id, 1) == "US" do
      response = HTTPoison.get!("http://finance.google.com/finance/info?q=#{Enum.at(id, 0)}")

      if response.status_code == 200 do
        data =
          response.body
          |> String.trim_leading("\n//")
          |> Parser.parse!()
          |> List.first()

        keys = ["lt", "elt", "el", "ec", "ecp"]

        if keys |> Enum.all?(&Map.has_key?(data, &1)) do
          last_trade = Timex.parse!(data["lt"], "{Mshort} {D}, {h12}:{m}{AM} {Zabbr}")
          last_pre_market = Timex.parse!(data["elt"], "{Mshort} {D}, {h12}:{m}{AM} {Zabbr}")

          if Timex.before?(last_trade, last_pre_market) do
            prefix =
              case Timex.diff(last_pre_market, last_trade, :hours) >= 12 do
                true -> "pre"
                false -> "post"
              end

            pre_market_price = data["el"]
            pre_market_change = data["ec"]
            pre_market_percentage = "#{data["ecp"]}%"
            pre_market_time = Timex.format!(last_pre_market, "{h24}:{m} {D}.{M}")

            pre_market_percentage =
              case String.starts_with?(pre_market_percentage, "-") do
                true -> pre_market_percentage
                false -> "+#{pre_market_percentage}"
              end

            "; #{prefix}-market: #{pre_market_price} #{pre_market_change} " <>
              "(#{pre_market_percentage}), #{pre_market_time}"
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
    stock =
      stocks
      |> List.first()
      |> String.split("quote/")
      |> Enum.reverse()
      |> List.first()
      |> String.replace("\" ", "")

    url = "https://www.bloomberg.com/markets/api/quote-page/#{stock}?locale=en"
    response = HTTPoison.get!(url).body |> Parser.parse!()

    case is_nil(response["basicQuote"]) do
      true ->
        "Not found."

      false ->
        case is_nil(response["basicQuote"]["price"]) do
          true ->
            stocks
            |> List.delete_at(0)
            |> get_stock_response()

          false ->
            response
        end
    end
  end

  def get_stock_msg(stocks) do
    case stocks != nil do
      true ->
        stocks
        |> get_stock_response()
        |> parse_stock_response()

      false ->
        "Not found."
    end
  end

  def get_stocks(search_result) do
    search_result
    |> Enum.map(fn %{title: _title, url: url} -> url end)
    |> Enum.reject(fn item -> !String.contains?(item, "/quote/") end)
  end

  def get_quote(arg) do
    "#{arg} bloomberg.com"
    |> Utils.google_search()
    |> get_stocks()
    |> get_stock_msg()
  end

  def get_index(arg) do
    (arg ++ ["index"])
    |> Enum.join("+")
    |> get_quote()
  end

  def get_stock(arg) do
    (arg ++ ["stock"])
    |> Enum.join("+")
    |> get_quote()
  end

  def get_historical_data(url) do
    url = String.trim_trailing(url, "/")
    now = Timex.now()
    start = 946_684_800
    #      now
    #      |> Timex.shift(years: -11)
    #      |> Timex.to_unix()
    stop = Timex.to_unix(now)

    url =
      "#{url}/history?period1=#{start}&period2=#{stop}&interval=1d&filter=history&frequency=1d"

    case HTTPoison.get(url) do
      {:ok, page} ->
        case String.contains?(page.body, "isPending") do
          true ->
            page.body
            |> Floki.find("script")
            |> Floki.raw_html()
            |> String.split("\"prices\":")
            |> Enum.at(1)
            |> String.split(",\"isPending")
            |> List.first()

          false ->
            ""
        end

      {:error, _page} ->
        ""
    end
  end

  def build_csv_strings(data) do
    csv_data =
      data
      |> Enum.map(fn item -> Utils.keys_to_atom(item) end)
      |> Enum.reject(fn item -> Map.has_key?(item, :type) end)
      |> Enum.map(fn item ->
        "#{Timex.to_date(Timex.from_unix(item.date))},#{item.close},#{item.adjclose}"
      end)
      |> Enum.reverse()

    (["date,close,adjclose"] ++ csv_data)
    |> Enum.join("\n")

    # ["date,open,close,high,low,adjclose,volume\n"] ++ csv_data
  end

  def write_csv_file(filename, csv_data) do
    path =
      case String.ends_with?(Application.get_env(:trumpet, :csv_location), "/") do
        true -> Application.get_env(:trumpet, :csv_location)
        false -> "#{Application.get_env(:trumpet, :csv_location)}/"
      end

    path = "#{path}#{filename}"
    File.write(path, csv_data)
  end

  def write_and_get_url(symbol, csv_data) do
    filename = "#{symbol}-#{Date.utc_today()}.csv"

    write_csv_file(filename, csv_data)

    case String.ends_with?(Application.get_env(:trumpet, :self_address), "/") do
      true -> "#{Application.get_env(:trumpet, :self_address)}#{filename}"
      false -> "#{Application.get_env(:trumpet, :self_address)}/#{filename}"
    end
  end

  def get_yahoo_pages(search_result) do
    search_result
    |> Enum.map(fn %{title: _title, url: url} -> url end)
    |> Enum.reject(fn item -> !String.starts_with?(item, "https://finance.yahoo.com/quote/") end)
  end

  # Get stock history data from Yahoo finance
  def get_stock_history(arg) do
    link =
      "#{arg} yahoo finance"
      |> Utils.google_search()
      |> get_yahoo_pages()
      |> List.first()

    csv =
      link
      |> get_historical_data()
      |> build_csv_strings()

    symbol =
      link
      |> String.trim_trailing("/")
      |> String.split("/")
      |> Enum.reverse()
      |> List.first()

    write_and_get_url(symbol, csv)
  end

  def file_to_csv(file) do
    IO.puts(file)

    filename =
      file
      |> String.split("/")
      |> Enum.reverse()
      |> List.first()
      |> String.split(".")
      |> Enum.reverse()
      |> List.delete_at(0)
      |> Enum.reverse()
      |> Enum.join(".")

    json = file |> File.read!() |> Poison.decode!()
    csv = build_csv_strings(json)
    File.write("/home/ghouli/stock_data/csv/#{filename}.csv", csv)
  end

  def files_to_csv do
    "/home/ghouli/stock_data/*.json"
    |> Path.wildcard()
    |> Enum.each(fn file ->
      # Task.start(__MODULE__, :file_to_csv, [file])
      file_to_csv(file)
    end)
  end

  def start_leech do
    [_ | tail] =
      HTTPoison.get!(
        "https://raw.githubusercontent.com/datasets/s-and-p-500-companies/master/data/constituents.csv"
      ).body
      |> String.split("\n")

    tail
    |> Enum.each(fn item ->
      [ticker | rest] = String.split(item, ",")
      Task.start(__MODULE__, :leech, [ticker, rest])
      # :timer.sleep(500)
      # task = Task.async(__MODULE__, :leech, [ticker, rest])
      # Task.await(task)
    end)
  end

  def leech(ticker, rest) do
    sector = rest |> Enum.reverse() |> List.first()
    name = rest |> Enum.reverse() |> List.delete_at(0) |> Enum.reverse() |> Enum.join(",")
    filename = "/home/ghouli/stock_data/#{ticker}-#{name}-#{sector}.json"

    case File.exists?(filename) do
      # IO.puts "."
      true ->
        ""

      false ->
        :timer.sleep(:rand.uniform(10000))
        IO.puts("#{ticker} started")

        url =
          "#{name} yahoo finance"
          |> Utils.google_search()
          |> get_yahoo_pages()
          |> List.first()

        # url = "https://finance.yahoo.com/quote/#{ticker}"
        # :timer.sleep(:rand.uniform(10000))
        data = get_historical_data(url)
        File.write(filename, data)

        case data == "" do
          true -> IO.puts("#{ticker} failed!")
          false -> IO.puts("#{ticker} ok")
        end
    end
  end
end
