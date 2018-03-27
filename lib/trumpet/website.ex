defmodule Trumpet.Website do
alias Trumpet.Utils

  def website({:ok, page}) do
    website(page)
  end

  def website({:error, _}) do
    %{url:            "",
      title:          "",
      description:    "",
      og_title:       "",
      og_site:        "",
      og_description: ""
     }
  end

  def website(page) do
    %{url:            page.request_url,
      title:          page.body |> Floki.find("title") |> Floki.raw_html() |> String.split("<\/title>") |> List.first(),
      description:    page.body |> Floki.find("description") |> Floki.text(),
      og_title:       page.body |> Utils.floki_helper("meta[property='og:title']"),
      og_site:        page.body |> Utils.floki_helper("meta[property='og:site_name']"),
      og_description: page.body |> Utils.floki_helper("meta[property='og:description']")
     }
  end

  def get_website(url) do
    url
    |> HTTPoison.get([], [follow_redirect: true])
    |> website()
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
        true -> url
          #|> String.trim_leading("“")
          #|> String.trim_trailing("”")
      end
    website = get_website(url)
    title =
      cond do
        website.og_site == "Twitch" -> "#{website.og_title} - #{website.og_description}"
        website.og_site == "Twitter" -> "#{website.og_title}: #{website.og_description}"
        website.og_title != nil
          && String.length(website.og_title) > String.length(website.title) -> website.og_title
        true -> website.title
      end
    title
    |> Utils.clean_string()
    |> String.replace("Imgur: The most awesome images on the Internet", "")
    |> String.replace("Twitter / ?", "")
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
