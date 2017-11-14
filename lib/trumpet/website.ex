defmodule Trumpet.Website do
alias Trumpet.Utils

  def get_website({:ok, page}) do
    %{url:            page.request_url,
      title:          page.body |> Floki.find("title") |> Floki.text(),
      description:    page.body |> Floki.find("description") |> Floki.text(),
      og_title:       page.body |> Utils.floki_helper("meta[property='og:title']"),
      og_site:        page.body |> Utils.floki_helper("meta[property='og:site_name']"),
      og_description: page.body |> Utils.floki_helper("meta[property='og:description']")
     } 
  end 

  def get_website(page) do
    %{url:            page.request_url,
      title:          page.body |> Floki.find("title") |> Floki.text(),
      description:    page.body |> Floki.find("description") |> Floki.text(),
      og_title:       page.body |> Utils.floki_helper("meta[property='og:title']"),
      og_site:        page.body |> Utils.floki_helper("meta[property='og:site_name']"),
      og_description: page.body |> Utils.floki_helper("meta[property='og:description']")
     }
  end 
end