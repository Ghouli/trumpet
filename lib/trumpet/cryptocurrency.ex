defmodule Trumpet.Cryptocurrency do
  def fetch_json do    
    HTTPoison.get!("https://api.coinmarketcap.com/v1/ticker/?convert=EUR&limit=0").body
    |> Poison.Parser.parse!()
  end

  def keys_to_atom(map) do
    for {key, val} <- map, into: %{}, do: {String.to_atom(key), val}
  end

  def get_coin_quote(coin) do
    coin = String.downcase(coin)
    fetch_json()
    |> Enum.reduce([], fn (item, acc) -> item
      case String.contains?(item["id"], coin)
        || String.contains?(String.downcase(item["symbol"]), coin)
        || String.contains?(String.downcase(item["name"]), coin) do
        true  -> [item | acc]
        false -> acc
      end
    end)
    |> Enum.reverse()
    |> List.first()
    |> keys_to_atom()
  end

  defp round_by(float), do: Trumpet.Utils.round_by(String.to_float(float), 2)

  defp get_percent_change(change) do
    case String.starts_with?("#{change}", "-") do
      true  -> "\x0305#{change}%\x0F"
      false -> "\x0303+#{change}%\x0F"
    end
  end

  def get_coin(coin, currency) do
    data = coin
      |> Enum.join(" ")
      |> get_coin_quote()
    price =
      case currency == "EUR" do
        true  -> "#{round_by(data.price_eur)}€"
        false -> "$#{round_by(data.price_usd)}"
      end
    "#{data.name} (#{data.symbol}) #{price} "<>
    "day: #{get_percent_change(data.percent_change_24h)}, "<>
    "week: #{get_percent_change(data.percent_change_7d)}"
  end
end
