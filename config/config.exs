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
#     import_config "#{Mix.env}.exs"
config :trumpet, bots: [
  %{:server => "irc.quakenet.org", :port => 6667,
    :nick => "trumpet", :user => "trumpet", :name => "trumpet",
    :channel => "#testtest"}
  ]

  # Fill these
  config :extwitter, :oauth, [
   consumer_key: "",
   consumer_secret: "",
   access_token: "",
   access_token_secret: ""
]

config :quantum, :trump_tweets,
  cron: [
    # Every minute
    #{"* * * * *",      {Trumpet.Bot, :trump_check, []}},
    # Every 15 minutes
    #{"*/15 * * * *",   fn -> System.cmd("rm", ["/tmp/tmp_"]) end},
    # Runs on 18, 20, 22, 0, 2, 4, 6:
    #{"0 18-6/2 * * *", fn -> :mnesia.backup('/var/backup/mnesia') end},
    # Runs every midnight:
    #{"@daily",         {Backup, :backup, []}}
  ]