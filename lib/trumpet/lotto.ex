defmodule Trumpet.LottoNumbers do

  defp gen_numbers(max), do: for n <- 1..max, do: n
  defp gen_numbers(max, count) do
    :crypto.rand_seed()
    gen_numbers(max)
    |> Enum.take_random(count)
  end

  def eurojackpot do
    main =
        gen_numbers(50, 5)
        |> Enum.sort()
        |> Enum.map(fn(x) -> "#{x}" end)
        |> Enum.join(", ")
        |> String.trim_trailing(", ")
    supplementary =
        gen_numbers(10, 2)
        |> Enum.sort()
        |> Enum.map(fn(x) -> "#{x}" end)
        |> Enum.join(", ")
        |> String.trim_trailing(", ")
    "#{main} + #{supplementary}"
  end

  def lotto do
    [supplementary | main] = gen_numbers(40, 8)
    main =
        main
        |> Enum.sort()
        |> Enum.map(fn(x) -> "#{x}" end)
        |> Enum.join(", ")
        |> String.trim_trailing(", ")
    supplementary = "#{supplementary}"
    "#{main} + #{supplementary}"
  end
end