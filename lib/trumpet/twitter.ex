defmodule Trumpet.Twitter do
  alias Trumpet.Bot
  alias Trumpet.Utils

  defp trim_tweet_msg(text) do
    text =
      case String.contains?(text, "…") do
        true ->
          text
          |> String.split("…")
          |> Enum.reverse()
          |> List.first()
          |> String.trim()
          |> fetch_long_tweet()
        false ->
          text
      end

    text
    |> Utils.clean_string()
    |> remove_quotes()
  end

  def get_tweet_msg(%ExTwitter.Model.Tweet{} = tweet) do
    trim_tweet_msg(tweet.text)
  end

  def get_tweet_msg(tweet_id) do
    tweet_id
    |> ExTwitter.show()
    |> get_tweet_msg()
  end

  defp fetch_long_tweet(url) do
    HTTPoison.get!(url, [], follow_redirect: true).body
    |> Utils.floki_helper("meta[property='og:description']")
  end

  defp remove_quotes(tweet) do
    tweet
    |> String.replace("“", "")
    |> String.replace("”", "")
  end

  defp is_older(old_timestamp, new_timestamp) do
    Timex.before?(old_timestamp, new_timestamp)
  end

  def handle_tweet(tweet) do
    timestamp = Utils.get_tweet_timestamp(tweet)
    if is_older(Bot.get_last_tweet_timestamp(), timestamp) && tweet.retweeted_status == nil do
      Bot.update_last_tweet(tweet)
      false
    else
      true
    end
  end

  def populate_last_tweet do
    [screen_name: "realDonaldTrump", count: 5]
    |> ExTwitter.user_timeline()
    |> Enum.reverse()
    |> Enum.take_while(fn tweet -> handle_tweet(tweet) end)
  end
end
