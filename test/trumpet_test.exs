defmodule TrumpetTest do
  use ExUnit.Case
  doctest Trumpet

  test "subscribe channel to features" do
    Trumpet.Commands.handle_command("!tweet sub", "tester", "#test")
    Trumpet.Commands.handle_command("!title sub", "tester", "#test")
    Trumpet.Commands.handle_command("!paradox sub", "tester", "#test")
    Trumpet.Commands.handle_command("!qotd sub", "tester", "#test")

    assert Enum.member?(Trumpet.Bot.get_function_channels(:tweet_channels), "#test")
    assert Enum.member?(Trumpet.Bot.get_function_channels(:url_title_channels), "#test")
    assert Enum.member?(Trumpet.Bot.get_function_channels(:devdiary_channels), "#test")
    assert Enum.member?(Trumpet.Bot.get_function_channels(:quote_of_the_day_channels), "#test")

    Trumpet.Commands.handle_command("!tweet unsub", "tester", "#test")
    Trumpet.Commands.handle_command("!title unsub", "tester", "#test")
    Trumpet.Commands.handle_command("!paradox unsub", "tester", "#test")
    Trumpet.Commands.handle_command("!qotd unsub", "tester", "#test")

    assert !Enum.member?(Trumpet.Bot.get_function_channels(:tweet_channels), "#test")
    assert !Enum.member?(Trumpet.Bot.get_function_channels(:url_title_channels), "#test")
    assert !Enum.member?(Trumpet.Bot.get_function_channels(:devdiary_channels), "#test")
    assert !Enum.member?(Trumpet.Bot.get_function_channels(:quote_of_the_day_channels), "#test")
  end

  test "fetch trump tweets" do
    Trumpet.Commands.populate_last_tweet_id()

    id = Trumpet.Bot.get_last_tweet_id()
    tweet = Trumpet.Twitter.get_tweet_msg(id)
    assert is_integer(id)
    assert String.valid?(tweet)
    assert !String.contains?(tweet, "…")
    assert !String.contains?(tweet, "&amp")

    assert tweet == Trumpet.Commands.handle_command("!tweet", ["last"], "#test", "tester")
  end

  test "cryptocoin command returns quote" do
    assert String.contains?(Trumpet.Cryptocurrency.get_coin([""],"usd"),"Bitcoin")
    assert String.contains?(Trumpet.Cryptocurrency.get_coin(["eth"], "eur"), "Ethereum")
    assert String.contains?(Trumpet.Cryptocurrency.get_coin(["ethereum classic"],"usd"),"Ethereum Classic")

    assert String.contains?(Trumpet.Commands.handle_command("!crypto", [""], "#test", "tester"), "Bitcoin")
    assert String.contains?(Trumpet.Commands.handle_command("!altcoin", ["eth"], "#test", "tester"), "Ethereum")
  end

  test "stock command returns quote and shorturl" do
    aapl = Trumpet.Stocks.get_quote(["aapl"])
    t = Trumpet.Stocks.get_quote(["at t"])
    assert String.contains?(aapl, "Apple Inc, NASDAQ")
    assert String.contains?(t, "AT&T Inc, New York")
    
    index = Trumpet.Stocks.get_index(["hel"])
    assert String.contains?(index, "OMX Helsinki")
    assert assert String.contains?(aapl, "https://goo.gl/")
      || String.contains?(t, "https://goo.gl/")
      || String.contains?(index, "https://goo.gl/")

    assert String.contains?(Trumpet.Commands.handle_command("!stock", ["at t"], "#test", "tester"), "AT&T Inc, New York")
    assert String.contains?(Trumpet.Commands.handle_command("!index", ["hel"], "#test", "tester"), "OMX Helsinki")
  end

  test "fetching paradox dev diaries" do
    Trumpet.Paradox.populate_paradox_devdiaries()

    assert !Enum.empty?(Trumpet.Bot.get_ck2_devdiary_map())
    assert !Enum.empty?(Trumpet.Bot.get_eu4_devdiary_map())
    assert !Enum.empty?(Trumpet.Bot.get_hoi4_devdiary_map())
    assert !Enum.empty?(Trumpet.Bot.get_stellaris_devdiary_map())

    assert String.contains?(Trumpet.Paradox.get_last_ck2(), "forum.paradoxplaza")
    assert String.contains?(Trumpet.Paradox.get_last_eu4(), "forum.paradoxplaza")
    assert String.contains?(Trumpet.Paradox.get_last_hoi4(), "forum.paradoxplaza")
    assert String.contains?(Trumpet.Paradox.get_last_stellaris(), "forum.paradoxplaza")

    assert String.contains?(Trumpet.Commands.handle_command("!ck2", [""], "#test", "tester"), "forum.paradoxplaza")
    assert String.contains?(Trumpet.Commands.handle_command("!eu4", [""], "#test", "tester"), "forum.paradoxplaza") 
    assert String.contains?(Trumpet.Commands.handle_command("!hoi4", [""], "#test", "tester"), "forum.paradoxplaza") 
    assert String.contains?(Trumpet.Commands.handle_command("!stellaris", [""], "#test", "tester"), "forum.paradoxplaza")    
  end

  test "get motivational quote" do
    assert String.contains?(Trumpet.Commands.get_motivation(), ". -")
    assert String.contains?(Trumpet.Commands.handle_command("!motivation", [""], "#test", "tester"), ". -") 
  end

  test "get quote of the day" do
    qotd = Trumpet.Commands.get_quote_of_the_day()
    assert String.contains?(qotd, ". -")
    assert Trumpet.Commands.handle_command("!qotd", [""], "#test", "tester") == qotd
  end

  test "epoch returns correct date" do
    assert Trumpet.Commands.unix_to_localtime(["1234567890"]) == "2009-02-14 01:31:30 EET"
    assert Trumpet.Commands.handle_command("!epoch", ["1234567890"], "#test", "tester") == "2009-02-14 01:31:30 EET"
  end

  test "timezone command" do
    assert Trumpet.Commands.time_to_local(["cst","22"]) == "06:00:00"
    assert Trumpet.Commands.handle_command("!time", ["cst", "22"], "#test", "tester") == "06:00:00"
  end

  test "reddit image search" do
    assert String.contains?(Trumpet.Commands.get_random_redpic(["retrobattlestations"]),"http")
    assert String.contains?(Trumpet.Commands.handle_command("!r", ["retrobattlestations"], "#test", "tester"), "http")
  end

  test "title fetching" do
    assert Trumpet.Commands.fetch_title("https://imgur.com/r/space/wQTN1Cj") == "Albert II, the first monkey in space - Imgur"
    assert Trumpet.Commands.fetch_title("https://i.imgur.com/wQTN1Cj.jpg") == "Albert II, the first monkey in space - Imgur"
  end

  test "lotto generator" do
    set1 = Trumpet.Commands.handle_command("!lotto", [""], "#test", "tester")
    set2 = Trumpet.Commands.handle_command("!lotto", [""], "#test", "tester")

    main =
      set1
      |> String.split("+")
      |> List.first()
      |> String.replace(" ", "")
      |> String.split(",")
    sup =
      set1
      |> String.split("+")
      |> Enum.at(1)
      |> String.replace(" ", "")

    assert set1 != set2
    assert Enum.count(main) == 7
    assert sup |> String.to_integer() |> is_integer()
  end

  test "eurojackpot generator" do
    set1 = Trumpet.Commands.handle_command("!eurojackpot", [""], "#test", "tester")
    set2 = Trumpet.Commands.handle_command("!eurojackpot", [""], "#test", "tester")

    main =
      set1
      |> String.split("+")
      |> List.first()
      |> String.replace(" ", "")
      |> String.split(",")
    sup =
      set1
      |> String.split("+")
      |> Enum.at(1)
      |> String.replace(" ", "")
      |> String.split(",")

    assert set1 != set2
    assert Enum.count(main) == 5
    assert Enum.count(sup) == 2
  end
end
