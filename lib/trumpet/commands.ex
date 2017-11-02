defmodule Trumpet.Commands do
  alias Trumpet.Bot
  alias Trumpet.Paradox
  alias Trumpet.Stocks
  alias Trumpet.Twitter

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
    |> String.replace("\n", "")
    |> Floki.text()
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
    if pics.status_code == 200 do
      pics = pics.body |> Poison.Parser.parse!
      pics["data"]["children"]
      |> Enum.map(fn (data) -> data["data"]["url"] end)
      |> Enum.shuffle
      |> List.first
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
    |> String.replace("\n", "")
    |> Floki.text
  end

  def unix_to_datetime(epoch) do
    epoch =
      case is_binary(epoch) do
        true  -> epoch |> String.to_integer
        false -> epoch
      end
    Timex.from_unix(epoch)
  end

  def parse_time(time) when is_binary(time) do
    # Make sure there are enough items
    time = [time] ++ [":00:00"]
           |> Enum.join()
           |> String.split(":")
           |> Enum.map(fn(item) -> String.to_integer(item) end)
    Timex.now()
    |> Map.put(:hour, time |> Enum.at(0))
    |> Map.put(:minute, time |> Enum.at(1))
    |> Map.put(:second, time |> Enum.at(2))
  end

  def time_to_local(args) do
    time =
      case Enum.count(args) > 1 do
        true -> parse_time(Enum.at(args, 1))
        false -> Timex.now()
      end
    try do
      zone = args
            |> Enum.at(0)
            |> String.upcase
            |> Timex.Timezone.get
      time
      |> Map.put(:time_zone, zone.abbreviation)
      |> Map.put(:utc_offset, zone.offset_utc)
      |> Map.put(:std_offset, zone.offset_std)
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
      end
    rescue
      ArgumentError -> ""
    end
  end

  def unix_to_localtime(args) do
    zone =
      case Enum.count(args) > 1 do
        true  -> Enum.at(args, 1)
        false -> "EET"
      end
    arg = List.first(args)
    try do
      time = unix_to_datetime(arg)
      time =
        case is_map(time) do
          true  -> time
                   |> Timex.Timezone.convert(Timex.Timezone.get(zone, time))
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
    |> List.first
    |> URI.decode
  end

  defp floki_helper(page, property) do
    page
    |> Floki.find(property)
    |> Floki.attribute("content")
    |> List.first()
  end

  def validate_string(string) do
    case String.valid?(string) do
      true -> string
      false ->
        string
        |> :unicode.characters_to_binary(:latin1)
        # That damn – seems to cause problems on some pages. This fixes it.
        |> String.replace(<<0xc3, 0xa2, 0xc2, 0x80, 0xc2, 0x93>>,<<0xe2, 0x80, 0x93>>)
    end
  end

  def google_search(query) do
    HTTPoison.get!("https://www.google.fi/search?q=#{URI.encode(query)}").body
    |> Floki.find("h3[class='r']")
    |> Floki.raw_html
    |> String.replace("<h3 class=\"r\">", "")
    |> String.replace("<a href=\"/url?q=", "")
    |> String.trim_trailing("</a></h3>")
    |> String.split("</a></h3>")
    |> Enum.map(&(String.split(&1, "\">")))
    |> Enum.reject(fn(x) -> Enum.count(x) != 2 end)
    |> Enum.map(fn([url, title]) -> %{url: url |> String.split("&sa=U") |> List.first(), title: Floki.text(title)} end)
    |> Enum.reject(fn(x) -> String.starts_with?(x.url, "<a href=") end)
    |> Enum.map(fn(%{url: url, title: title}) -> %{url: url, title: validate_string(title)} end)
  end

  def url_shorten(url) do
    {:api_key, api_key} = Application.get_env(:trumpet, :url_shortener_api_key) |> List.first
    response = HTTPoison.post!("https://www.googleapis.com/urlshortener/v1/url?key=#{api_key}",
      "{\"longUrl\": \"#{url}\"}", [{"Content-Type", "application/json"}]).body
      |> Poison.decode!()
    response["id"]
  end

  def fetch_title(url) do
    try do
      url =
        case Regex.match?(~r/(i.imgur)/, url) do
          true  -> url
                   |> String.replace("i.imgur", "imgur")
                   |> String.split(".")
                   |> Enum.drop(-1)
                   |> Enum.join(".")
          false -> url
        end
      page = HTTPoison.get!(url, [], [follow_redirect: true]).body
      og_title = page |> floki_helper("meta[property='og:title']") 
      og_site = page |> floki_helper("meta[property='og:site_name']")
      og_desc = page |> floki_helper("meta[property='og:description']")
      #[{_, _, [title]}] = page |> Floki.find("title") |> Floki.text
      title = page |> Floki.find("title") |> Floki.text
      #tube_title = page |> Floki.find("title:") |> Floki.text
      cond do
        og_site == "Twitter" -> og_desc
        og_title != nil && String.length(og_title) > String.length(title) -> og_title
        true -> title
      end
      |> String.trim()
      |> Floki.text()
      |> String.replace("Imgur: The most awesome images on the Internet", "")
    rescue
      ArgumentError -> nil
      CaseClauseError -> nil
      MatchError -> nil
    end
  end

  def handle_url_title(input, channel) do
    if Regex.match?(~r/(https*:\/\/).+(\.)(.+)/, input) do
      input
      |> fetch_title()
      |> Bot.msg_to_channel(channel)
    end
  end

  def handle_spotify_uri(input, channel) do
    spotify = google_search(input)
              |> List.first
    Bot.msg_to_channel("♪ #{spotify.title} ♪ #{spotify.url}", channel)
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
    cond do
      String.starts_with?(msg, "https://www.pelit.fi/forum/proxy.php") ->
        msg |> pelit_cmd() |> Bot.msg_to_channel(channel)
      String.starts_with?(msg, "spotify:") ->
        msg |> handle_spotify_uri(channel)
      String.contains?(msg, "http") && Enum.member?(Bot.get_url_title_channels(),channel) ->
        msg
        |> String.split(" ")
        |> Enum.map(fn (item) -> handle_url_title(item, channel) end)
      true -> :ok
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
