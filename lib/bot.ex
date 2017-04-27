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

    {:ok, agent} = (Agent.start_link fn -> [] end, name: :agent)
    Agent.update(:agent, fn list -> [client | list] end)

    {:ok, %Config{config | :client => client}}
  end

  def get_client() do
    client = Agent.get(:agent, fn list -> list end) |> List.first
    IO.inspect client
    client
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

  def handle_scrape(url) do
    page = Scrape.website(url)
    if page.title == nil do
      page.url
    else
      page.title |> String.trim
    end
  end

  def join_channel(channel) do
    Client.join get_client, channel
  end

  def handle_url(input, config, channel) do
    cond do
      String.starts_with?(input, "http://") ->
        title = handle_scrape(input)
        Client.msg config.client, :privmsg, channel, "\x02title:\x0F #{title}" 
      String.starts_with?(input, "https://") ->
        title = handle_scrape(input)
        Client.msg config.client, :privmsg, channel, "\x02title:\x0F #{title}"
      true ->
        Logger.info "Not url"
    end
  end

  def handle_info({:received, msg, %SenderInfo{:nick => nick}, channel}, config) do
    Logger.info "#{nick} from #{channel}: #{msg}"
    Logger.info msg
    if String.contains?(msg, "http") do
      line_items = String.split(msg, " ")
      for item <- line_items, do: handle_url(item, config, channel)
    end
    {:noreply, config}
  end

  def handle_info({:mentioned, msg, %SenderInfo{:nick => nick}, channel}, config) do
    Logger.warn "#{nick} mentioned you in #{channel}"
    case String.contains?(msg, "hi") do
      true ->
        reply = "Hi #{nick}!"
        Client.msg config.client, :privmsg, config.channel, reply
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
end