defmodule Trumpet.IEXTradingApi do
  alias Trumpet.Stocks.Stock

  defp get_year_range(nil, nil), do: ""

  defp get_year_range(year_low, year_high) do
    "#{year_low} - #{year_high}"
  end

  def parse_data(stock, stats) do
    %Stock{
      name: stock["companyName"],
      price: stock["latestPrice"],
      exchange: stock["primaryExchange"],
      currency: "",
      price_change: stock["change"],
      percent_change: stock["changePercent"],
      volume: stock["latestVolume"],
      last_update_local: "",
      ext_hours_market: "",
      year_low: stock["week52Low"],
      year_high: stock["week52High"],
      year_range: get_year_range(stock["week52Low"], stock["week52High"]),
      year_change: stats["week52change"],
      morningstar: ""
    }
  end

  def stock_response(nil), do: "Not found."
  def stock_response("Not found."), do: ""

  def stock_response(stock) do
    if stock.name != nil do

      "#{stock.name}, #{stock.exchange}, #{stock.price}, " <>
        "#{stock.price_change}, #{stock.percent_change}%, volume: #{stock.volume}, " <>
        "52w change: #{stock.year_change}, 52w range: #{stock.year_range}" <>
        ""
    end
  end

  def fetch_stock(symbol) do
    stock =
      HTTPoison.get!("https://api.iextrading.com/1.0/stock/#{symbol}/quote").body
      |> Poison.Parser.parse!()
    stats =
      HTTPoison.get!("https://api.iextrading.com/1.0/stock/#{symbol}/stats").body
      |> Poison.Parser.parse!()
    parse_data(stock, stats)
    |> stock_response()
  end

  def get_stock(arg) do
  end
end
