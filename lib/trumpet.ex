defmodule Trumpet do
  use Application

  alias Trumpet.Bot

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = :trumpet
     |> Application.get_env(:bots)
     |> Enum.map(fn bot -> worker(Bot, [bot]) end)
    children = children ++ [worker(Trumpet.Scheduler, [])]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Trumpet.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
