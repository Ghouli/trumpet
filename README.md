# Trumpet

Trumpet is [ExIrc](https://github.com/bitwalker/exirc) based IRC-bot, which base purpose is to spew Trump's tweets on few channels. Also included the always so useful fetching of titles from urls.

## Getting started

Set config.exs file with your Twitter keys, and launch with `iex -S mix`. You can join new channels with `Trumpet.Bot.join_channel "#somechannel"`.

Supported commands so far:

```
!tweet subscribe
!tweet unsubscribe
!tweet last

!fakenews subscribe
!fakenews unsubscribe
!fakenews last

!title subscribe
!title unsubscribe
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

