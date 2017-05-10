defmodule Trumpet.Bot do
  use GenServer
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
    #Logger.debug "Connecting to #{server}:#{port}"
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
    update_setting(:tweet_channels, [])
    update_setting(:fake_news_channels, [])
    update_setting(:url_title_channels, [])
    populate_latest_tweet_ids()
    populate_latest_fake_news()
  end

  def update_setting(key, value) do
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
      :timer.sleep(1000) # This is to prevent dropouts for flooding
      Client.msg get_client(), :privmsg, channel, msg
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
    |> Enum.map(fn (channel) -> msg_tweet(channel, tweet) end)
  end

  def handle_scrape(url) do
    try do
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
    if String.contains?(msg, "http") && Enum.member?(get_url_title_channels(),channel) do
      msg
      |> String.split(" ")
      |> Enum.map(fn (item) -> handle_url_title(item, channel) end)
    end
  end

  def check_commands(msg, nick, channel) do
    cond do
      msg == "!tweet subscribe" ->
        channels = get_tweet_channels()
        case (!Enum.member?(channels, channel)) do
          true -> channels
                  |> add_to_list(channel)
                  |> update_tweet_channels()
                  msg_to_channel("MAGA!", channel)
          false -> msg_to_channel("Already subscribed", channel)
        end
      msg == "!tweet unsubscribe" ->
        channels = get_tweet_channels()
        case (Enum.member?(channels, channel)) do
          true -> channels
                  |> List.delete(channel)
                  |> update_tweet_channels()
                  msg_to_channel("Sad news from the failing #{channel}!", channel)
          false -> msg_to_channel("Not subscribed", channel)
        end
      msg == "!tweet last" ->
        get_latest_tweet_ids()
        |> Enum.reverse()
        |> List.first
        |> ExTwitter.show
        |> msg_tweet(channel)
      msg == "!fakenews subscribe" ->
        channels = get_fake_news_channels()
        case (!Enum.member?(channels, channel)) do
          true -> channels
                  |> add_to_list(channel)
                  |> update_fake_news_channels()
                  msg_to_channel("Subscribed.", channel)
          false -> msg_to_channel("Already subscribed.", channel)
        end
      msg == "!fakenews unsubscribe" ->
        channels = get_fake_news_channels()
        case (Enum.member?(channels, channel)) do
          true -> channels
                  |> List.delete(channel)
                  |> update_fake_news_channels()
                  msg_to_channel("Unsubscribed.", channel)
          false -> msg_to_channel("Not subscribed.", channel)
        end
      msg == "!fakenews last" ->
        article = get_latest_fake_news() |> Enum.reverse() |> List.first |> Scrape.article
        msg_to_channel(article.url, channel)
        case (Enum.member?(get_url_title_channels(), channel)) do
          true -> handle_url_title(article.url, channel)
          false -> :timer.sleep(1000)
        end
        msg_to_channel(article.description, channel)
      msg == "!title subscribe" ->
        channels = get_url_title_channels()
        case (!Enum.member?(channels, channel)) do
          true -> channels
                  |> add_to_list(channel)
                  |> update_url_title_channels()
                  msg_to_channel("Subscribed.", channel)
          false -> msg_to_channel("Already subscribed.", channel)
        end
      msg == "!title unsubscribe" ->
        channels = get_url_title_channels()
        case (Enum.member?(channels, channel)) do
          true -> channels
                  |> List.delete(channel)
                  |> update_url_title_channels()
                  msg_to_channel("Unsubscribed.", channel)
          false -> msg_to_channel("Not subscribed.", channel)
        end
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

  def trump_check() do
    check_trump_tweets()
    check_trump_fake_news()
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
