# Trumpet

Trumpet is [ExIrc](https://github.com/bitwalker/exirc) based IRC-bot, which base purpose is to spew Trump's tweets on few channels. Also included the always so useful fetching of titles from urls.

## Getting started

Set config.exs file with desired user info, irc-server and channels, and launch with `iex -S mix`. Bot automatically connects to every channel given in config, and tries to auth with Q & hide hostname/ip if connecting to Quakenet with password set.

Some functionality requires additional setup:

-Fetching Trump tweets require Twitter API keys to be set.

-URL shortener for stocks command requires Google URL Shortener API key to be set.

-Fetching Paradox dev diaries requires gd_bundle-g2.crt in /etc/ssl/certs/gd_bundle-g2.crt (at least for now)


Some supported commands so far:

```
!tweet sub
!tweet unsub
!tweet last

!fakenews sub
!fakenews unsub
!fakenews last

!title sub
!title unsub

!r subreddit

!quotd sub
!quotd unsub
!quotd
!motivation

!paradox sub
!paradox unsub
!ck2
!eu4
!hoi4
!stellaris

!stock some stock
!index some index

!epoch unixtime
!time timezone time
```

## Installation

Guides to installing [Elixir can be found here.](http://elixir-lang.github.io/install.html)

Other than that, just clone the repo and setup your config.exs.
