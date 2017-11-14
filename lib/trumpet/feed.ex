defmodule Trumpet.Feed do

  def get_feed({:ok, page}) do
    page.body
    |> Floki.find("item")
    |> Enum.map(fn (item) ->
      %{title:        item |> Floki.find("title") |> Floki.text(),
        link:         item |> Floki.find("link") |> Floki.text(),
        url:          item |> Floki.find("link") |> Floki.text(),
        description:  item |> Floki.find("description") |> Floki.text() |> Floki.text(),
        creator:      item |> Floki.find("creator") |> Floki.text(),
        guid:         item |> Floki.find("guid") |> Floki.text(),
        uuid:         item |> Floki.find("uuid") |> Floki.text(),
        pub_date:     item |> Floki.find("pubDate") |> Floki.text()
      }
    end)
  end

  def get_feed({:error, _}) do
    %{title:       "",
      link:        "",
      url:         "",
      description: "",
      creator:     "",
      guid:        "",
      uuid:        "",
      pub_date:    ""
      }
  end

  def get_feed(page) do
    page.body
    |> Floki.find("item")
    |> Enum.map(fn (item) ->
      %{title:        item |> Floki.find("title") |> Floki.text(),
        link:         item |> Floki.find("link") |> Floki.text(),
        url:          item |> Floki.find("link") |> Floki.text(),
        description:  item |> Floki.find("description") |> Floki.text() |> Floki.text(),
        creator:      item |> Floki.find("creator") |> Floki.text(),
        guid:         item |> Floki.find("guid") |> Floki.text(),
        uuid:         item |> Floki.find("uuid") |> Floki.text(),
        pub_date:     item |> Floki.find("pubDate") |> Floki.text()
      }
    end)
  end
end