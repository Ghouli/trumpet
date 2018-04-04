defmodule Trumpet.Lurking do
  defmodule GameState do
    defstruct description: "",
              location: "",
              score: "",
              moves: ""
  end

  defmodule Room do
    defstruct description: nil,
              location: nil,
              north: nil,
              northwest: nil,
              west: nil,
              southwest: nil,
              south: nil,
              southeast: nil,
              east: nil,
              norteast: nil,
              up: nil,
              down: nil
  end

  alias Trumpet.Bot

  defp app_dir(), do: Application.app_dir(:trumpet) |> String.split("_build") |> List.first()

  defp dfrotz_path,
    do: Application.get_env(:trumpet, :dfrotz_path, "#{app_dir()}deps/frotz/dfrotz")

  defp game_path, do: Application.get_env(:trumpet, :game_path)
  defp game_file, do: Application.get_env(:trumpet, :game_file)

  defp game_state(), do: Bot.get_game_process()
  defp get_game(), do: game_state()

  def init_game(channel) do
    case game_state() != :inactive do
      true ->
        Bot.msg_to_channel("Game already active", channel)

      false ->
        start_game(game_file(), channel)
    end
  end

  def start_game(game, channel) do
    case !File.exists?("#{game_path()}#{game}") do
      true ->
        Bot.msg_to_channel("Gamefile doesn't exist", channel)

      false ->
        game = Port.open({:spawn, "#{dfrotz_path()} -m -p #{game_path()}#{game}"}, [:binary])

        Bot.update_game_process(game)
        Bot.update_game_map(Map.new())
        handle_irc_message("", channel)
    end
  end

  def list_games(channel) do
    games =
      (Path.wildcard("#{game_path()}*.dat") ++ Path.wildcard("#{game_path()}*.DAT"))
      |> Enum.map(fn item -> String.split(item, "/") |> Enum.reverse() |> List.first() end)
      |> Enum.join(" ")

    Bot.msg_to_channel("Found following game files: #{games}", channel)
  end

  def stop_game(channel) do
    case game_state() == :inactive do
      true ->
        Bot.msg_to_channel("Game not active", channel)

      false ->
        Port.close(get_game())
        Bot.update_game_process(:inactive)
        Bot.msg_to_channel("Game stopped", channel)
    end
  end

  def split_messages(message) do
    case String.length(message) > 400 do
      true ->
        [last | rest] =
          String.split(message, ".", trim: true)
          |> Enum.reverse()

        rest = rest |> Enum.reverse() |> Enum.join(".")
        last = last |> String.trim()
        ["#{rest}.", last]

      false ->
        message
    end
  end

  def update_state(raw) do
    IO.puts("raw: #{raw}")
    [header | description] = raw |> String.split("\n", parts: 2)
    IO.puts("header")
    IO.inspect(header)
    IO.puts("description")
    IO.inspect(description)

    if !Enum.empty?(description) do
      IO.puts("not empty")
      IO.puts("checking")

      if description |> List.first() |> String.split("\n\n") |> List.first() ==
           String.split(header, "    ", trim: true) |> List.first() |> String.trim() do
        IO.puts("Empty desc?")

        [location, score, moves] =
          header
          |> String.split("    ", trim: true)
          |> Enum.map(fn item -> String.trim(item) end)

        IO.puts("header ok")
        IO.inspect(header)

        description =
          description |> List.first() |> String.split("\n\n") |> List.first() |> String.trim()

        IO.puts("description ok")
        IO.inspect(description)
        %GameState{location: location, score: score, moves: moves, description: [description]}
      else
        case description |> List.first() == ">" do
          true ->
            %{
              location: "",
              score: "",
              moves: "",
              description: header |> String.replace("\n", " ")
            }

          false ->
            [location, score, moves] =
              header
              |> String.split("    ", trim: true)
              |> Enum.map(fn item -> String.trim(item) end)

            [head | tail] =
              description
              |> Enum.join()
              |> String.replace("\n\n", "_%")
              |> String.replace("\n", " ")
              |> String.split("_%")
              # Removes shell char
              |> List.delete(">")
              |> List.delete(location)

            # This doesn't need to be printed twice
            head = head |> String.replace_leading(location, "") |> String.trim()
            # Split description messages if too long for irc (~400)
            head = split_messages(head)
            tail = Enum.map(tail, fn message -> split_messages(message) end)
            description = ([head] ++ tail) |> List.flatten()
            %GameState{location: location, score: score, moves: moves, description: description}
        end
      end
    else
      IO.puts("empty")
      %GameState{description: header}
    end
  end

  def handle_response(raw, channel) do
    state = update_state(raw)

    case state.location == "" do
      true ->
        send_messages_to_irc("#{state.description}", channel)

      false ->
        send_messages_to_irc(
          "Location: #{state.location} Score: #{state.score} Moves #{state.moves}",
          channel
        )

        state.description
        |> Enum.each(fn msg -> send_messages_to_irc(msg, channel) end)
    end
  end

  def game_input(input, channel) do
    IO.puts("game input:")
    IO.inspect(input)
    input = input |> String.trim()
    Port.command(get_game(), "#{input}\n")
    raw = game_output()

    case raw == :empty do
      true ->
        %{location: "", score: "", moves: "", description: [""]}

      false ->
        Task.start(__MODULE__, :handle_response, [raw, channel])
    end
  end

  def game_output() do
    case get_all_output() do
      {:ok, output} -> output
      {:empty, output} -> output
      "" -> :empty
    end
  end

  def get_all_output() do
    result = get_game_output(get_game(), "")

    case result do
      # call recursively until buffer empty
      {:ok, output} ->
        get_game_output(get_game(), output)

      {:empty, output} ->
        output
    end
  end

  def get_game_output(game, output) do
    receive do
      {^game, {:data, result}} -> {:ok, "#{output}#{result}"}
    after
      1000 -> {:empty, output}
    end
  end

  def handle_irc_message(message, channel) do
    case get_game() == :inactive do
      true ->
        :inactive

      false ->
        IO.puts("message from irc")
        IO.inspect(message)
        game_input(message, channel)
    end
  end

  def send_messages_to_irc(message, channel) do
    if message != ">I beg your pardon?" && message != ">" do
      Bot.msg_to_channel(message, channel)
      :timer.sleep(500)
    end
  end
end
