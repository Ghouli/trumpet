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
  alias ExIrc.SenderInfo
  alias Trumpet.Commands
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

  def channels(), do: get_client() |> ExIrc.Client.channels()
  def is_connected?(), do: get_client() |> ExIrc.Client.is_connected?()

  def init_settings() do
    update_setting(:last_tweet_id, 0)
    update_setting(:latest_fake_news, (for n <- 1..20, do: n))
    update_setting(:tweet_channels, Application.get_env(:trumpet, :tweet_channels, []))
    update_setting(:fake_news_channels, Application.get_env(:trumpet,:fake_news_channels, []))
    update_setting(:url_title_channels, Application.get_env(:trumpet, :url_title_channels, []))
    update_setting(:aotd_channels, Application.get_env(:trumpet, :aotd_channels, []))
    update_setting(:devdiary_channels, Application.get_env(:trumpet, :devdiary_channels, []))
    update_setting(:quote_of_the_day_channels, Application.get_env(:trumpet, :quote_of_the_day_channels, []))
    update_setting(:admins, Application.get_env(:trumpet, :admins, []))
    update_setting(:stellaris, %{})
    update_setting(:hoi4, %{})
    update_setting(:eu4, %{})
    update_setting(:ck2, %{})
    update_channels(Application.get_env(:trumpet, :channels, [])
      ++ get_function_channels(:tweet_channels)
      ++ get_function_channels(:fake_news_channels)
      ++ get_function_channels(:url_title_channels)
      ++ get_function_channels(:aotd_channels)
      ++ get_function_channels(:devdiary_channels)
      ++ get_function_channels(:quote_of_the_day_channels))
    Commands.populate_last_tweet_id()
    Commands.populate_latest_fake_news()
    Paradox.populate_paradox_devdiaries()
  end

  defp update_setting(key, value \\ []), do: Agent.update(:runtime_config, &Map.put(&1, key, value))
  def update_last_tweet_id(tweets), do: update_setting(:last_tweet_id, tweets)
  def update_latest_fake_news(urls), do: update_setting(:latest_fake_news, urls)
  def update_tweet_channels(channels), do: update_setting(:tweet_channels, channels)
  def update_fake_news_channels(channels), do: update_setting(:fake_news_channels, channels)
  def update_url_title_channels(channels), do: update_setting(:url_title_channels, channels)
  def update_aotd_channels(channels), do: update_setting(:aotd_channels, channels)
  def update_quote_of_the_day_channels(channels), do: update_setting(:quote_of_the_day_channels, channels)
  def update_function_channels(channels, function), do: update_setting(function, channels)
  def update_admins(admins), do: update_setting(:admins, admins)

  # Used by Paradox module
  def update_ck2_devdiary_map(map), do: update_setting(:ck2, map)
  def update_eu4_devdiary_map(map), do: update_setting(:eu4, map)
  def update_hoi4_devdiary_map(map), do: update_setting(:hoi4, map)
  def update_stellaris_devdiary_map(map), do: update_setting(:stellaris, map)
  def update_devdiary_map(map_atom, map), do: update_setting(map_atom, map)

  defp get_setting(key), do: Agent.get(:runtime_config, &Map.get(&1, key))
  def get_config(), do: get_setting(:config)

  def get_client(), do: get_setting(:client)
  def update_channels(channels), do: update_setting(:channels, Enum.uniq(channels))
  def get_channels(), do: get_setting(:channels)

  def get_last_tweet_id(), do: get_setting(:last_tweet_id)
  def get_latest_fake_news(), do: get_setting(:latest_fake_news)
  def get_tweet_channels(), do: get_setting(:tweet_channels)
  def get_fake_news_channels(), do: get_setting(:fake_news_channels)
  def get_url_title_channels(), do: get_setting(:url_title_channels)
  def get_aotd_channels(), do: get_setting(:aotd_channels)
  def get_quote_of_the_day_channels(), do: get_setting(:quote_of_the_day_channels)
  def get_function_channels(function), do: get_setting(function)
  def get_admins(), do: get_setting(:admins)

  # Used by Paradox module
  def get_devdiary_channels(), do: get_setting(:devdiary_channels)
  def get_ck2_devdiary_map(), do: get_setting(:ck2)
  def get_eu4_devdiary_map(), do: get_setting(:eu4)
  def get_hoi4_devdiary_map(), do: get_setting(:hoi4)
  def get_stellaris_devdiary_map(), do: get_setting(:stellaris)
  def get_devdiary_map(map_atom), do: get_setting(map_atom)

  def add_to_list(list, item), do: list ++ [item]

  def handle_info({:connected, server, port}, config) do
    Logger.debug "Connected to #{server}:#{port}"
    Logger.debug "Logging to #{server}:#{port} as #{config.nick}.."
    Client.logon config.client, config.pass, config.nick, config.user, config.name
    {:noreply, config}
  end

  def handle_info(:logged_in, config) do
    Logger.debug "Logged in to #{config.server}:#{config.port}"
    # Try to auth & hide if we are in quakenet
    if String.contains?(config.server, "quakenet") && config.pass != nil do
      Logger.debug("Authenticating..")
      quakenet_auth()
      Logger.debug("Hiding..")
      quakenet_hide()
    end
    Logger.debug("Joining channels..")
    join_channels()
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
      true -> Task.start(__MODULE__ , :check_commands, [msg, nick, channel])
      false -> Task.start(__MODULE__, :check_title, [msg, nick, channel])
    end
    {:noreply, config}
  end

  def handle_info({:mentioned, msg, %SenderInfo{:nick => nick}, channel}, config) do
    Logger.warn "#{nick} mentioned you in #{channel}"
    Client.msg config.client, :privmsg, get_admins() |> List.first, "#{channel} <#{nick}> #{msg}"
    {:noreply, config}
  end

  def handle_info({:received, msg, %SenderInfo{:nick => nick}}, config) do
    Logger.warn "#{nick}: #{msg}"
    if Enum.member?(get_admins(), nick) do
      Task.start(__MODULE__ , :admin_command, [msg, nick])
    end
    {:noreply, config}
  end

  def handle_info({:notice, msg, %SenderInfo{:nick => nick}}, config) do
    Logger.warn "#{nick} sent notice: #{msg}"
    if nick != [] do
      Client.msg config.client, :privmsg, get_admins() |> List.first, "#{nick}: #{msg}"
    end
    {:noreply, config}
  end

  def handle_info({:invited, %SenderInfo{:nick => nick}, channel}, config) do
    Logger.warn "#{nick} invited us to #{channel}"
    Client.msg config.client, :privmsg, get_admins() |> List.first, "#{nick} invited us to #{channel}"
    if Enum.member?(get_admins(), nick) do
      join_channel(channel)
    end
    {:noreply, config}
  end

  def handle_info({:kicked, %SenderInfo{:nick => nick}, channel, reason}, config) do
    Logger.warn "#{nick} kicked us from #{channel}"
    Client.msg config.client, :privmsg, get_admins() |> List.first, "#{nick} kicked us from #{channel}, reason: #{reason}"
    get_channels()
    |> List.delete(channel)
    |> update_channels()
    {:noreply, config}
  end

  def handle_info({:kicked, nick, %SenderInfo{:nick => by}, channel, reason}, config) do
    Logger.warn "#{nick} was kicked from #{channel} by #{by}"
    {:noreply, config}
  end

  # Catch-all for messages you don't care about
  def handle_info(_msg, config) do
    #IO.inspect _msg
    {:noreply, config}
  end

  def join_channel(channel) do
    get_channels() ++ [channel] |> update_channels()
    Client.join get_client(), channel
  end

  def part_channel(channel) do
    get_channels() |> List.delete(channel) |> update_channels()
    Client.part get_client(), channel
  end

  def terminate(_, state) do
    # Quit the channel and close the underlying client connection when the process is terminating
    Client.quit state.client, "Goodbye, cruel world."
    Client.stop! state.client
    :ok
  end

  def msg_to_channel(msg, channel) do
    if is_binary(channel) && is_binary(msg) do
      ExIrc.Client.msg(get_client(), :privmsg, channel, msg)
      :timer.sleep(1000) # This is to prevent dropouts for flooding
    end
  end

  def op_user(channel, user) do
    ExIrc.Client.mode(get_client(), channel, "+o", user)
  end
  def deop_user(channel, user) do
    ExIrc.Client.mode(get_client(), channel, "-o", user)
  end

  def voice_user(channel, user) do
    ExIrc.Client.mode(get_client(), channel, "+v", user)
  end
  def devoice_user(channel, user) do
    ExIrc.Client.mode(get_client(), channel, "-v", user)
  end

  def kick_user(channel, user, reason) do
    ExIrc.Client.kick(get_client(), channel, user, reason)
  end
  def kick_user(channel, user) do
    ExIrc.Client.kick(get_client(), channel, user)
  end

  def quakenet_auth() do
    client = get_client()
    user = get_config().user
    pass = get_config().pass
    ExIrc.Client.msg(client, :privmsg, "q@cserve.quakenet.org", "auth #{user} #{pass}")
  end

  def quakenet_hide() do
    client = get_client()
    user = get_config().user
    ExIrc.Client.mode(client, user, "+x")
  end

  def admin_command(msg, nick) do
    [cmd | args] = msg |> String.split(" ")
    cond do
      cmd == "join" ->
        args
        |> List.first()
        |> join_channel()
      cmd == "part" ->
        args
        |> List.first()
        |> part_channel()
      cmd == "msg" ->
        [channel | msg] = args
        msg
        |> Enum.join(" ")
        |> msg_to_channel(channel)
      cmd == "op" ->
        [channel, user] = args
        op_user(channel, user)
      cmd == "deop" ->
        [channel, user] = args
        deop_user(channel, user)
      cmd == "admin" ->
        [command, user] = args
        cond do
          command == "add" -> get_admins() |> add_to_list(user) |> update_admins()
          command == "del" -> get_admins() |> List.delete(user) |> update_admins()
          true -> ""
        end
      true ->
        :ok
    end
  end

  def check_commands(msg, nick, channel) do
    Commands.handle_command(msg, nick, channel)
  end

  def check_title(msg, nick, channel) do
    Commands.check_title(msg, nick, channel)
  end

  def join_channels() do
    get_channels()
    |> Enum.each(fn(channel) -> join_channel(channel) end)
  end

  def reconnect() do
    client = get_client()
    config = get_config()
    Client.connect! client, config.server, config.port
  end

  def check_connection() do
    case ExIrc.Client.is_connected?(get_client()) do
      true -> :ok
      false -> reconnect()
    end
  end
end
