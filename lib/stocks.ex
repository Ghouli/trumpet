defmodule Trumpet.Stocks do
  alias Trumpet.Bot

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
      update_time = stock["lastUpdateTime"]
      update_date = stock["priceDate"]
      "#{name}, #{exchange}#{price} #{currency} #{price_ch} (#{percent_string}), volume: #{volume}, last update: #{update_time} #{update_date}"
    end
  end

  def get_index(arg) do
    search_string = "https://www.google.fi/search?as_q=#{arg}+index&as_sitesearch=bloomberg.com"
    search_result = HTTPoison.get!(search_string).body |> Codepagex.to_string!(:iso_8859_15)    
    stock = search_result |> Floki.find("cite") |> Floki.text |> String.replace("https://", "") |> String.split("www") |> List.delete_at(0)
    if stock != nil do
      stock = stock
              |> List.first
              |> String.split("/")
              |> Enum.reverse
              |> List.first
              |> String.replace("\" ", "")
      url = "https://www.bloomberg.com/markets/api/quote-page/#{stock}?locale=en"
      response = HTTPoison.get!(url).body |> Poison.Parser.parse!
      stock_price_string =
        cond do
          response["basicQuote"] == nil -> "Not found."
          response["basicQuote"] != nil ->
            if response["basicQuote"]["price"] == nil do
              stock = search_result |> Floki.find("cite") |> Floki.text |> String.replace("https://", "") |> String.split("www") |> List.delete_at(0)
                    |> List.delete_at(0)
                    |> List.first
                    |> String.split("/")
                    |> Enum.reverse
                    |> List.first
                    |> String.replace("\" ", "")
              url = "https://www.bloomberg.com/markets/api/quote-page/#{stock}?locale=en"
              response = HTTPoison.get!(url).body |> Poison.Parser.parse!
            end
            parse_stock_response(response)
          true -> "Not found."
        end
    end
  end

  def get_stock(arg) do
    search_string = "https://www.google.fi/search?as_q=#{arg}+stock&as_sitesearch=bloomberg.com"
    search_result = HTTPoison.get!(search_string).body |> Codepagex.to_string!(:iso_8859_15)    
    stock = search_result |> Floki.find("cite") |> Floki.text |> String.replace("https://", "") |> String.split("www") |> List.delete_at(0)
    if stock != nil do
      stock = stock
              |> List.first
              |> String.split("/")
              |> Enum.reverse
              |> List.first
              |> String.replace("\" ", "")
      url = "https://www.bloomberg.com/markets/api/quote-page/#{stock}?locale=en"
      response = HTTPoison.get!(url).body |> Poison.Parser.parse!
      stock_price_string =
        cond do
          response["basicQuote"] == nil -> "Not found."
          response["basicQuote"] != nil ->
            if response["basicQuote"]["price"] == nil do
              stock = search_result |> Floki.find("cite") |> Floki.text |> String.replace("https://", "") |> String.split("www") |> List.delete_at(0)
                    |> List.delete_at(0)
                    |> List.first
                    |> String.split("/")
                    |> Enum.reverse
                    |> List.first
                    |> String.replace("\" ", "")
              url = "https://www.bloomberg.com/markets/api/quote-page/#{stock}?locale=en"
              response = HTTPoison.get!(url).body |> Poison.Parser.parse!
            end
            parse_stock_response(response)
          true -> "Not found."
        end
    end
  end
end