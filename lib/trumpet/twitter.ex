defmodule Trumpet.Twitter do
  alias Trumpet.Bot
  alias Trumpet.Utils

  def get_tweet_msg(tweet_id) do
    tweet = ExTwitter.show(tweet_id)
    text =
      case String.contains?(tweet.text, "…") do
        true  ->
          tweet.text
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
  end

  defp fetch_long_tweet(url) do
    HTTPoison.get!(url, [], [follow_redirect: true]).body
    |> Utils.floki_helper("meta[property='og:description']")
  end

  defp remove_quotes(tweet) do
    tweet
    |> String.replace("“", "")
    |> String.replace("”", "")
  end

  def handle_tweet(tweet) do
    if (Bot.get_last_tweet_id() < tweet.id) && (tweet.retweeted_status == nil) do
      Bot.update_last_tweet_id(tweet.id)
    end
  end

  def populate_last_tweet_id do
    [count: 5, screen_name: "realDonaldTrump"]
    |> ExTwitter.user_timeline()
    |> Enum.each(fn (tweet) -> handle_tweet(tweet) end)
  end
end
