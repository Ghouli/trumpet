defmodule Trumpet.Twitter do
  alias Trumpet.Bot
  alias Trumpet.Command

  def msg_tweet(tweet, channel) do
    tweet.text
    |> String.replace("&amp;", "&")
    |> String.replace("\n", "")
    |> Bot.msg_to_channel(channel)
  end

  def msg_tweet(tweet) do
    Bot.get_tweet_channels()
    |> Enum.map(fn (channel) -> msg_tweet(tweet, channel) end)
  end

  def handle_tweet(tweet) do
    if (Bot.get_last_tweet_id() < tweet.id) && (tweet.retweeted_status == nil) do
      Bot.update_last_tweet_id(tweet.id)
      msg_tweet(tweet)
    end
  end

  def populate_last_tweet_id() do
    [count: 1, screen_name: "realDonaldTrump"]
    |> ExTwitter.user_timeline()
    |> Enum.each(fn (tweet) -> Bot.update_last_tweet_id(tweet.id) end)
  end
end