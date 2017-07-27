defmodule Trumpet.Commands do
  alias Trumpet.Bot
  alias Trumpet.Paradox
  alias Trumpet.Stocks
  alias Trumpet.Twitter

  def handle_command(msg, nick, channel) do
    [cmd | args] = msg |> String.split(" ")
    if Enum.empty?(args) do
      args = [""]
    end
    response =
      cond do        
        args |> List.first |> String.starts_with?("sub") ->
          cmd |> subscribe_channel(channel)
        args |> List.first |> String.starts_with?("unsub") ->
          cmd |> unsubscribe_channel(channel)
        true ->
          handle_command(cmd, args, channel, nick)
      end 
    response
    |> Bot.msg_to_channel(channel)
  end

  defp handle_command("!tweet", args, _, _), do: tweet_cmd(args)
  defp handle_command("!fakenews", args, channel, _), do: fakenews_cmd(args, channel)
  defp handle_command("!stock", args, _, _), do: stock_cmd(args)
  defp handle_command("!stocks", args, _, _), do: stock_cmd(args)
  defp handle_command("!börs", args, _, _), do: stock_cmd(args)
  defp handle_command("!pörs", args, _, _), do: stock_cmd(args)
  defp handle_command("!pörssi", args, _, _), do: stock_cmd(args)
  defp handle_command("!index", args, _, _), do: index_cmd(args)
  defp handle_command("!r", args, _, _), do: get_random_redpic(args)
  defp handle_command("!epoch", args, _, _), do: unix_to_localtime(args)
  defp handle_command("!time", args, _, _), do: time_to_local(args)
  defp handle_command("!pelit", args, _, _), do: pelit_cmd(args)

  defp handle_command("!motivation", _, _, _), do: get_motivation()
  defp handle_command("!qotd", _, _, _), do: get_quote_of_the_day()
  defp handle_command("!asshole", _, _, _), do: ["asshole"] |> get_random_redpic()
  defp handle_command("!porn", _, _, _), do: ["retrobattlestations"] |> get_random_redpic()
  defp handle_command("!rotta", _, _, _), do: ["sphynx"] |> get_random_redpic()
  defp handle_command("!maga", _, _, _), do: ["The_Donald"] |> get_random_redpic()
  defp handle_command("!ck2", _, _, _), do: Paradox.get_last_ck2()
  defp handle_command("!eu4", _, _, _), do: Paradox.get_last_eu4()
  defp handle_command("!hoi4", _, _, _), do: Paradox.get_last_hoi4()
  defp handle_command("!stellaris", _, _, _), do: Paradox.get_last_stellaris()
  defp handle_command("!kuake", _, _, _), do: Scrape.website("https://store.nin.com/products/quake-ost-1xlp").description

  defp handle_command(_, _, _, _), do: ""

  defp add_to_list(list, item), do: list ++ [item]

  defp get_function(string) do
    cond do
      string == "!aotd" -> :aotd_channels
      string == "!fakenews" -> :fake_news_channels
      string == "!title" -> :url_title_channels
      string == "!tweet" -> :tweet_channels
      string == "!qotd" -> :quote_of_the_day_channels
      string == "!paradox" -> :devdiary_channels
      true -> nil
    end
  end

  defp subscribe_channel(function, channel) do
    function = get_function(function)
    if function != nil do
      channels = Bot.get_function_channels(function)
      case (!Enum.member?(channels, channel)) do
        true -> channels
                |> add_to_list(channel)
                |> Bot.update_function_channels(function)
                case function do
                  :tweet_channels -> "MAGA!"
                  _ -> "Subscribed."
                end
        false -> "Already subscribed."
      end
    end
  end

  def unsubscribe_channel(function, channel) do
    function = get_function(function)
    channels = Bot.get_function_channels(function)
    if function != nil && channels != nil do
      channels = Bot.get_function_channels(function)
      case (Enum.member?(channels, channel)) do
        true -> channels
                |> List.delete(channel)
                |> Bot.update_function_channels(function)
              case function do
                :tweet_channels ->  "Sad news from the failing #{channel}!"
                _ -> "Unsubscribed."
              end
        false -> "Not subscribed."
      end
    end
  end

  def clean_tweet(tweet), do: tweet.text |> clean_msg()
  def clean_msg(msg) do
    msg
    |> String.replace("&amp;", "&")
    |> String.replace("\n", "")
  end

  defp tweet_cmd(["last" | _]), do: tweet_cmd([""])
  defp tweet_cmd([""]) do
    Bot.get_last_tweet_id()
    |> ExTwitter.show
    |> clean_tweet()
  end
  defp tweet_cmd(_), do: ""

  defp fakenews_cmd(["last" | _], channel) do
    article = Bot.get_latest_fake_news() |> Enum.reverse() |> List.first |> Scrape.article
    Bot.msg_to_channel(article.url, channel)
    case (Enum.member?(Bot.get_url_title_channels(), channel)) do
      true -> handle_url_title(article.url, channel)
      false -> :timer.sleep(1000)
    end
    article.description      
  end
  defp fakenews_cmd(_), do: ""

  defp stock_cmd(args) do
    args |> Stocks.get_stock()
  end

  defp index_cmd(args) do
    args |> Stocks.get_index()
  end

  defp get_random_redpic([subreddit | _]) do
    pics = HTTPoison.get!("https://www.reddit.com/r/#{subreddit}/hot.json?over18=1")
    cond do
      pics.status_code == 200 ->
        pics = pics.body |> Poison.Parser.parse!
        pics["data"]["children"]
        |> Enum.map(fn (data) -> data["data"]["url"] end)
        |> Enum.shuffle
        |> List.first
      true -> ""
    end
  end

  defp get_quote_of_the_day() do
    full_quote = HTTPoison.get!("https://www.brainyquote.com/quotes_of_the_day.html").body
                 |> Floki.find(".clearfix")
                 |> List.first
                 |> Floki.raw_html
    quote_text = full_quote |> Floki.find(".b-qt") |> Floki.text
    quote_auth = full_quote |> Floki.find(".bq-aut") |> Floki.text
    "#{quote_text} -#{quote_auth}"
  end

  defp get_motivation() do
    block = HTTPoison.get!("http://inspirationalshit.com/quotes").body |> Floki.find("blockquote")
    motivation = block |> Floki.find("p") |> Floki.text
    author = block |> Floki.find("cite") |> Floki.text
    "#{motivation} -#{author}"
    |> String.replace("&amp;", "&")
    |> String.replace("\n", "")
  end

  def unix_to_datetime(epoch) do
    if is_binary(epoch) do
      epoch = epoch |> String.to_integer
    end
    Timex.from_unix(epoch)
  end

  def time_to_local(args) do
    zone = args |> Enum.at(0) |> String.upcase
    time = args |> Enum.at(1)
    try do
      if String.split(time, ":") |> Enum.count < 3 do
        time = [time] ++ [":00"] |> Enum.join()
      end
      if String.split(time, ":") |> Enum.count < 3 do
        time = [time] ++ [":00"] |> Enum.join()
      end
      time = time |> String.split(":")
      zone = Timex.Timezone.get(zone)
      datetime = Timex.now()
                 |> Map.put(:hour, time |> Enum.at(0) |> String.to_integer())
                 |> Map.put(:minute, time |> Enum.at(1) |> String.to_integer())
                 |> Map.put(:second, time |> Enum.at(2) |> String.to_integer())
                 |> Map.put(:time_zone, zone.abbreviation)
                 |> Map.put(:utc_offset, zone.offset_utc)
                 |> Map.put(:std_offset, zone.offset_std)
      fixed = datetime              
              |> Timex.Timezone.convert(Timex.Timezone.get("Europe/Helsinki"))
              |> Timex.format!("%T", :strftime)
    rescue
      ArgumentError -> ""
    end
  end

  def unix_to_utc(arg) do
    try do
      time = unix_to_datetime(arg)
      if is_map(time) do
        time
        |> Timex.Timezone.convert(Timex.Timezone.get("Europe/Helsinki"))
        "#{time}"
      end
    rescue
      ArgumentError -> ""
    end
  end

  def unix_to_localtime(args) do
    zone = "EET"
    arg = List.first(args)
    if (Enum.count(args) > 1) do
      zone = Enum.at(args, 1)
    end
    try do
      time = unix_to_datetime(arg)
      if is_map(time) do
        time = time
               |> Timex.Timezone.convert(Timex.Timezone.get(zone))
        time_string = time |> Timex.format!("{ISOdate} {ISOtime} {Zabbr}")
        "#{time_string}"
      end
    rescue
      ArgumentError -> ""
    end
  end

  defp pelit_cmd([url | _]) do
    url
    |> String.replace("https://www.pelit.fi/forum/proxy.php?image=", "")
    |> String.split("&hash")
    |> List.first
    |> String.replace("%3A", ":")
    |> String.replace("%2F", "/")
  end

  def handle_scrape(url) do
    try do
      if Regex.match?(~r/(i.imgur)/, url) do
        url = url
              |> String.replace("i.imgur", "imgur")
              |> String.split(".")
              |> Enum.reverse
              |> List.delete_at(0)
              |> Enum.reverse
              |> Enum.join(".")
      end
      page = Scrape.website(url)
      if page.title == nil do
        ""
      else
        page.title
        |> String.replace("\n", " ")
        |> String.trim
        |> String.replace("Imgur: The most awesome images on the Internet", "")
      end
    rescue
      ArgumentError -> nil
      CaseClauseError -> nil
    end
  end

  def handle_url_title(input, channel) do
    title =
      case Regex.match?(~r/(https*:\/\/).+(\.)(.+)/, input) do
        true -> handle_scrape(input)
        false -> nil
      end
    if title != nil do
      Bot.msg_to_channel("#{title}", channel)
    end
  end

  def update_fake_news(news) do
    latest_fake_news = Bot.get_latest_fake_news()
    if !Enum.member?(latest_fake_news, news.url) do
      latest_fake_news
      |> List.delete_at(0)
      |> add_to_list(news.url)
      |> Bot.update_latest_fake_news()
    end
  end

  def handle_fake_news(news) do
    if !Enum.member?(Bot.get_latest_fake_news(), news.url) do
      update_fake_news(news)

      # First send news url
      Bot.get_fake_news_channels()
      |> Enum.map(fn (channel) -> Bot.msg_to_channel(news.url, channel) end)

      # Then title (or not)
      Bot.get_fake_news_channels()
      |> Enum.each(fn (channel) ->
        case (Enum.member?(Bot.get_url_title_channels(), channel)) do
          true -> Bot.msg_to_channel(news.title, channel)
          false -> :timer.sleep(1000)
        end
      end)

      # And finally description
      Bot.get_fake_news_channels()
      |> Enum.each(fn (channel) -> Bot.msg_to_channel(news.description, channel) end)
    end
  end

  def check_title(msg, nick, channel) do
    if String.contains?(msg, "http") do
      if Enum.member?(Bot.get_url_title_channels(),channel) do
        msg
        |> String.split(" ")
        |> Enum.map(fn (item) -> handle_url_title(item, channel) end)
      end
    end
  end

  def check_aotd() do
    aotd = ["asshole"] |> get_random_redpic()
    Bot.get_aotd_channels()
    |> Enum.map(fn (channel) ->
      Bot.msg_to_channel("Asshole of the day: #{aotd}", channel)
    end)
  end

  def check_quote_of_the_day() do
    quote_of_the_day = get_quote_of_the_day()
    Bot.get_quote_of_the_day_channels()
    |> Enum.map(fn (channel) -> Bot.msg_to_channel(quote_of_the_day, channel) end)
  end

  def check_trump_tweets() do
    [count: 5, screen_name: "realDonaldTrump"]
    |> ExTwitter.user_timeline()
    |> Enum.reverse
    |> Enum.each(fn(tweet) -> Twitter.handle_tweet(tweet) end)
  end

  def check_trump_fake_news() do
    "http://feeds.washingtonpost.com/rss/politics"
    |> Scrape.feed
    |> Enum.each(fn (news) ->
      if String.contains?(news.title, "Trump") || String.contains?(news.description, "Trump"), do:
        handle_fake_news(news)
      end)
  end

  def good_morning() do
    # fugly hax until i un-fugger my quantum
    time = Timex.now()
    if time.hour == 5 && time.minute == 0 do
      check_aotd()
      :timer.sleep(2000)
      check_quote_of_the_day()
    end
  end

  def check_paradox_devdiaries() do
    Paradox.check_ck2_devdiary()
    Paradox.check_eu4_devdiary()
    Paradox.check_hoi4_devdiary()
    Paradox.check_stellaris_devdiary()
  end

  def populate_last_tweet_id() do
    [count: 1, screen_name: "realDonaldTrump"]
    |> ExTwitter.user_timeline()
    |> Enum.each(fn (tweet) -> Bot.update_last_tweet_id(tweet.id) end)
  end

  def populate_latest_fake_news() do
    "http://feeds.washingtonpost.com/rss/politics"
    |> Scrape.feed#(:minimal)
    |> Enum.each(fn(news) ->
      if String.contains?(news.title, "Trump") || String.contains?(news.description, "Trump"), do:
        update_fake_news(news)
    end)
  end
end