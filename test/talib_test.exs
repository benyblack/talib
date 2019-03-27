defmodule TAlibTest do
  use ExUnit.Case
  doctest TAlib

  test "greets the world" do
    assert TAlib.hello() == :world
  end
end
