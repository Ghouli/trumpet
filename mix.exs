defmodule Trumpet.Mixfile do
  use Mix.Project

  def project do
    [app: :trumpet,
     version: "0.3.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger, :exirc, :extwitter, :quantum, :timex],
     mod: {Trumpet, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:exirc, github: "ghouli/exirc"},
     {:extwitter, "~> 0.9"},
     {:credo, "~> 0.8.8", only: [:dev, :test]},
     {:floki, "~> 0.18.1"},
     {:quantum, ">= 2.1.1"},
     #{:scrape, github: "Ghouli/elixir-scrape"},
     {:timex, "~> 3.1"},
   ]
  end
end
