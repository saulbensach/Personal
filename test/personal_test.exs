defmodule PersonalTest do
  use ExUnit.Case
  doctest Personal

  test "greets the world" do
    assert Personal.hello() == :world
  end
end
