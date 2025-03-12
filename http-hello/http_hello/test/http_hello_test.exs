defmodule HttpHelloTest do
  use ExUnit.Case
  doctest HttpHello

  test "greets the world" do
    assert HttpHello.hello() == :world
  end
end
