defmodule Trumpet.Commands do
  alias Trumpet.Bot
  alias Trumpet.Paradox
  alias Trumpet.Stocks
  alias Trumpet.Twitter
  alias Trumpet.Utils

  def handle_command(msg, nick, channel) do
    [cmd | args] = msg |> String.split(" ")
    args =
      case Enum.empty?(args) do
        true  -> [""]
        false -> args
      end
    response =
      cond do
        args |> List.first |> String.starts_with?("sub") ->
          cmd |> get_function() |> subscribe_channel(channel)
        args |> List.first |> String.starts_with?("unsub") ->
          cmd |> unsubscribe_channel(channel)
        true ->
          handle_command(cmd, args, channel, nick)
      end
    response
    |> Bot.msg_to_channel(channel)
  end

  defp handle_command("!tweet", args, channel, _), do: tweet_cmd(args, channel)
  defp handle_command("!fakenews", args, channel, _), do: fake_news_cmd(args, channel)
  defp handle_command("!stock", args, _, _), do: stock_cmd(args)
  defp handle_command("!stocks", args, _, _), do: stock_cmd(args)
  defp handle_command("!börs", args, _, _), do: stock_cmd(args)
  defp handle_command("!pörs", args, _, _), do: stock_cmd(args)
  defp handle_command("!pörssi", args, _, _), do: stock_cmd(args)
  defp handle_command("!index", args, _, _), do: index_cmd(args)
  defp handle_command("!yahoo", args, _, _), do: stock_history_cmd(args)
  defp handle_command("!r", args, _, _), do: get_random_redpic(args)
  defp handle_command("!epoch", args, _, _), do: unix_to_localtime(args)
  defp handle_command("!time", args, _, _), do: time_to_local(args)
  defp handle_command("!pelit", args, _, _), do: pelit_cmd(args)
  defp handle_command("!crypto", args, _, _), do: crypto_coin_cmd(args, "EUR")

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

  defp handle_command(cmd, args, _, _) do
    if String.match?(cmd, ~r(!\w+coin)), do: crypto_coin_cmd(args, "USD")
  end

  defp add_to_list(list, item), do: list ++ [item]

  defp get_function(string) do
    cond do
      string == "!fakenews" -> :fake_news_channels
      string == "!title" -> :url_title_channels
      string == "!tweet" -> :tweet_channels
      string == "!qotd" -> :quote_of_the_day_channels
      string == "!paradox" -> :devdiary_channels
      true -> nil
    end
  end

  def subscribe_channel(nil, _channel), do: ""
  def subscribe_channel(function, channel) do
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

  def unsubscribe_channel(nil, _channel), do: ""
  def unsubscribe_channel(function, channel) do
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

  defp tweet_cmd(["last" | _], channel), do: tweet_cmd([""], channel)
  defp tweet_cmd([""], channel) do
    Bot.get_last_tweet_id()
    |> Twitter.get_tweet_msg()
    |> Bot.msg_to_channel(channel)
  end
  defp tweet_cmd(_), do: ""

  defp fake_news_cmd(["last" | _], channel) do
    article =
      Bot.get_latest_fake_news()
      |> Enum.reverse()
      |> List.first()
      |> HTTPoison.get()
      |> Trumpet.Website.website()
    Bot.msg_to_channel(article.url, channel)
    case (Enum.member?(Bot.get_url_title_channels(), channel)) do
      true -> handle_url_title(article.url, channel)
      false -> :timer.sleep(1000)
    end
    article.og_description
  end
  defp fake_news_cmd(_), do: ""

  defp stock_cmd(args) do
    Stocks.get_stock(args)
  end

  defp index_cmd(args) do
    Stocks.get_index(args)
  end

  defp stock_history_cmd(args) do
    args |> Enum.join(" ") |> Stocks.get_stock_history()
  end

  defp crypto_coin_cmd(args, currency) do
    Trumpet.Cryptocurrency.get_coin(args, currency)
  end

  def get_random_redpic([subreddit | _]) do
    pics = HTTPoison.get!("https://www.reddit.com/r/#{subreddit}/hot.json?over18=1")
    if pics.status_code == 200 do
      pics = Poison.Parser.parse!(pics.body)
      pics["data"]["children"]
      |> Enum.map(fn(data) -> data["data"]["url"] end)
      |> Enum.shuffle()
      |> List.first()
    end
  end

  def get_quote_of_the_day do
    full_quote =
      HTTPoison.get!("https://www.brainyquote.com/quotes_of_the_day.html", [], [follow_redirect: true]).body
      |> Floki.find(".clearfix")
      |> List.first()
      |> Floki.raw_html()
    quote_text =
    full_quote
      |> Floki.find(".b-qt")
      |> Floki.text()
    quote_auth = full_quote
      |> Floki.find(".bq-aut")
      |> Floki.text()
    "#{quote_text} -#{quote_auth}"
  end

  def get_motivation do
    block =
      HTTPoison.get!("http://inspirationalshit.com/quotes").body
      |> Floki.find("blockquote")
    motivation =
      block
      |> Floki.find("p")
      |> Floki.text()
    author =
      block
      |> Floki.find("cite")
      |> Floki.text()
    String.replace("#{motivation} -#{author}", "\n", "")
  end

  def parse_time(time) when is_binary(time) do
    # Make sure there are enough items
    time =
      [time] ++ [":00:00"]
      |> Enum.join()
      |> String.split(":")
      |> Enum.map(fn(item) -> String.to_integer(item) end)
    Timex.now()
    |> Map.put(:hour, Enum.at(time, 0))
    |> Map.put(:minute, Enum.at(time, 1))
    |> Map.put(:second, Enum.at(time, 2))
  end

  def time_to_local(args) do
    time =
      case Enum.count(args) > 1 do
        true ->  args |> Enum.at(1) |> parse_time()
        false -> Timex.now()
      end
    try do
      zone =
        args
        |> Enum.at(0)
        |> String.upcase
        |> Timex.Timezone.get
      localzone = Timex.Timezone.get("Europe/Helsinki")
      time
      |> Map.put(:time_zone, zone.abbreviation)
      |> Map.put(:utc_offset, zone.offset_utc)
      |> Map.put(:std_offset, zone.offset_std)
      |> Timex.Timezone.convert(localzone)
      |> Timex.format!("%T", :strftime)
    rescue
      ArgumentError -> ""
    end
  end

  def unix_to_utc(arg) do
    time = Utils.unix_to_datetime(arg)
    if is_map(time) do
      localzone = Timex.Timezone.get("Europe/Helsinki")
      time
      |> Timex.Timezone.convert(localzone)
    end
  rescue
    ArgumentError -> ""
  end

  def unix_to_localtime(args) do
    zone =
      case Enum.count(args) > 1 do
        true  -> Enum.at(args, 1)
        false -> "EET"
      end
    arg = List.first(args)
    try do
      time = Utils.unix_to_datetime(arg)
      localtime = Timex.Timezone.get(zone, time)
      case is_map(time) do
        true  -> time
          |> Timex.Timezone.convert(localtime)
          |> Timex.format!("{ISOdate} {ISOtime} {Zabbr}")
        false -> ""
        end
    rescue
      ArgumentError -> ""
    end
  end

  defp pelit_cmd([url | _]), do: pelit_cmd(url)
  defp pelit_cmd(url) do
    url
    |> String.replace("https://www.pelit.fi/forum/proxy.php?image=", "")
    |> String.split("&hash")
    |> List.first()
    |> URI.decode()
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
      end
    website =
      url
      |> HTTPoison.get([], [follow_redirect: true])
      |> Trumpet.Website.website()
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
  rescue
    ArgumentError -> nil
    CaseClauseError -> nil
    MatchError -> nil
  end

  def handle_url_title(input, channel) do
    if Regex.match?(~r/(https*:\/\/).+(\.)(.+)/, input) do
      input
      |> fetch_title()
      |> Bot.msg_to_channel(channel)
    end
  end

  def handle_spotify_uri(input, channel) do
    spotify =
      input
      |> Utils.google_search()
      |> List.first()
    Bot.msg_to_channel("♪ #{spotify.title} ♪ #{spotify.url}", channel)
  end

  def check_title(msg, _nick, channel) do
    cond do
      String.starts_with?(msg, "https://www.pelit.fi/forum/proxy.php") ->
        msg
        |> pelit_cmd()
        |> Bot.msg_to_channel(channel)
      String.starts_with?(msg, "spotify:") ->
        msg
        |> handle_spotify_uri(channel)
      String.contains?(msg, "http") && Enum.member?(Bot.get_url_title_channels(), channel) ->
        msg
        |> String.split(" ")
        |> Enum.map(fn(item) -> handle_url_title(item, channel) end)
      true -> :ok
    end
  end

  def check_quote_of_the_day do
    quote_of_the_day = get_quote_of_the_day()
    Bot.get_quote_of_the_day_channels()
    |> Enum.map(fn(channel) -> Bot.msg_to_channel(quote_of_the_day, channel) end)
  end

  def check_trump_tweets do
    current_last = Bot.get_last_tweet_id()
    [count: 5, screen_name: "realDonaldTrump"]
    |> ExTwitter.user_timeline()
    |> Enum.reverse
    |> Enum.each(fn(tweet) -> Twitter.handle_tweet(tweet) end)

    if current_last != Bot.get_last_tweet_id() do
      last_tweet = Twitter.get_tweet_msg(Bot.get_last_tweet_id())

      Bot.get_tweet_channels()
      |> Enum.each(fn(channel) ->
        Bot.msg_to_channel(last_tweet, channel)
      end)
    end
  end

  def good_morning do
    check_quote_of_the_day()
  end

  def trump_check do
    check_trump_tweets()
    check_trump_fake_news()
  end

  def check_paradox_devdiaries do
    Paradox.check_ck2_devdiary()
    Paradox.check_eu4_devdiary()
    Paradox.check_hoi4_devdiary()
    Paradox.check_stellaris_devdiary()
  end

  def populate_last_tweet_id do
    [count: 1, screen_name: "realDonaldTrump"]
    |> ExTwitter.user_timeline()
    |> Enum.each(fn(tweet) -> Bot.update_last_tweet_id(tweet.id) end)
  end

  def update_fake_news(news) do
    latest_fake_news = Bot.get_latest_fake_news()
    if !Enum.member?(latest_fake_news, news.url) do
      [_ | tail] = latest_fake_news
      tail
      |> add_to_list(news.url)
      |> Bot.update_latest_fake_news()
    end
    last =
      Bot.get_latest_fake_news()
      |> Enum.reverse()
      |> List.first()
    if last != Bot.get_last_fake_news() do
      last
      |> HTTPoison.get!()
      |> Trumpet.Website.website()
      |> handle_fake_news()
      Bot.update_last_fake_news(last)
    end
  end

  def check_fake_title(channels, news) do
    Enum.each(channels, fn(channel) ->
      case (Enum.member?(Bot.get_url_title_channels(), channel)) do
        true  -> Bot.msg_to_channel(news.title, channel)
        false -> :timer.sleep(1000)
     end
    end)
  end
  def handle_fake_news(news) do
    if !Enum.member?(Bot.get_latest_fake_news(), news.url) do
      update_fake_news(news)

      # First send news url
      Bot.get_fake_news_channels()
      |> Enum.map(fn(channel) -> Bot.msg_to_channel(news.url, channel) end)

      # Then title (or not)
      Bot.get_fake_news_channels()
      |> check_fake_title(news)

      # And finally description
      Bot.get_fake_news_channels()
      |> Enum.each(fn(channel) -> Bot.msg_to_channel(news.description, channel) end)
    end
  end

  def news_about_trump?(news) do
    title = news.title
    desc = news.description
    String.contains?(title, "Trump") || String.contains?(desc, "Trump")
  end

  def check_trump_fake_news do
    "http://feeds.washingtonpost.com/rss/politics"
    |> HTTPoison.get()
    |> Trumpet.Feed.feed()
    |> Enum.each(fn(news) ->
      if news_about_trump?(news), do:
        update_fake_news(news)
    end)
  end

  def populate_latest_fake_news do
    check_trump_fake_news()
    Bot.get_latest_fake_news()
    |> Enum.reverse()
    |> List.first()
    |> Bot.update_last_fake_news()
  end
end
