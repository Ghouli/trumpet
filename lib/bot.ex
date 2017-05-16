defmodule Trumpet.Bot do
  use GenServer

 # import Quantum.Scheduler
 # use Quantum.Scheduler,
 #   otp_app: :trumpet
  require Logger

  defmodule Config do
    defstruct server:  nil,
              port:    nil,
              pass:    nil,
              nick:    nil,
              user:    nil,
              name:    nil,
              channel: nil,
              client:  nil

    def from_params(params) when is_map(params) do
      Enum.reduce(params, %Config{}, fn {k, v}, acc ->
        case Map.has_key?(acc, k) do
          true  -> Map.put(acc, k, v)
          false -> acc
        end
      end)
    end
  end

  alias ExIrc.Client
#  alias ExIrc.Channels
#  alias ExIrc.Utils
  alias ExIrc.SenderInfo
#  alias ExIrc.Client.Transport
  alias Trumpet.Stocks
  alias Trumpet.Paradox

  def start_link(%{:nick => nick} = params) when is_map(params) do
    config = Config.from_params(params)
    GenServer.start_link(__MODULE__, [config], name: String.to_atom(nick))
  end

  def init([config]) do
    # Start the client and handler processes, the ExIrc supervisor is automatically started when your app runs
    {:ok, client}  = ExIrc.start_link!()

    # Register the event handler with ExIrc
    Client.add_handler client, self()

    # Connect and logon to a server, join a channel and send a simple message
    Client.connect! client, config.server, config.port

    {:ok, agent} = Agent.start_link(fn -> %{} end, name: :runtime_config)

    update_setting(:client, client)
    update_setting(:config, config)
    init_settings()
    {:ok, %Config{config | :client => client}}
  end

  def init_settings() do
    update_setting(:latest_tweet_ids, (for n <- 1..5, do: n))
    update_setting(:latest_fake_news, (for n <- 1..20, do: n))
    update_setting(:tweet_channels, Application.get_env(:trumpet, :tweet_channels, []))
    update_setting(:fake_news_channels, Application.get_env(:trumpet,:fake_news_channels, []))
    update_setting(:url_title_channels, Application.get_env(:trumpet, :url_title_channels, []))
    update_setting(:aotd_channels, Application.get_env(:trumpet, :aotd_channels, []))
    update_setting(:devdiary_channels, Application.get_env(:trumpet, :devdiary_channels, []))
    update_setting(:quote_of_the_day_channels, Application.get_env(:trumpet, :quote_of_the_day_channels, []))

    update_setting(:stellaris, %{})
    update_setting(:hoi4, %{})
    update_setting(:eu4, %{})
    update_setting(:ck2, %{})
    populate_latest_tweet_ids()
    populate_latest_fake_news()
    Paradox.populate_paradox_devdiaries()
  end

  def update_setting(key, value \\ []) do
    Agent.update(:runtime_config, &Map.put(&1, key, value))
  end

  def update_latest_tweet_ids(tweets) do
    update_setting(:latest_tweet_ids, tweets)
  end

  def update_latest_fake_news(urls) do
    update_setting(:latest_fake_news, urls)
  end

  def update_tweet_channels(channels) do
    update_setting(:tweet_channels, channels)
  end

  def update_fake_news_channels(channels) do
    update_setting(:fake_news_channels, channels)
  end

  def update_url_title_channels(channels) do
    update_setting(:url_title_channels, channels)
  end

  def update_aotd_channels(channels) do
    update_setting(:aotd_channels, channels)
  end

  def update_quote_of_the_day_channels(channels) do
    update_setting(:quote_of_the_day_channels, channels)
  end

  def update_function_channels(channels, function) do
    update_setting(function, channels)
  end

  def update_ck2_devdiary_map(map) do
    update_setting(:ck2, map)
  end

  def update_eu4_devdiary_map(map) do
    update_setting(:eu4, map)
  end

  def update_hoi4_devdiary_map(map) do
    update_setting(:hoi4, map)
  end

  def update_stellaris_devdiary_map(map) do
    update_setting(:stellaris, map)
  end

  def update_devdiary_map(map_atom, map) do
    update_setting(map_atom, map)
  end

  def get_setting(key) do
    Agent.get(:runtime_config, &Map.get(&1, key))
  end

  def get_client() do
    get_setting(:client)
  end

  def get_config() do
    get_setting(:config)
  end

  def get_latest_tweet_ids() do
    get_setting(:latest_tweet_ids)
  end

  def get_latest_fake_news() do
    get_setting(:latest_fake_news)
  end

  def get_tweet_channels() do
    get_setting(:tweet_channels)
  end

  def get_fake_news_channels() do
    get_setting(:fake_news_channels)
  end

  def get_url_title_channels() do
    get_setting(:url_title_channels)
  end

  def get_aotd_channels() do
    get_setting(:aotd_channels)
  end

  def get_quote_of_the_day_channels() do
    get_setting(:quote_of_the_day_channels)
  end

  def get_function_channels(function) do
    get_setting(function)
  end

  def get_devdiary_channels() do
    get_setting(:devdiary_channels)
  end

  def get_ck2_devdiary_map() do
    get_setting(:ck2)
  end

  def get_eu4_devdiary_map() do
    get_setting(:eu4)
  end

  def get_hoi4_devdiary_map() do
    get_setting(:hoi4)
  end

  def get_stellaris_devdiary_map() do
    get_setting(:stellaris)
  end

  def get_devdiary_map(map_atom) do
    get_setting(map_atom)
  end

  def add_to_list(list, item) do
    list ++ [item]
  end

  def handle_info({:connected, server, port}, config) do
    Logger.debug "Connected to #{server}:#{port}"
    Logger.debug "Logging to #{server}:#{port} as #{config.nick}.."
    Client.logon config.client, config.pass, config.nick, config.user, config.name
    {:noreply, config}
  end

  def handle_info(:logged_in, config) do
    Logger.debug "Logged in to #{config.server}:#{config.port}"
    Logger.debug "Joining #{config.channel}.."
    Client.join config.client, config.channel
    {:noreply, config}
  end
  def handle_info(:disconnected, config) do
    Logger.debug "Disconnected from #{config.server}:#{config.port}"
    {:stop, :normal, config}
  end

  def handle_info({:joined, channel}, config) do
    Logger.debug "Joined #{channel}"
    #Client.msg config.client, :privmsg, config.channel, "Hello world!"
    {:noreply, config}
  end

  def handle_info({:names_list, channel, names_list}, config) do
    names = names_list
            |> String.split(" ", trim: true)
            |> Enum.map(fn name -> " #{name}\n" end)
    Logger.info "Users logged in to #{channel}:\n#{names}"
    {:noreply, config}
  end

  def handle_info({:received, msg, %SenderInfo{:nick => nick}, channel}, config) do
    Logger.info "#{nick} from #{channel}: #{msg}"
    case String.starts_with?(msg, "!") do
      true -> check_commands(msg, nick, channel)
      false -> check_title(msg, nick, channel)
    end
    {:noreply, config}
  end

  def handle_info({:mentioned, msg, %SenderInfo{:nick => nick}, channel}, config) do
    Logger.warn "#{nick} mentioned you in #{channel}"
    case String.contains?(msg, "hi") do
      true ->
        #Client.msg config.client, :privmsg, channel, "dude"
        :ok
      false ->
        :ok
    end
    {:noreply, config}
  end

  def handle_info({:received, msg, %SenderInfo{:nick => nick}}, config) do
    Logger.warn "#{nick}: #{msg}"
    reply = "Hi!"
    Client.msg config.client, :privmsg, nick, reply
    Logger.info "Sent #{reply} to #{nick}"
    {:noreply, config}
  end

  # Catch-all for messages you don't care about
  def handle_info(_msg, config) do
    {:noreply, config}
  end

  def join_channel(channel) do
    Client.join get_client(), channel
  end

  def terminate(_, state) do
    # Quit the channel and close the underlying client connection when the process is terminating
    Client.quit state.client, "Goodbye, cruel world."
    Client.stop! state.client
    :ok
  end

  def msg_to_channel(msg, channel) do
    if is_binary(channel) && is_binary(msg) do
      Client.msg get_client(), :privmsg, channel, msg
      :timer.sleep(1000) # This is to prevent dropouts for flooding
    end
  end

  def msg_tweet(tweet, channel) do
    tweet.text
    |> String.replace("&amp;", "&")
    |> String.replace("\n", "")
    |> msg_to_channel(channel)
  end

  def msg_tweet(tweet) do
    get_tweet_channels()
    |> Enum.map(fn (channel) -> msg_tweet(tweet, channel) end)
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
        nil
      else
        page.title |> String.trim
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
      Client.msg get_client(), :privmsg, channel, "#{title}"
    end
  end

  def handle_tweet(tweet) do
    latest_ids = get_latest_tweet_ids()
    if (!Enum.member?(latest_ids, tweet.id)) && (tweet.retweeted_status == nil) do
      latest_ids
      |> List.delete_at(0)
      |> add_to_list(tweet.id)
      |> update_latest_tweet_ids()

      msg_tweet(tweet)
    end
  end

  def handle_fake_news(url) do
    latest_fake_news = get_latest_fake_news()
    if !Enum.member?(latest_fake_news, url) do
      latest_fake_news
      |> List.delete_at(0)
      |> add_to_list(url)
      |> update_latest_fake_news()

      # First send news url
      get_fake_news_channels()
      |> Enum.map(fn (channel) -> msg_to_channel(url, channel) end)

      article = Scrape.article "#{url}"

      # Then title (or not)
      get_fake_news_channels()
      |> Enum.map(fn (channel) ->
        case (Enum.member?(get_url_title_channels(), channel)) do
          true -> msg_to_channel(article.title, channel)
          false -> :timer.sleep(1000)
        end
      end)

      # And finally description
      get_fake_news_channels()
      |> Enum.map(fn (channel) -> msg_to_channel(article.description, channel) end)
    end
  end

  def check_title(msg, nick, channel) do
    if String.contains?(msg, "http") do 
      if Enum.member?(get_url_title_channels(),channel) do
        msg
        |> String.split(" ")
        |> Enum.map(fn (item) -> handle_url_title(item, channel) end)
      end
    end
  end

  def check_commands(msg, nick, channel) do
    command_list = String.split(msg, " ")
    cond do
      Enum.count(command_list) >= 2 ->
        cmd = Enum.at(command_list,0)
        arg = Enum.at(command_list,1)
        cond do
          String.starts_with?(arg, "sub") ->
            cmd |> subscribe_channel(channel)
          String.starts_with?(arg, "unsub") ->
            cmd |> unsubscribe_channel(channel)
          msg == "!tweet last" ->
            get_latest_tweet_ids()
            |> Enum.reverse()
            |> List.first
            |> ExTwitter.show
            |> msg_tweet(channel)
          msg == "!fakenews last" ->
            article = get_latest_fake_news() |> Enum.reverse() |> List.first |> Scrape.article
            msg_to_channel(article.url, channel)
            case (Enum.member?(get_url_title_channels(), channel)) do
              true -> handle_url_title(article.url, channel)
              false -> :timer.sleep(1000)
            end
            msg_to_channel(article.description, channel)
          cmd == "!stock" ->
            stock_cmd(channel, msg)
          cmd == "!stocks" ->
            stock_cmd(channel, msg)
          cmd == "!pörssi" ->
            stock_cmd(channel, msg)
          cmd == "!pörs" ->
            stock_cmd(channel, msg)
          cmd == "!börs" ->
            stock_cmd(channel, msg)
          cmd == "!r" ->
            get_random_redpic(arg)
            |> msg_to_channel(channel)
          cmd == "!index" ->
            index_cmd(channel, msg)
          cmd == "!epoch" ->
            unix_to_localtime(arg)
            |> msg_to_channel(channel)
          true -> nil
        end
      Enum.count(command_list) == 1 ->
        cond do
          msg == "!asshole" ->
            get_persie()
            |> msg_to_channel(channel)
          msg == "!motivation" ->
            get_motivation()
            |> String.replace("&amp;", "&")
            |> String.replace("\n", "")
            |> msg_to_channel(channel)
          msg == "!porn" ->
            get_battlestation()
            |> msg_to_channel(channel)
          msg == "!rotta" ->
            get_random_redpic("sphynx")
            |> msg_to_channel(channel)
          msg == "!maga" ->
            get_random_redpic("The_Donald")
            |> msg_to_channel(channel)
          msg == "!ck2" ->
            Paradox.get_last_ck2()
            |> msg_to_channel(channel)
          msg == "!eu4" ->
            Paradox.get_last_eu4()
            |> msg_to_channel(channel)
          msg == "!hoi4" ->
            Paradox.get_last_hoi4()
            |> msg_to_channel(channel)
          msg == "!stellaris" ->
            Paradox.get_last_stellaris()
            |> msg_to_channel(channel)
          true -> nil
        end
      true -> nil
    end
  end

  def stock_cmd(channel, msg) do
    [head | tail] = String.split(msg, " ")
    tail
    |> Enum.join("+")
    |> Stocks.get_stock()
    |> msg_to_channel(channel)
  end

  def index_cmd(channel, msg) do
    [head | tail] = String.split(msg, " ")
    tail
    |> Enum.join("+")
    |> Stocks.get_index()
    |> msg_to_channel(channel)
  end

  def subscribe_channel(function, channel) do
    function = get_function(function)
    if function != nil do
      channels = get_function_channels(function)
      case (!Enum.member?(channels, channel)) do
        true -> channels
                |> add_to_list(channel)
                |> update_function_channels(function)
                case function do
                  :tweet_channels -> msg_to_channel("MAGA!", channel)
                  _ -> msg_to_channel("Subscribed.", channel)
                end
        false -> msg_to_channel("Already subscribed.", channel)
      end
    end
  end

  def unsubscribe_channel(function, channel) do
    function = get_function(function)
    channels = get_function_channels(function)
    IO.inspect function
    IO.inspect channels
    if function != nil && channels != nil do
      channels = get_function_channels(function)
      case (Enum.member?(channels, channel)) do
        true -> channels
                |> List.delete(channel)
                |> update_function_channels(function)
              case function do
                :tweet_channels ->  msg_to_channel("Sad news from the failing #{channel}!", channel)
                _ -> msg_to_channel("Unsubscribed.", channel)
              end
        false -> msg_to_channel("Not subscribed.", channel)
      end
    end
  end

  def get_function(string) do
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

  def check_trump_tweets() do
    [count: 5, screen_name: "realDonaldTrump"]
    |> ExTwitter.user_timeline()
    |> Enum.reverse
    |> Enum.map(fn(tweet) -> handle_tweet(tweet) end)
  end

  def check_trump_fake_news() do
    "http://feeds.washingtonpost.com/rss/politics"
    |> Scrape.feed(:minimal)
    |> Enum.map(fn(url) ->
        if String.match?(url, ~r/(trump)/) do handle_fake_news(url) end
    end)
  end

  def check_paradox_devdiaries() do
    Paradox.check_ck2_devdiary()
    Paradox.check_eu4_devdiary()
    Paradox.check_hoi4_devdiary()
    Paradox.check_stellaris_devdiary()
  end

  def rejoin_channels() do
    chans = get_tweet_channels() ++
            get_fake_news_channels() ++
            get_aotd_channels() ++
            get_quote_of_the_day_channels() ++
            get_devdiary_channels() ++
            get_url_title_channels()
            |> Enum.uniq()
    for chan <- chans, do: join_channel(chan)
  end

  def reconnect() do
    client = get_client()
    config = get_config()
    Client.connect! client, config.server, config.port

    #rejoin_channels()
  end

  def check_connection() do
    case ExIrc.Client.is_connected?(get_client()) do
      true -> :ok
      false -> reconnect()
    end
  end

  def get_random_redpic(subreddit) do
    url = "https://www.reddit.com/r/#{subreddit}/hot.json?over18=1"
    pixies = HTTPoison.get!(url)
    cond do
      pixies.status_code == 200 -> 
        pixies = pixies.body |> Poison.Parser.parse!
        pixies["data"]["children"]
        |> Enum.map(fn (data) -> data["data"]["url"] end)
        |> Enum.shuffle
        |> List.first
      true -> ""
    end
  end

  def get_persie() do
    red = Base.decode64!("YXNzaG9sZQ==")
    get_random_redpic(red)
  end

  def get_battlestation() do
    get_random_redpic("retrobattlestations")
  end

  def check_aotd() do
    aotd = get_persie()
    get_aotd_channels()
    |> Enum.map(fn (channel) -> 
      msg_to_channel("Asshole of the day: #{aotd}", channel)
    end)
  end

  def get_quote_of_the_day() do
    full_quote = HTTPoison.get!("https://www.brainyquote.com/quotes_of_the_day.html").body
                 |> Floki.find(".bqcpx")
                 |> List.first
                 |> Floki.raw_html
    quote_text = full_quote |> Floki.find(".b-qt") |> Floki.text
    quote_auth = full_quote |> Floki.find(".bq-aut") |> Floki.text
    "#{quote_text} -#{quote_auth}"
  end

  def get_motivation() do
    block = HTTPoison.get!("http://inspirationalshit.com/quotes").body |> Floki.find("blockquote")
    motivation = block |> Floki.find("p") |> Floki.text
    author = block |> Floki.find("cite") |> Floki.text
    "#{motivation} -#{author}"
  end

  def check_quote_of_the_day() do
    quote_of_the_day = get_quote_of_the_day()
    get_quote_of_the_day_channels()
    |> Enum.map(fn (channel) -> msg_to_channel(quote_of_the_day, channel) end)
  end

  def trump_check() do
    check_connection()
    check_trump_tweets()
    check_trump_fake_news()
    good_morning()
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

  def unix_to_localtime(arg) do
    case Integer.parse(arg) do
      :error -> ""
      _ ->  try do
              time = arg
                     |> String.to_integer
                     |> Timex.from_unix 
              
              if !is_map(time) do
                time
                |> Timex.Timezone.convert(Timex.Timezone.get("Europe/Helsinki"))
                "#{time}"
              end
            rescue
              ArgumentError -> ""
            end
    end
  end

  def add_tweet_id(tweet) do
    id = tweet.id
    latest_ids = get_latest_tweet_ids()
    if !Enum.member?(latest_ids, id) do
      latest_ids = latest_ids |> List.delete_at(0)
      update_setting(:latest_tweet_ids, latest_ids ++ [id])
    end
  end

  def populate_latest_tweet_ids() do
    [count: 5, screen_name: "realDonaldTrump"]
    |> ExTwitter.user_timeline()
    |> Enum.reverse
    |> Enum.map(fn(tweet) -> add_tweet_id(tweet) end)
  end

  def populate_latest_fake_news() do
    "http://feeds.washingtonpost.com/rss/politics"
    |> Scrape.feed(:minimal)
    |> Enum.map(fn(url) ->
      if String.match?(url, ~r/(trump)/) do handle_fake_news(url) end
    end)
  end
end
