defmodule Trumpet.Cryptocurrency do
  alias Trumpet.Utils

  def fetch_json do
    HTTPoison.get!("https://api.coinmarketcap.com/v1/ticker/?convert=EUR&limit=0").body
    |> Poison.Parser.parse!()
  end

  def get_coin_quote(coin) do
    coin = String.downcase(coin)

    fetch_json()
    |> Enum.filter(fn item ->
      String.contains?(item["id"], coin) ||
        String.contains?(String.downcase(item["symbol"]), coin) ||
        String.contains?(String.downcase(item["name"]), coin)
    end)
    |> List.first()
    |> Utils.keys_to_atom()
  end

  defp round_by(float_string) do
    float = String.to_float(float_string)

    cond do
      float > 1 -> Number.Delimit.number_to_delimited(float)
      float > 0.1 -> Trumpet.Utils.round_by(float, 3)
      float > 0.01 -> Trumpet.Utils.round_by(float, 4)
      float > 0.001 -> Trumpet.Utils.round_by(float, 5)
      true -> float_string
    end
  end

  defp get_percent_change(change) do
    case String.starts_with?("#{change}", "-") do
      true -> "\x0305#{change}%\x0F"
      false -> "\x0303+#{change}%\x0F"
    end
  end

  def get_old_price(price_now, change_percent) do
    price_now / ((100 + change_percent) / 100)
  end

  def calc_price_change_percent(old_price, new_price) do
    Trumpet.Utils.round_by((new_price - old_price) / old_price * 100, 2)
  end

  def calculate_difference(data, btc) do
    btc_price = String.to_float(btc.price_usd)
    btc_change_24h = String.to_float(btc.percent_change_24h)
    btc_change_7d = String.to_float(btc.percent_change_7d)
    btc_price_day_ago = get_old_price(btc_price, btc_change_24h)
    btc_price_week_ago = get_old_price(btc_price, btc_change_7d)

    alt_price = String.to_float(data.price_usd)
    alt_price_btc = String.to_float(data.price_btc)
    alt_change_24h = String.to_float(data.percent_change_24h)
    alt_change_7d = String.to_float(data.percent_change_7d)
    alt_price_day_ago = get_old_price(alt_price, alt_change_24h)
    alt_price_day_ago_btc = alt_price_day_ago / btc_price_day_ago
    alt_price_week_ago = get_old_price(alt_price, alt_change_7d)
    alt_price_week_ago_btc = alt_price_week_ago / btc_price_week_ago

    price_change_day = calc_price_change_percent(alt_price_day_ago_btc, alt_price_btc)
    price_change_week = calc_price_change_percent(alt_price_week_ago_btc, alt_price_btc)

    "day: #{get_percent_change(price_change_day)}, " <>
      "week #{get_percent_change(price_change_week)}"
  end

  def get_price_in_btc(data) do
    btc = get_coin_quote("BTC")
    " - #{round_by(data.price_btc)} BTC " <> calculate_difference(data, btc)
  end

  def get_coin(coin, currency) do
    data =
      coin
      |> Enum.join(" ")
      |> get_coin_quote()

    price =
      case currency == "EUR" do
        true -> "#{round_by(data.price_eur)}€"
        false -> "$#{round_by(data.price_usd)}"
      end

    price_in_btc =
      case data.symbol == "BTC" do
        true -> ""
        false -> get_price_in_btc(data)
      end

    volume =
      data."24h_volume_usd"
      # (String.to_float(data."24h_volume_usd") / String.to_float(data.price_usd))
      |> Number.Delimit.number_to_delimited()
      |> String.trim_trailing(".00")

    market_cap =
      data.market_cap_usd
      |> Number.Delimit.number_to_delimited()
      |> String.trim_trailing(".00")

    "#{data.name} (#{data.symbol}) #{price} " <>
      "day: #{get_percent_change(data.percent_change_24h)}, " <>
      "week: #{get_percent_change(data.percent_change_7d)}, " <>
      "volume: $#{volume}, " <> "market cap: $#{market_cap}" <> price_in_btc
  end
end
