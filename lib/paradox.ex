defmodule Trumpet.Paradox do
  defmodule DevDiary do
    defstruct id: nil,
              url: nil,
              title: nil,
              description: nil
  end

  alias Trumpet.Bot

  def get_latest_devdiaries(url) do
    HTTPoison.get!("#{url}").body
    |> Floki.find(".wikitable")
    |> List.first
  end

  def construct_devdiary_map(table) do
    titles = table
             |> Floki.find(".extiw")
             |> Enum.map(fn (item) -> Tuple.to_list(item) |> List.flatten |> Enum.reverse |> List.first end)
    urls = table
           |> Floki.find(".extiw")
           |> Floki.attribute("href")
    descriptions = table
                   |>Floki.find("td")
                   |> Floki.text
                   |> String.split("\n")
                   |> Enum.map(fn (item) -> String.split(item, "  ") |> List.first |> String.trim end)
    diaries = Enum.zip([titles, urls, descriptions])
              |> Enum.map(fn {title, url, desc} -> 
                  id = url |> String.split("/") |> Enum.reverse |> List.first
                  diary = %DevDiary{id: id, url: url, title: title, description: desc}
                end)
              |> Enum.reduce(%{}, fn (diary, acc) ->
                  Map.put(acc, String.to_integer(diary.id), diary)
                end)
  end

  def get_hoi4_devdiaries() do
    "http://www.hoi4wiki.com/Developer_diaries"
    |> get_latest_devdiaries()
    |> construct_devdiary_map()
  end

  def get_stellaris_devdiaries() do
    "http://www.stellariswiki.com/Developer_diaries"
    |> get_latest_devdiaries()
    |> construct_devdiary_map()
  end

  def get_ck2_devdiaries() do
    "http://www.ckiiwiki.com/Developer_diaries"
    |> get_latest_devdiaries()
    |> construct_devdiary_map()
  end

  def get_eu4_devdiaries() do
    "http://www.eu4wiki.com/Developer_diaries"
    |> get_latest_devdiaries()
    |> construct_devdiary_map()
  end

  def get_last_devdiary(map) do
    key = Map.keys(map)
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

  def check_ck2_devdiary() do
    new_diaries = get_ck2_devdiaries()
    new_last = new_diaries
               |> get_last_devdiary()
    old_last = Bot.get_ck2_devdiary_map()
               |> get_last_devdiary()
    if new_last.id != old_last.id do
      Bot.update_ck2_devdiary_map(new_last)
      devdiary_string = get_devdiary_string(new_last, "CK2")
      Bot.get_devdiary_channels()
      |> Enum.each(fn (channel) -> Bot.msg_to_channel(devdiary_string, channel) end)
    end
  end

  def check_eu4_devdiary() do
    new_diaries = get_eu4_devdiaries()
    new_last = new_diaries
               |> get_last_devdiary()
    old_last = Bot.get_eu4_devdiary_map()
               |> get_last_devdiary()
    if new_last.id != old_last.id do
      Bot.update_eu4_devdiary_map(new_last)
      devdiary_string = get_devdiary_string(new_last, "EU4")
      Bot.get_devdiary_channels()
      |> Enum.each(fn (channel) -> Bot.msg_to_channel(devdiary_string, channel) end)
    end 
  end

  def check_hoi4_devdiary() do
    new_diaries = get_hoi4_devdiaries()
    new_last = new_diaries
               |> get_last_devdiary()
    old_last = Bot.get_hoi4_devdiary_map()
               |> get_last_devdiary()
    if new_last.id != old_last.id do
      Bot.update_hoi4_devdiary_map(new_last)
      devdiary_string = get_devdiary_string(new_last, "HoI4")
      Bot.get_devdiary_channels()
      |> Enum.each(fn (channel) -> Bot.msg_to_channel(devdiary_string, channel) end)
    end   
  end

  def check_stellaris_devdiary() do
    new_diaries = get_stellaris_devdiaries()
    new_last = new_diaries
               |> get_last_devdiary()
    old_last = Bot.get_stellaris_devdiary_map()
               |> get_last_devdiary()
    if new_last.id != old_last.id do
      Bot.update_stellaris_devdiary_map(new_last)
      devdiary_string = get_devdiary_string(new_last, "Stellaris")
      Bot.get_devdiary_channels()
      |> Enum.each(fn (channel) -> Bot.msg_to_channel(devdiary_string, channel) end)
    end
  end
end