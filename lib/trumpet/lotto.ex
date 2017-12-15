defmodule Trumpet.LottoNumbers do
  alias Trumpet.Utils

  def gen_eurojackpot(count, take) do
    Utils.random_numbers(count, take)
    |> Utils.print_random_numbers()
  end

  def eurojackpot do
    main = gen_eurojackpot(50, 5)
    supplementary = gen_eurojackpot(10, 2)
    "#{main} + #{supplementary}"
  end

  def lotto do
    [supplementary | main] = Utils.random_numbers(40, 8)
    main = Utils.print_random_numbers(main)
    supplementary = "#{supplementary}"
    "#{main} + #{supplementary}"
  end
end
