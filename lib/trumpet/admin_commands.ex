defmodule Trumpet.AdminCommands do
  alias Trumpet.Bot

  def check_command("join", args, _nick) do
    args
    |> List.first()
    |> Bot.join_channel()
  end

  def check_command("part", args, _nick) do
    args
    |> List.first()
    |> Bot.part_channel()
  end

  def check_command("channels", args, nick) do
    title = Bot.get_url_title_channels()
    paradox = Bot.get_devdiary_channels()
    tweet = Bot.get_tweet_channels()
    qotd = Bot.get_quote_of_the_day_channels()

    channels =
      Bot.get_channels()
      |> Enum.filter(fn x -> !Enum.member?(title, x) end)
      |> Enum.filter(fn x -> !Enum.member?(paradox, x) end)
      |> Enum.filter(fn x -> !Enum.member?(tweet, x) end)
      |> Enum.filter(fn x -> !Enum.member?(qotd, x) end)
      |> Enum.join(" ")

    title = Enum.join(title, " ")
    paradox = Enum.join(paradox, " ")
    tweet = Enum.join(tweet, " ")
    qotd = Enum.join(qotd, " ")
    title = "title: #{title}"
    paradox = "paradox: #{paradox}"
    tweet = "tweet: #{tweet}"
    qotd = "qotd: #{qotd}"
    channels = "channels: #{channels}"
    Bot.msg_to_user(title, nick)
    Bot.msg_to_user(paradox, nick)
    Bot.msg_to_user(tweet, nick)
    Bot.msg_to_user(qotd, nick)
    Bot.msg_to_user(channels, nick)
  end

  def check_command("msg", args, _nick) do
    [channel | msg] = args

    msg
    |> Enum.join(" ")
    |> Bot.msg_to_channel(channel)
  end

  def check_command("op", args, _nick) do
    [channel, user] = args
    Bot.op_user(channel, user)
  end

  def check_command("deop", args, _nick) do
    [channel, user] = args
    Bot.deop_user(channel, user)
  end

  def check_command("admin", args, _nick) do
    [command, user] = args

    cond do
      command == "add" ->
        Bot.get_admins()
        |> Bot.add_to_list(user)
        |> Bot.update_admins()

      command == "del" ->
        Bot.get_admins()
        |> List.delete(user)
        |> Bot.update_admins()

      true ->
        ""
    end
  end

  def check_command(_, _, _), do: :ok
  def check_command(_, _), do: :ok
  def check_command(_), do: :ok
end
