defmodule Trumpet.Website do
  alias Trumpet.Utils

  def website({:ok, page}) do
    website(page)
  end

  def website({:error, _}) do
    %{
      url: "",
      title: "",
      description: "",
      og_title: "",
      og_site: "",
      og_description: "",
      body: ""
    }
  end

  def website(page) do
    %{
      url: page.request_url,
      title:
        page.body
        |> Floki.find("title")
        |> Enum.map(&Floki.text/1)
        |> Enum.reject(fn(x) -> String.length(x) > 400 end)
        |> Enum.map(&String.trim/1)
        |> Enum.max_by(&String.length/1),
      description: page.body |> Floki.find("description") |> Floki.text(),
      og_title: page.body |> Utils.floki_helper("meta[property='og:title']"),
      og_site: page.body |> Utils.floki_helper("meta[property='og:site_name']"),
      og_description: page.body |> Utils.floki_helper("meta[property='og:description']"),
      body: page.body
    }
  end

  def get_website(url) do
    url
    |> HTTPoison.get([], follow_redirect: true)
    |> website()
  end

  def add_imgur_data(title, website) do
    age =
      website.body
      |> Floki.find("span.date")
      |> Floki.text()

    img = Utils.floki_helper(website.body, "meta[name='twitter:image']")

    headers =
      HTTPoison.head!(img).headers
      |> Enum.into(%{})

    size = Utils.calculate_size_from_bytes(headers["Content-Length"])
    # type = headers["Content-Type"]
    "#{title} - #{size} - #{age} ago"
  end

  def parse_youtube_data(title, response) do
    response = Poison.Parser.parse!(response)

    response = List.first(response["items"])

    views =
      response["statistics"]["viewCount"]
      |> String.to_integer()
      |> Utils.calculate_views(0)

    length =
      response["contentDetails"]["duration"]
      |> String.downcase()
      |> String.trim_leading("pt")

    published =
      response["snippet"]["publishedAt"]
      |> Timex.parse!("{ISO:Extended}")

    # Get age in seconds and form age string
    age =
      DateTime.utc_now()
      |> DateTime.diff(published)
      |> Timex.Duration.from_seconds()
      |> Timex.Duration.to_string()

    years = Regex.run(~r/P(\d+)Y/, age, capture: :all_but_first)
    months = Regex.run(~r/Y(\d+)M/, age, capture: :all_but_first)
    days = Regex.run(~r/M(\d+)D/, age, capture: :all_but_first)
    hours = Regex.run(~r/T(\d+)H/, age, capture: :all_but_first)

    age =
      cond do
        !is_nil(years) -> "#{years}y, #{months}m ago"
        !is_nil(months) -> "#{months}m, #{days}d ago"
        !is_nil(days) -> "#{days}d ago"
        !is_nil(hours) -> "#{hours}h ago"
        true -> "FRESH"
      end

    "#{title} [#{length} - #{views} views - #{age}]"
  end

  def add_youtube_data(title, website) do
    id = website.url |> String.split("?v=") |> Enum.at(1)
    key = Application.get_env(:trumpet, :google_api_key)

    query =
      "https://www.googleapis.com/youtube/v3/videos?id=#{id}" <>
        "&key=#{key}&part=snippet,contentDetails,statistics" <>
        "&fields=items(id,snippet,contentDetails,statistics)"

    {status, response} = HTTPoison.get(query)

    case status != :ok do
      true -> title
      false -> parse_youtube_data(title, response.body)
    end
  end

  def fetch_title(url) do
    url =
      cond do
        Regex.match?(~r/(i.imgur)/, url) ->
          url
          |> String.replace("i.imgur", "imgur")
          |> String.split(".")
          |> Enum.drop(-1)
          |> Enum.join(".")

        String.contains?(url, "https://www.kauppalehti.fi/uutiset/") ->
          String.replace(url, "www.", "m.")

        true ->
          url
          # |> String.trim_leading("“")
          # |> String.trim_trailing("”")
      end

    website = get_website(url)

    title =
      cond do
        website.og_site == "Twitch" ->
          "#{website.og_title} - #{website.og_description}"

        website.og_site == "Twitter" ->
          "#{website.og_title}: #{website.og_description}"

        website.og_title != nil && String.length(website.og_title) > String.length(website.title) ->
          website.og_title

        true ->
          website.title
      end

    title
    |> Utils.clean_string()
    |> String.replace("Imgur: The most awesome images on the Internet", "")
    |> String.replace("Imgur: The magic of the Internet", "")
    |> String.replace("Twitter / ?", "")

    cond do
      String.contains?(url, "imgur") ->
        add_imgur_data(title, website)

      String.contains?(url, "youtube") && String.contains?(url, "watch") ->
        add_youtube_data(title, website)

      true ->
        title
    end
  rescue
    ArgumentError -> nil
    CaseClauseError -> nil
    MatchError -> nil
  end

  def get_description(url) do
    site = get_website(url)
    site.description
  end

  def get_og_description(url) do
    site = get_website(url)
    site.og_description
  end
end
