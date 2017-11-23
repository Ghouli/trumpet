defmodule Trumpet.AdminCommands do
  alias Trumpet.Bot

  def check_command("join", args) do
    args
    |> List.first()
    |> Bot.join_channel()
  end

  def check_command("part", args) do
    args
    |> List.first()
    |> Bot.part_channel()
  end

  def check_command("msg", args) do
    [channel | msg] = args
    msg
    |> Enum.join(" ")
    |> Bot.msg_to_channel(channel)
  end

  def check_command("op", args) do
    [channel, user] = args
    Bot.op_user(channel, user)
  end

  def check_command("deop", args) do
    [channel, user] = args
    Bot.deop_user(channel, user)
  end

  def check_command("admin", args) do
    [command, user] = args
    cond do
      command == "add" -> Bot.get_admins()
        |> Bot.add_to_list(user)
        |> Bot.update_admins()
      command == "del" -> Bot.get_admins()
        |> List.delete(user)
        |> Bot.update_admins()
      true -> ""
    end
  end

  def check_command(_, _), do: :ok
end
