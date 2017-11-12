defmodule Trumpet.Twitter do
  alias Trumpet.Bot
  alias Trumpet.Commands
  alias Trumpet.Utils

  def msg_tweet(tweet, channel) do
    text =
      case String.contains?(tweet.text, "…") do
        true  -> tweet.text
          |> String.split("…")
          |> Enum.reverse()
          |> List.first()
          |> String.trim()
          |> fetch_long_tweet()
        false -> tweet.text
      end
    text
    |> Utils.clean_string()
    |> remove_quotes()
    |> Bot.msg_to_channel(channel)
  end

  def fetch_long_tweet(url) do
    HTTPoison.get!(url, [], [follow_redirect: true]).body
    |> Utils.floki_helper("meta[property='og:description']")
  end

  def remove_quotes(tweet) do
    tweet
    |> String.replace("“", "")
    |> String.replace("”", "")
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

  def populate_last_tweet_id do
    [count: 1, screen_name: "realDonaldTrump"]
    |> ExTwitter.user_timeline()
    |> Enum.each(fn (tweet) -> Bot.update_last_tweet_id(tweet.id) end)
  end
end
