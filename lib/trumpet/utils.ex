defmodule Trumpet.Utils do
  # Case insensetive get from Map
  def ci_get_in(nil, _), do: nil
  def ci_get_in({_k, val}, []), do: val
  def ci_get_in({_k, val}, key), do: ci_get_in(val, key)

  def ci_get_in(map, [key | rest]) do
    current_level_map = Enum.find(map, &key_lookup(&1, key))
    ci_get_in(current_level_map, rest)
  end

  def key_lookup({k, _v}, key) when is_binary(k) do
    String.downcase(k) == String.downcase(key)
  end

  def keys_to_atom(map) do
    for {key, val} <- map, into: %{}, do: {String.to_atom(key), val}
  end

  def round_by(float, by), do: :erlang.float_to_binary(float / 1, decimals: by)

  def random_numbers(max, count, min \\ 1) do
    :crypto.rand_seed()

    max
    |> gen_numbers(min)
    |> Enum.take_random(count)
  end

  def gen_numbers(max, min), do: for(n <- min..max, do: n)

  def print_random_numbers(numbers) do
    numbers
    |> Enum.sort()
    |> Enum.map(fn x -> "#{x}" end)
    |> Enum.join(", ")
    |> String.trim_trailing(", ")
  end

  def validate_string(string) do
    case String.valid?(string) do
      true ->
        string

      false ->
        string
        |> :unicode.characters_to_binary(:latin1)
        # That damn – seems to cause problems on some pages. This fixes it.
        |> String.replace(<<0xC3, 0xA2, 0xC2, 0x80, 0xC2, 0x93>>, <<0xE2, 0x80, 0x93>>)
    end
  end

  def clean_string(string) do
    string
    |> validate_string()
    |> String.replace("\n", " ")
    |> Floki.text()
    |> String.replace(~r/ +/, " ")
    |> String.trim()
  end

  def floki_helper(page, property) do
    page
    |> Floki.find(property)
    |> Floki.attribute("content")
    |> List.first()
  end

  def google_search(query) do
    HTTPoison.get!("https://www.google.fi/search?q=#{URI.encode(query)}").body
    |> Floki.find("h3[class='r']")
    |> Floki.raw_html()
    |> String.replace("<h3 class=\"r\">", "")
    |> String.replace("<a href=\"/url?q=", "")
    |> String.trim_trailing("</a></h3>")
    |> String.split("</a></h3>")
    |> Enum.map(&String.split(&1, "\">"))
    |> Enum.reject(fn x -> Enum.count(x) != 2 end)
    |> Enum.map(fn [url, title] ->
      %{
        url:
          url
          |> String.split("&sa=U")
          |> List.first(),
        title: Floki.text(title)
      }
    end)
    |> Enum.reject(fn x -> String.starts_with?(x.url, "<a href=") end)
    |> Enum.map(fn %{url: url, title: title} ->
      %{url: url, title: validate_string(title)}
    end)
  end

  def url_shorten(url) do
    {:api_key, api_key} =
      :trumpet
      |> Application.get_env(:url_shortener_api_key)
      |> List.first()

    response =
      HTTPoison.post!(
        "https://www.googleapis.com/urlshortener/v1/url?key=#{api_key}",
        "{\"longUrl\": \"#{url}\"}",
        [{"Content-Type", "application/json"}]
      ).body
      |> Poison.decode!()

    response["id"]
  end

  def unix_to_datetime(epoch) do
    epoch =
      case is_binary(epoch) do
        true -> String.to_integer(epoch)
        false -> epoch
      end

    Timex.from_unix(epoch)
  end
end
