defmodule Trumpet.Bot do
  use GenServer

  require Logger

  defmodule Config do
    defstruct server: nil,
              port: nil,
              pass: nil,
              nick: nil,
              user: nil,
              name: nil,
              channel: nil,
              client: nil

    def from_params(params) when is_map(params) do
      Enum.reduce(params, %Config{}, fn {k, v}, acc ->
        case Map.has_key?(acc, k) do
          true -> Map.put(acc, k, v)
          false -> acc
        end
      end)
    end
  end

  alias ExIRC.Client
  alias ExIRC.SenderInfo
  alias Trumpet.Commands
  alias Trumpet.Paradox
  alias Trumpet.Utils

  def start_link(%{:nick => nick} = params) when is_map(params) do
    config = Config.from_params(params)
    GenServer.start_link(__MODULE__, [config], name: String.to_atom(nick))
  end

  def init([config]) do
    IO.puts("Initializing state..")

    # Start the client and handler processes, the ExIRC supervisor is automatically started when your app runs
    {:ok, client} = ExIRC.start_link!()

    # Register the event handler with ExIRC
    Client.add_handler(client, self())

    {:ok, _agent} = Agent.start_link(fn -> %{} end, name: :runtime_config)

    update_setting(:client, client)
    update_setting(:config, config)
    init_settings()

    IO.puts("Done!")

    # No need to connect if just running tests..
    case Mix.env() == :test do
      true -> IO.puts("Running tests...")
      false -> Client.connect!(client, config.server, config.port)
    end

    init_msg_sender()

    {:ok, %Config{config | :client => client}}
  end

  def init_msg_sender do
    sender = get_msg_sender()

    if sender == nil || !Process.alive?(sender) do
      Logger.warn("Restarting msg_sender")
      {:ok, sender} = start_msg_sender()
      update_msg_sender(sender)
      msg_admins("Restarted msg_sender")
    end
  end

  def channels, do: get_client() |> ExIRC.Client.channels()
  def connected?, do: get_client() |> ExIRC.Client.is_connected?()

  def init_settings do
    update_setting(:msg_queue, [])
    update_setting(:last_tweet_id, 0)
    update_setting(:latest_fake_news, for(n <- 1..40, do: n))
    update_setting(:tweet_channels, Application.get_env(:trumpet, :tweet_channels, []))
    update_setting(:fake_news_channels, Application.get_env(:trumpet, :fake_news_channels, []))
    update_setting(:url_title_channels, Application.get_env(:trumpet, :url_title_channels, []))
    update_setting(:devdiary_channels, Application.get_env(:trumpet, :devdiary_channels, []))

    update_setting(
      :quote_of_the_day_channels,
      Application.get_env(:trumpet, :quote_of_the_day_channels, [])
    )

    update_setting(:admins, Application.get_env(:trumpet, :admins, []))
    update_setting(:stellaris, %{})
    update_setting(:hoi4, %{})
    update_setting(:eu4, %{})
    update_setting(:ck2, %{})

    update_channels(
      Application.get_env(:trumpet, :channels, []) ++
        get_function_channels(:tweet_channels) ++
        get_function_channels(:fake_news_channels) ++
        get_function_channels(:url_title_channels) ++
        get_function_channels(:devdiary_channels) ++
        get_function_channels(:quote_of_the_day_channels)
    )

    [screen_name: "realDonaldTrump", count: 1]
    |> ExTwitter.user_timeline()
    |> List.first()
    |> update_last_tweet()
    # Commands.populate_latest_fake_news()
    Paradox.populate_paradox_devdiaries()
  end

  defp update_setting(key, value \\ []),
    do: Agent.update(:runtime_config, &Map.put(&1, key, value))

  def update_last_tweet(tweet), do: update_setting(:last_tweet, tweet)
  def update_latest_fake_news(urls), do: update_setting(:latest_fake_news, urls)
  def update_last_fake_news(url), do: update_setting(:last_fake_news, url)
  def update_tweet_channels(channels), do: update_setting(:tweet_channels, channels)
  def update_fake_news_channels(channels), do: update_setting(:fake_news_channels, channels)
  def update_url_title_channels(channels), do: update_setting(:url_title_channels, channels)

  def update_quote_of_the_day_channels(channels),
    do: update_setting(:quote_of_the_day_channels, channels)

  def update_function_channels(channels, function), do: update_setting(function, channels)
  def update_admins(admins), do: update_setting(:admins, admins)

  # Used by Paradox module
  def update_ck2_devdiary_map(map), do: update_setting(:ck2, map)
  def update_eu4_devdiary_map(map), do: update_setting(:eu4, map)
  def update_hoi4_devdiary_map(map), do: update_setting(:hoi4, map)
  def update_stellaris_devdiary_map(map), do: update_setting(:stellaris, map)
  def update_devdiary_map(map_atom, map), do: update_setting(map_atom, map)

  defp get_setting(key), do: Agent.get(:runtime_config, &Map.get(&1, key))
  def get_config, do: get_setting(:config)

  def get_client, do: get_setting(:client)
  def update_channels(channels), do: update_setting(:channels, Enum.uniq(channels))
  def get_channels, do: get_setting(:channels)

  def get_last_tweet, do: get_setting(:last_tweet)
  def get_last_tweet_id, do: get_last_tweet().id
  def get_last_tweet_timestamp, do: get_last_tweet() |> Utils.get_tweet_timestamp()
  def get_latest_fake_news, do: get_setting(:latest_fake_news)
  def get_last_fake_news, do: get_setting(:last_fake_news)
  def get_tweet_channels, do: get_setting(:tweet_channels)
  def get_fake_news_channels, do: get_setting(:fake_news_channels)
  def get_url_title_channels, do: get_setting(:url_title_channels)
  def get_quote_of_the_day_channels, do: get_setting(:quote_of_the_day_channels)
  def get_function_channels(function), do: get_setting(function)
  def get_admins, do: get_setting(:admins)

  # Used by Paradox module
  def get_devdiary_channels, do: get_setting(:devdiary_channels)
  def get_ck2_devdiary_map, do: get_setting(:ck2)
  def get_eu4_devdiary_map, do: get_setting(:eu4)
  def get_hoi4_devdiary_map, do: get_setting(:hoi4)
  def get_stellaris_devdiary_map, do: get_setting(:stellaris)
  def get_devdiary_map(map_atom), do: get_setting(map_atom)

  def add_to_list(list, item), do: list ++ [item]

  def update_msg_sender(sender), do: update_setting(:msg_sender, sender)
  def get_msg_sender, do: get_setting(:msg_sender)

  def update_msg_queue(queue), do: update_setting(:msg_queue, queue)
  def get_msg_queue, do: get_setting(:msg_queue)

  def add_msg(msg) do
    queue =
      get_msg_queue()
      |> add_to_list(msg)

    update_msg_queue(queue)
    init_msg_sender()
  end

  def get_msg do
    queue = get_msg_queue()

    case Enum.empty?(queue) do
      true ->
        nil

      false ->
        [head | tail] = queue
        update_msg_queue(tail)
        head
    end
  end

  def change_nick(new_nick) do
    Logger.debug(fn ->
      "Trying to change nick to #{new_nick}"
    end)

    client = get_client()
    ExIRC.Client.nick(client, new_nick)
  end

  def handle_info({:connected, server, port}, config) do
    Logger.info(fn ->
      "Connected to #{server}:#{port}"
    end)

    Logger.debug(fn ->
      "Logging to #{server}:#{port} as #{config.nick}.."
    end)

    Client.logon(config.client, config.pass, config.nick, config.user, config.name)
    {:noreply, config}
  end

  def handle_info(:logged_in, config) do
    Logger.info(fn ->
      "Logged in to #{config.server}:#{config.port}"
    end)

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
    Logger.info(fn ->
      "Disconnected from #{config.server}:#{config.port}, trying to reconnect"
    end)

    {:noreply, config}
  end

  def handle_info({:joined, channel}, config) do
    Logger.info(fn ->
      "Joined #{channel}"
    end)

    # Client.msg config.client, :privmsg, config.channel, "Hello world!"
    {:noreply, config}
  end

  def handle_info({:names_list, channel, names_list}, config) do
    names =
      names_list
      |> String.split(" ", trim: true)
      |> Enum.map(fn name -> " #{name}\n" end)

    Logger.info("Users logged in to #{channel}:\n#{names}")
    {:noreply, config}
  end

  def handle_info({:received, msg, %SenderInfo{:nick => nick}, channel}, config) do
    Logger.info("#{nick} from #{channel}: #{msg}")

    case String.starts_with?(msg, "!") do
      true -> Task.start(__MODULE__, :check_commands, [msg, nick, channel])
      false -> Task.start(__MODULE__, :check_title, [msg, nick, channel])
    end

    {:noreply, config}
  end

  def handle_info({:mentioned, msg, %SenderInfo{:nick => nick}, channel}, config) do
    Logger.warn("#{nick} mentioned you in #{channel}")
    msg_admins("#{channel} <#{nick}> #{msg}")

    {:noreply, config}
  end

  def handle_info({:received, msg, %SenderInfo{:nick => nick}}, config) do
    Logger.warn("#{nick}: #{msg}")

    case Enum.member?(get_admins(), nick) do
      true ->
        Task.start(__MODULE__, :admin_command, [msg, nick])

      false ->
        msg_admins("#{nick} msg: #{msg}")
        Task.start(__MODULE__, :check_commands, [msg, nick, nick])
    end

    {:noreply, config}
  end

  def handle_info({:notice, msg, %SenderInfo{:nick => nick}}, config) do
    Logger.warn("#{nick} sent notice: #{msg}")

    if nick != [] && !String.starts_with?(msg, "[#") do
      msg_admins("#{nick} notice: #{msg}")
    end

    {:noreply, config}
  end

  def handle_info({:invited, %SenderInfo{:nick => nick}, channel}, config) do
    Logger.warn("#{nick} invited us to #{channel}")
    msg_admins("#{nick} invited us to #{channel}")

    if Enum.member?(get_admins(), nick) do
      join_channel(channel)
    end

    {:noreply, config}
  end

  def handle_info({:kicked, %SenderInfo{:nick => nick}, channel, reason}, config) do
    Logger.warn("#{nick} kicked us from #{channel}")
    msg_admins("#{nick} kicked us from #{channel}, reason: #{reason}")

    get_channels()
    |> List.delete(channel)
    |> update_channels()

    {:noreply, config}
  end

  def handle_info({:kicked, nick, %SenderInfo{:nick => by}, channel, _reason}, config) do
    Logger.warn("#{nick} was kicked from #{channel} by #{by}")
    {:noreply, config}
  end

  # Catch-all for messages you don't care about
  def handle_info(_msg, config) do
    # IO.inspect _msg
    {:noreply, config}
  end

  def join_channel(channel) do
    update_channels(get_channels() ++ [channel])
    Client.join(get_client(), channel)
  end

  def part_channel(channel) do
    get_channels() |> List.delete(channel) |> update_channels()
    Client.part(get_client(), channel)
  end

  def terminate(_, state) do
    # Quit the channel and close the underlying client connection when the process is terminating
    Client.quit(state.client, "Goodbye, cruel world.")
    Client.stop!(state.client)
    :ok
  end

  def msg_admins(channel, nick, msg) do
    msg_admins("#{channel} #{nick}: #{msg}")
  end

  def msg_admins(nick, msg) do
    msg_admins("#{nick}: #{msg}")
  end

  def msg_admins(msg) do
    Task.start(__MODULE__, :send_admin_messages, [msg])
  end

  def send_admin_messages(msg) do
    get_admins()
    |> Enum.each(fn admin -> msg_to_user("#{msg}", admin) end)
  end

  def msg_to_user(msg, nick), do: msg_to_channel(msg, nick)

  def msg_to_channel(msg, channel) do
    if is_binary(channel) && is_binary(msg) do
      add_msg(%{msg: msg, to: channel})
    end
  end

  def start_msg_sender do
    Task.start(__MODULE__, :send_msg, [])
  end

  def send_msg do
    msg = get_msg()

    if msg != nil && is_map(msg) do
      ExIRC.Client.msg(get_client(), :privmsg, msg.to, msg.msg)
      # This is to prevent dropouts for flooding
      :timer.sleep(500)
    end

    :timer.sleep(500)
    send_msg()
  end

  def op_user(channel, user) do
    ExIRC.Client.mode(get_client(), channel, "+o", user)
  end

  def deop_user(channel, user) do
    ExIRC.Client.mode(get_client(), channel, "-o", user)
  end

  def voice_user(channel, user) do
    ExIRC.Client.mode(get_client(), channel, "+v", user)
  end

  def devoice_user(channel, user) do
    ExIRC.Client.mode(get_client(), channel, "-v", user)
  end

  def kick_user(channel, user, reason) do
    ExIRC.Client.kick(get_client(), channel, user, reason)
  end

  def kick_user(channel, user) do
    ExIRC.Client.kick(get_client(), channel, user)
  end

  def quakenet_auth do
    client = get_client()
    user = get_config().user
    pass = get_config().pass
    ExIRC.Client.msg(client, :privmsg, "q@cserve.quakenet.org", "auth #{user} #{pass}")
  end

  def quakenet_hide do
    client = get_client()
    nick = get_config().nick
    ExIRC.Client.mode(client, nick, "+x")
  end

  def admin_command(msg, nick) do
    IO.inspect(msg)
    IO.inspect(nick)
    [cmd | args] = msg |> String.split(" ")
    Trumpet.AdminCommands.check_command(cmd, args, nick)
  end

  def check_commands(msg, nick, channel) do
    Commands.handle_command(msg, nick, channel)
  end

  def check_title(msg, nick, channel) do
    Commands.check_title(msg, nick, channel)
  end

  def join_channels do
    Enum.each(get_channels(), fn channel -> join_channel(channel) end)
  end

  def reconnect do
    if Mix.env() != :test do
      IO.puts("Reconnecting")
      client = get_client()
      config = get_config()
      Client.connect!(client, config.server, config.port)
    end
  end

  def check_connection do
    init_msg_sender()

    case ExIRC.Client.is_connected?(get_client()) do
      true -> :ok
      false -> reconnect()
    end
  end
end
