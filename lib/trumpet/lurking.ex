defmodule Trumpet.Lurking do
  defmodule GameState do
    defstruct description:  "",
              location:     "",
              score:        "",
              moves:        ""
  end
  defmodule Room do
    defstruct description: nil,
              location:    nil,
              north:       nil,
              northwest:   nil,
              west:        nil,
              southwest:   nil,
              south:       nil,
              southeast:   nil,
              east:        nil,
              norteast:    nil,
              up:          nil,
              down:        nil
  end

  alias Trumpet.Bot

  def init_game() do
    game_path = "/home/ghouli/code/trumpet/frotz/dfrotz /home/ghouli/code/trumpet/frotz/LURKING.DAT"
    game = Port.open({:spawn, game_path}, [:binary])
    Bot.update_game_process(game)
    Bot.update_game_map(Map.new())
  end

  def stop_game() do
    Port.close(get_game())
    Bot.update_game_process(:inactive)
  end

  defp get_game() do
    Bot.get_game_process()
  end

  def split_messages(message) do
    case String.length(message) > 400 do
      true  -> [last | rest] = String.split(message, ".", trim: true)
        |> Enum.reverse()
        rest = rest |> Enum.reverse() |> Enum.join(".")
        last = last |> String.trim()
        ["#{rest}.", last]
      false -> message
    end
  end

  def handle_response(raw) do
    [header | description] = raw |> String.split("\n\n", parts: 2)
    IO.puts "header"
    IO.inspect header
    IO.puts "description"
    IO.inspect description
    if !Enum.empty?(description) do
      IO.puts "not empty"
      IO.puts "checking"
      if description |> List.first() |> String.split("\n\n") |> List.first == String.split(header, "    ", trim: true) |> List.first() |> String.trim() do
        IO.puts "Empty desc?"
        [location, score, moves] = header 
          |> String.split("    ", trim: true)
          |> Enum.map(fn(item) -> String.trim(item) end)
        IO.puts "header ok"
        IO.inspect header
        description = description |> List.first() |> String.split("\n\n") |> List.first() |> String.trim()
        IO.puts "description ok"
        IO.inspect description
        %GameState{location: location, score: score, moves: moves, description: [description]}
      else
        case description |> List.first() == ">" do
          true -> %{location: "", score: "", moves: "", description: header |> String.replace("\n", " ")}
          false ->
            [location, score, moves] = header 
              |> String.split("    ", trim: true)
              |> Enum.map(fn(item) -> String.trim(item) end)
            [head | tail] = description
              |> Enum.join()
              |> String.replace("\n\n", "_%")
              |> String.replace("\n", " ")
              |> String.split("_%")
              |> List.delete(">") # Removes shell char
              |> List.delete(location)
            head = head |> String.replace_leading(location, "") |> String.trim() # This doesn't need to be printed twice
            #Split description messages if too long for irc (~400)
            head = head |> split_messages()
            tail = tail |> Enum.map(fn (message) -> split_messages(message) end)
            description = [head] ++ tail |> List.flatten()
            %GameState{location: location, score: score, moves: moves, description: description}
        end
      end
    else
      IO.puts "empty"
      %GameState{description: header}
    end
  end

  def game_input(input) do
    IO.inspect input
    input = input |> String.trim()
    Port.command(get_game(), "#{input}\n")
    raw = game_output()
    case raw == :empty do
      true  -> %{location: "", score: "", moves: "", description: [""]}
      false -> handle_response(raw)
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
      {:ok, output} -> get_game_output(get_game(), output) #call recursively until buffer empty
      {:empty, output} -> output
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
      true -> :inactive
      false ->
        state = game_input(message)
        IO.inspect state
        case state.location == "" do
          true  -> send_messages_to_irc("#{state.description}", channel)
          false -> 
            send_messages_to_irc("Location: #{state.location} Score: #{state.score} Moves #{state.moves}", channel)
            state.description
            |> Enum.each(fn(msg) -> send_messages_to_irc(msg, channel) end) 
        end  
    end  
  end

  def send_messages_to_irc(message, channel) do
    Bot.msg_to_channel_now(message, channel)
    :timer.sleep(500)
  end
end