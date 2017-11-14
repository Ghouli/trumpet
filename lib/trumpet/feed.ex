defmodule Trumpet.Feed do

  def get_feed(page) do
    feed = page
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
    case Enum.empty?(feed) do
      true  -> empty()
      false -> feed
    end
  end

  def empty do
    [%{title:       "",
       link:        "",
       url:         "",
       description: "",
       creator:     "",
       guid:        "",
       uuid:        "",
       pub_date:    ""
    }]
  end

  def feed({:ok, page}) do
    page.body
    |> get_feed()
  end

  def feed({:error, _}) do
    empty()
  end

  def feed(page) do
    page.body
    |> feed()
  end
end
