# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :trumpet, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:trumpet, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#

# IRC-server settings (you can join more channels after connect)
config :trumpet, bots: [
  %{:server => "irc.quakenet.org", :port => 6667,
    :nick => "trumpet", :user => "trumpet", :name => "trumpet",
    :channel => "#your_channel_here"}
  ]

config :trumpet, aotd_channels: []
config :trumpet, fake_news_channels: []
config :trumpet, url_title_channels: []
config :trumpet, tweet_channels: []
config :trumpet, quote_of_the_day_channels: []
config :trumpet, devdiary_channels: []

# Fill these with your secrets
config :extwitter, :oauth, [
  consumer_key: "",
  consumer_secret: "",
  access_token: "",
  access_token_secret: ""
]

# How often to check for new tweets or fake news
config :quantum, trumpet: [
  cron: [    
    {"00 08 * * *",    {Trumpet.Bot, :good_morning, []}},
    # Every minute
    {"* * * * *",      {Trumpet.Bot, :trump_check, []}},
    # Every 15 minutes
    {"*/15 * * * *",      {Trumpet.Bot, :check_paradox_devdiaries, []}},    
  ]
]
