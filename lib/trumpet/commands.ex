defmodule Trumpet.Commands do
  alias Trumpet.Bot
  alias Trumpet.Lotto
  alias Trumpet.Paradox
  alias Trumpet.Stocks
  alias Trumpet.Twitter
  alias Trumpet.Utils
  alias Trumpet.VR
  alias Trumpet.Website

  def handle_command(msg, nick, channel) do
    [cmd | args] = msg |> String.trim() |> String.split(" ")

    args =
      case Enum.empty?(args) do
        true -> [""]
        false -> args
      end

    response =
      cond do
        args |> List.first() |> String.starts_with?("sub") ->
          Task.start(Trumpet.Bot, :msg_admins, [channel, nick, msg])
          cmd |> get_function() |> subscribe_channel(channel)

        args |> List.first() |> String.starts_with?("unsub") ->
          Task.start(Trumpet.Bot, :msg_admins, [channel, nick, msg])
          cmd |> get_function() |> unsubscribe_channel(channel)

        true ->
          handle_command(cmd, args, channel, nick)
      end

    response
    |> Bot.msg_to_channel(channel)
  end

  def handle_command(cmd, args, channel, nick), do: call_command(cmd, args, channel, nick)
  defp call_command("!tweet", args, channel, _), do: tweet_cmd(args, channel)
  defp call_command("!fakenews", args, channel, _), do: fake_news_cmd(args, channel)
  defp call_command("!stock", args, _, _), do: stock_cmd(args)
  defp call_command("!stocks", args, _, _), do: stock_cmd(args)
  defp call_command("!börs", args, _, _), do: stock_cmd(args)
  defp call_command("!pörs", args, _, _), do: stock_cmd(args)
  defp call_command("!pörssi", args, _, _), do: stock_cmd(args)
  defp call_command("!index", args, _, _), do: index_cmd(args)
  #  defp call_command("!yahoo", args, _, _), do: stock_history_cmd(args)
  defp call_command("!r", args, _, _), do: get_random_redpic(args)
  defp call_command("!epoch", args, _, _), do: unix_to_localtime(args)
  defp call_command("!time", args, _, _), do: time_to_local(args)
  defp call_command("!pelit", args, _, _), do: pelit_cmd(args)
  defp call_command("!coin", args, _, _), do: cryptocoin_cmd(args, "USD")
  defp call_command("!crypto", args, _, _), do: cryptocoin_cmd(args, "EUR")
  defp call_command("!random_gen", args, _, _), do: random_numbers(args)
  defp call_command("!vr", args, _, _), do: VR.get_next_train(args)
  defp call_command("!juna", args, _, _), do: VR.get_live_train(args)
  defp call_command("!eurojaska", _, _, _), do: Lotto.eurojackpot()
  defp call_command("!eurojackpot", _, _, _), do: Lotto.eurojackpot()
  defp call_command("!lotto", _, _, _), do: Lotto.lotto()
  defp call_command("!motivation", _, _, _), do: get_motivation()
  defp call_command("!qotd", _, _, _), do: get_quote_of_the_day()
  defp call_command("!asshole", _, _, _), do: ["asshole"] |> get_random_redpic()
  defp call_command("!porn", _, _, _), do: ["retrobattlestations"] |> get_random_redpic()
  defp call_command("!rotta", _, _, _), do: ["sphynx"] |> get_random_redpic()
  defp call_command("!maga", _, _, _), do: ["The_Donald"] |> get_random_redpic()
  defp call_command("!ck2", _, _, _), do: Paradox.get_last_ck2()
  defp call_command("!eu4", _, _, _), do: Paradox.get_last_eu4()
  defp call_command("!hoi4", _, _, _), do: Paradox.get_last_hoi4()
  defp call_command("!stellaris", _, _, _), do: Paradox.get_last_stellaris()

  defp call_command("!kuake", _, _, _),
    do: Website.get_og_description("https://store.nin.com/products/quake-ost-1xlp")

  defp call_command(cmd, args, _, _) do
    if String.match?(cmd, ~r(!\w+coin)), do: cryptocoin_cmd(args, "USD")
  end

  defp add_to_list(list, item), do: list ++ [item]

  defp get_function(string) do
    cond do
      # string == "!fakenews" -> :fake_news_channels
      string == "!title" ->
        :url_title_channels

      string == "!tweet" ->
        :tweet_channels

      string == "!qotd" ->
        :quote_of_the_day_channels

      string == "!paradox" ->
        :devdiary_channels

      true ->
        nil
    end
  end

  def subscribe_channel(nil, _channel), do: ""

  def subscribe_channel(function, channel) do
    channels = Bot.get_function_channels(function)

    case !Enum.member?(channels, channel) do
      true ->
        channels
        |> add_to_list(channel)
        |> Bot.update_function_channels(function)

        case function == :tweet_channels do
          true -> "MAGA!"
          false -> "Subscribed."
        end

      false ->
        "Already subscribed."
    end
  end

  def unsubscribe_channel(nil, _channel), do: ""

  def unsubscribe_channel(function, channel) do
    channels = Bot.get_function_channels(function)

    case Enum.member?(channels, channel) do
      true ->
        channels
        |> List.delete(channel)
        |> Bot.update_function_channels(function)

        case function == :tweet_channels do
          true -> "Sad news from the failing #{channel}!"
          false -> "Unsubscribed."
        end

      false ->
        "Not subscribed."
    end
  end

  defp tweet_cmd(["last" | _], channel), do: tweet_cmd([""], channel)

  defp tweet_cmd([""], _channel) do
    Bot.get_last_tweet_id()
    |> Twitter.get_tweet_msg()
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

    case Enum.member?(Bot.get_url_title_channels(), channel) do
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

  defp cryptocoin_cmd(args, currency) do
    Trumpet.Cryptocurrency.get_coin(args, currency)
  end

  def random_numbers(args) do
    cond do
      Enum.count(args) == 2 ->
        [count, take] = args

        count
        |> String.to_integer()
        |> Utils.random_numbers(String.to_integer(take))
        |> Utils.print_random_numbers()

      Enum.count(args) == 3 ->
        [count, take, min] = args

        count
        |> String.to_integer()
        |> Utils.random_numbers(String.to_integer(take), String.to_integer(min))
        |> Utils.print_random_numbers()

      true ->
        ""
    end
  end

  def get_random_redpic([subreddit | _]) do
    pics = HTTPoison.get!("https://www.reddit.com/r/#{subreddit}/hot.json?over18=1")

    if pics.status_code == 200 do
      pics = Poison.Parser.parse!(pics.body)
      :crypto.rand_seed()

      pics["data"]["children"]
      |> Enum.map(fn data -> data["data"]["url"] end)
      |> Enum.filter(fn url ->
        String.contains?(url, ["imgur", "i.redd"]) ||
          String.ends_with?(url, [".png", ".jpg", ".jpeg", ".gif", ".gifv"])
      end)
      |> Enum.random()
    end
  end

  def get_quote_of_the_day do
    full_quote =
      HTTPoison.get!(
        "https://www.brainyquote.com/quotes_of_the_day.html",
        [],
        follow_redirect: true
      ).body
      |> Floki.find(".clearfix")
      |> List.first()
      |> Floki.raw_html()

    quote_text =
      full_quote
      |> Floki.find(".b-qt")
      |> Floki.text()

    quote_auth =
      full_quote
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
      ([time] ++ [":00:00"])
      |> Enum.join()
      |> String.split(":")
      |> Enum.map(fn item -> String.to_integer(item) end)

    Timex.now()
    |> Map.put(:hour, Enum.at(time, 0))
    |> Map.put(:minute, Enum.at(time, 1))
    |> Map.put(:second, Enum.at(time, 2))
  end

  def time_to_local(args) do
    time =
      case Enum.count(args) > 1 do
        true -> args |> Enum.at(1) |> parse_time()
        false -> Timex.now()
      end

    try do
      zone =
        args
        |> Enum.at(0)
        |> String.upcase()
        |> Timex.Timezone.get()

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
    localzone = Timex.Timezone.get("Europe/Helsinki")
    Timex.Timezone.convert(time, localzone)
  rescue
    ArgumentError -> ""
  end

  def unix_to_localtime(args) do
    zone =
      case Enum.count(args) > 1 do
        true -> Enum.at(args, 1)
        false -> "EET"
      end

    arg = List.first(args)

    try do
      time = Utils.unix_to_datetime(arg)
      localtime = Timex.Timezone.get(zone, time)

      time
      |> Timex.Timezone.convert(localtime)
      |> Timex.format!("{ISOdate} {ISOtime} {Zabbr}")
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

  def handle_url_title(input, channel) do
    if Regex.match?(~r/(https*:\/\/).+(\.)(.+)/, input) do
      input
      |> Website.fetch_title()
      |> Bot.msg_to_channel(channel)
    end
  end

  def handle_spotify_uri(input, channel) do
    type =
      input
      |> String.split(":")
      |> Enum.at(1)

    spotify =
      input
      |> String.replace("spotify:#{type}:", "https://open.spotify.com/#{type}/")
      |> Website.get_website()

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
        |> Enum.map(fn item -> handle_url_title(item, channel) end)

      true ->
        :ok
    end
  end

  def check_quote_of_the_day do
    quote_of_the_day = get_quote_of_the_day()

    Bot.get_quote_of_the_day_channels()
    |> Enum.each(fn channel -> Bot.msg_to_channel(quote_of_the_day, channel) end)
  end

  def check_trump_tweets do
    current_last = Bot.get_last_tweet_id()

    Twitter.populate_last_tweet_id()

    if current_last != Bot.get_last_tweet_id() do
      last_tweet = Twitter.get_tweet_msg(Bot.get_last_tweet_id())

      Bot.get_tweet_channels()
      |> Enum.each(fn channel ->
        Bot.msg_to_channel(last_tweet, channel)
      end)
    end
  end

  def good_morning do
    check_quote_of_the_day()
  end

  def trump_check do
    check_trump_tweets()
    # check_trump_fake_news()
  end

  def check_paradox_devdiaries do
    Paradox.check_ck2_devdiary()
    Paradox.check_eu4_devdiary()
    Paradox.check_hoi4_devdiary()
    Paradox.check_stellaris_devdiary()
  end

  def populate_last_tweet_id do
    Twitter.populate_last_tweet_id()
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
    Enum.each(channels, fn channel ->
      case Enum.member?(Bot.get_url_title_channels(), channel) do
        true -> Bot.msg_to_channel(news.title, channel)
        false -> :timer.sleep(1000)
      end
    end)
  end

  def handle_fake_news(news) do
    if !Enum.member?(Bot.get_latest_fake_news(), news.url) do
      update_fake_news(news)

      # First send news url
      Bot.get_fake_news_channels()
      |> Enum.map(fn channel -> Bot.msg_to_channel(news.url, channel) end)

      # Then title (or not)
      Bot.get_fake_news_channels()
      |> check_fake_title(news)

      # And finally description
      Bot.get_fake_news_channels()
      |> Enum.each(fn channel -> Bot.msg_to_channel(news.description, channel) end)
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
    |> Enum.each(fn news ->
      if news_about_trump?(news), do: update_fake_news(news)
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
