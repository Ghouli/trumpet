defmodule TrumpetTest do
  use ExUnit.Case
  doctest Trumpet

  test "fetch trump tweets" do
    Trumpet.Commands.populate_last_tweet_id()

    id = Trumpet.Bot.get_last_tweet_id()
    tweet = Trumpet.Twitter.get_tweet_msg(id)
    assert is_integer(id)
    assert String.valid?(tweet)
    assert !String.contains?(tweet, "…")
    assert !String.contains?(tweet, "&amp")
  end

  test "cryptocoin command returns quote" do
    assert(String.contains?(Trumpet.Cryptocurrency.get_coin(["btc"],"usd"),"Bitcoin"))
  end

  test "stock command returns quote and shorturl" do
    stock = Trumpet.Stocks.get_quote(["aapl"])
    assert String.contains?(stock, "Apple Inc, NASDAQ")

    index = Trumpet.Stocks.get_index(["hel"])
    assert String.contains?(index, "OMX Helsinki")

    assert String.contains?(stock, "https://goo.gl/")
      || String.contains?(index, "https://goo.gl")
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
  end

  test "get motivational quote" do
    assert String.contains?(Trumpet.Commands.get_motivation(), ". -")
  end

  test "get quote of the day" do
    assert String.contains?(Trumpet.Commands.get_quote_of_the_day(), ". -")
  end

  test "epoch returns correct date" do
    assert Trumpet.Commands.unix_to_localtime(["1234567890"]) == "2009-02-14 01:31:30 EET"
  end

  test "timezone command" do
    assert Trumpet.Commands.time_to_local(["cst","22"]) == "06:00:00"
  end

  test "reddit image search" do
    assert String.contains?(Trumpet.Commands.get_random_redpic(["retrobattlestations"]),"http")
  end

  test "title fetching" do
    assert Trumpet.Website.fetch_title("https://imgur.com/r/space/wQTN1Cj") == "Albert II, the first monkey in space - Imgur"
    assert Trumpet.Website.fetch_title("https://i.imgur.com/wQTN1Cj.jpg") == "Albert II, the first monkey in space - Imgur"
  end
end
