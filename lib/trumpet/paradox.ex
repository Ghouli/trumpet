defmodule Trumpet.Paradox do
  defmodule DevDiary do
    defstruct id: nil,
              url: nil,
              title: nil,
              description: nil
  end

  alias Trumpet.Bot

  defp find_first(nil), do: nil
  defp find_first(diary), do: diary |> Floki.find(".wikitable") |> List.first
  def get_latest_devdiaries(url) do
    options = [hackney: [ssl_options: [ cacertfile: "/etc/ssl/certs/gd_bundle-g2.crt"]]]
    case HTTPoison.get("#{url}", %{}, options) do
      {:ok, response} -> response.body |> find_first()
      {:error, _} -> nil
    end
  end

  def construct_devdiary_map(nil), do: nil
  def construct_devdiary_map(table) do
    titles = table
             |> Floki.find(".extiw")
             |> Enum.map(fn (item) -> 
                          item 
                          |> Tuple.to_list()
                          |> List.flatten()
                          |> Enum.reverse()
                          |> List.first
                        end)
    urls = table
           |> Floki.find(".extiw")
           |> Floki.attribute("href")
    descriptions = table
                   |> Floki.find("td")
                   |> Floki.text
                   |> String.split("\n")
                   |> Enum.map(fn (item) ->
                                item
                                |> String.split("  ")
                                |> List.first
                                |> String.trim
                              end)
    [titles, urls, descriptions]
    |> Enum.zip()
    |> Enum.map(fn {title, url, desc} ->
        id = url |> String.split("/") |> Enum.reverse |> List.first
        %DevDiary{id: id, url: url, title: title, description: desc}
      end)
    |> Enum.reduce(%{}, fn (diary, acc) ->
        Map.put(acc, String.to_integer(diary.id), diary)
      end)
  end

  def get_hoi4_devdiaries() do
    "https://hoi4.paradoxwikis.com/Developer_diaries"
    |> get_latest_devdiaries()
    |> construct_devdiary_map()
  end

  def get_stellaris_devdiaries() do
    "https://stellaris.paradoxwikis.com/Developer_diaries"
    |> get_latest_devdiaries()
    |> construct_devdiary_map()
  end

  def get_ck2_devdiaries() do
    "https://ck2.paradoxwikis.com/Developer_diaries"
    |> get_latest_devdiaries()
    |> construct_devdiary_map()
  end

  def get_eu4_devdiaries() do
    "https://eu4.paradoxwikis.com/Developer_diaries"
    |> get_latest_devdiaries()
    |> construct_devdiary_map()
  end

  def get_last_devdiary(map) do
    key = map
          |> Map.keys()
          |> Enum.sort
          |> Enum.reverse
          |> List.first
    map[key]
  end

  def get_last_ck2() do
    Bot.get_ck2_devdiary_map()
    |> get_last_devdiary()
    |> get_devdiary_string("CK2")
  end

  def get_last_eu4() do
    Bot.get_eu4_devdiary_map()
    |> get_last_devdiary()
    |> get_devdiary_string("EU4")
  end

  def get_last_hoi4() do
    Bot.get_hoi4_devdiary_map()
    |> get_last_devdiary()
    |> get_devdiary_string("HoI4")
  end

  def get_last_stellaris() do
    Bot.get_stellaris_devdiary_map()
    |> get_last_devdiary()
    |> get_devdiary_string("Stellaris")
  end

  def populate_paradox_devdiaries() do
    get_ck2_devdiaries()
    |> Bot.update_ck2_devdiary_map()
    get_eu4_devdiaries()
    |> Bot.update_eu4_devdiary_map()
    get_hoi4_devdiaries()
    |> Bot.update_hoi4_devdiary_map()
    get_stellaris_devdiaries()
    |> Bot.update_stellaris_devdiary_map()
  end

  def get_devdiary_string(diary, game) do
    "#{game}: #{diary.title} - #{diary.url} - #{diary.description}"
  end

  def get_devdiaries(devdiary_atom) do
    cond do
      devdiary_atom == :ck2 -> get_ck2_devdiaries()
      devdiary_atom == :eu4 -> get_eu4_devdiaries()
      devdiary_atom == :hoi4 -> get_hoi4_devdiaries()
      devdiary_atom == :stellaris -> get_stellaris_devdiaries()
      true -> nil
    end
  end

  def check_devdiary(devdiary_atom, game) do
    new_diaries = get_devdiaries(devdiary_atom)
    new_last = new_diaries
               |> get_last_devdiary()
    old_last = devdiary_atom
               |> Bot.get_devdiary_map()
               |> get_last_devdiary()
    if new_last.id != old_last.id do
      Bot.update_devdiary_map(devdiary_atom, new_diaries)
      devdiary_string = get_devdiary_string(new_last, game)
      Bot.get_devdiary_channels()
      |> Enum.each(fn (channel) ->
                    Bot.msg_to_channel(devdiary_string, channel)
                  end)
    end
  end

  def check_ck2_devdiary() do
    check_devdiary(:ck2, "CK2")
  end

  def check_eu4_devdiary() do
    check_devdiary(:eu4, "EU4")
  end

  def check_hoi4_devdiary() do
    check_devdiary(:hoi4, "HoI4")
  end

  def check_stellaris_devdiary() do
    check_devdiary(:stellaris, "Stellaris")
  end
end
