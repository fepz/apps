defmodule KvServerTest do
  use ExUnit.Case
  doctest KvServer

  test "greets the world" do
    assert KvServer.hello() == :world
  end
end
