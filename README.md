# Trumpet

Trumpet is [ExIrc](https://github.com/bitwalker/exirc) based IRC-bot, which base purpose is to spew Trump's tweets on few channels. Also included the always so useful fetching of titles from urls.

## Getting started

Set config.exs file with your Twitter keys, and launch with `iex -S mix`. You can join new channels with `Trumpet.Bot.join_channel "#somechannel"`.

Supported commands so far:

```
!tweet sub
!tweet unsub
!tweet last

!fakenews sub
!fakenews unsub
!fakenews last

!title sub
!title unsub

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
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `trumpet` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:trumpet, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/trumpet](https://hexdocs.pm/trumpet).

