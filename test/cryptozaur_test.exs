defmodule CryptozaurTest do
  use ExUnit.Case
  doctest Cryptozaur

  test "greets the world" do
    assert Cryptozaur.hello() == :world
  end
end
