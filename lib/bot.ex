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
  alias ExIrc.Channels
  alias ExIrc.Utils
  alias ExIrc.SenderInfo
  alias ExIrc.Client.Transport

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
    update_setting(:last_id, 0)
    update_setting(:latest_ids, [0,0,0,0,0])
    populate_last_ids()
    {:ok, %Config{config | :client => client}}
  end

  def update_setting(key, value) do
    Agent.update(:runtime_config, &Map.put(&1, key, value))
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

  def get_last_id() do
    get_setting(:last_id)
  end

  def get_latest_ids() do
    get_setting(:latest_ids)
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
    names = String.split(names_list, " ", trim: true)
            |> Enum.map(fn name -> " #{name}\n" end)
    Logger.info "Users logged in to #{channel}:\n#{names}"
    {:noreply, config}
  end

  def join_channel(channel) do
    Client.join get_client, channel
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

  def handle_url(input, config, channel) do
    title = 
      cond do
        Regex.match?(~r/(https*:\/\/).+(\.)(.+)/, input) ->
          handle_scrape(input)
        true ->
          nil
      end
    if (title != nil) do
      Client.msg config.client, :privmsg, channel, "#{title}"
    end
  end

  def handle_info({:received, msg, %SenderInfo{:nick => nick}, channel}, config) do
    Logger.info "#{nick} from #{channel}: #{msg}"
    # Trumpet doesn't print url on its base mission
#    Logger.info msg
#    if String.contains?(msg, "http") do
#      line_items = String.split(msg, " ")
#      for item <- line_items, do: handle_url(item, config, channel)
#    end
    {:noreply, config}
  end

  def handle_info({:mentioned, msg, %SenderInfo{:nick => nick}, channel}, config) do
    Logger.warn "#{nick} mentioned you in #{channel}"
    case String.contains?(msg, "hi") do
      true ->
        reply = "eat shit and die #{nick}"
        #Client.msg config.client, :privmsg, channel, reply
        Logger.info "Sent #{reply} to #{config.channel}"
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

  def terminate(_, state) do
    # Quit the channel and close the underlying client connection when the process is terminating
    Client.quit state.client, "Goodbye, cruel world."
    Client.stop! state.client
    :ok
  end

  # Check latest tweet of this ingloriuous bastard
  def trump_check_last() do
    #Logger.info "running trump_check"
    last_tweet = ExTwitter.user_timeline([count: 1, screen_name: "realDonaldTrump"]) |> List.first
    id = last_tweet.id
    if (id != get_last_id()) do
        text = last_tweet.text |> String.replace("\n", " ")
        config = get_config()
        client = get_client()
        if (is_list(config.channel)) do
          for channel <- config.channel, do: Client.msg client, :privmsg, channel, text
        else
          Client.msg client, :privmsg, config.channel, text
        end
    end
    update_setting(:last_id, id)
  end

  def handle_tweet(tweet) do
    id = tweet.id
    latest_ids = get_latest_ids()
    if (!Enum.member?(latest_ids, id)) do
      latest_ids = latest_ids |> List.delete_at(0)
      update_setting(:latest_ids, latest_ids ++ [id])
        #client = get_client()
        #Client.msg client, :privmsg, "#testtest", tweet.text
      config = get_config()
      client = get_client()
      if (tweet.retweeted_status == nil) do
        if (is_list(config.channel)) do
          for channel <- config.channel, do: Client.msg client, :privmsg, channel, tweet.text
        else
          Client.msg client, :privmsg, config.channel, tweet.text
        end
      end
    end
  end

  def trump_check() do
    latest =  ExTwitter.user_timeline([count: 5, screen_name: "realDonaldTrump"]) |> Enum.reverse
    for tweet <- latest, do: handle_tweet(tweet)
  end

  def fetch_ids(tweet) do
    id = tweet.id
    latest_ids = get_latest_ids()
    if (!Enum.member?(latest_ids, id)) do
      latest_ids = latest_ids |> List.delete_at(0)
      update_setting(:latest_ids, latest_ids ++ [id])
    end
    IO.inspect latest_ids
  end

  def populate_last_ids() do
     latest =  ExTwitter.user_timeline([count: 5, screen_name: "realDonaldTrump"]) |> Enum.reverse
     for tweet <- latest, do: fetch_ids(tweet)
  end

  def test_trump() do
    Logger.info "testing trump"
    last_tweet = ExTwitter.user_timeline([count: 1, screen_name: "realDonaldTrump"]) |> List.first
    text = last_tweet.text
    config = get_config()
    client = get_client()
    if (is_list(config.channel)) do
      for channel <- config.channel, do: Client.msg client, :privmsg, channel, text
    else
      Client.msg client, :privmsg, config.channel, text
    end
    Client.msg client, :privmsg, config.channel, text
    IO.inspect config
    IO.inspect client
    IO.inspect text
  end
end
