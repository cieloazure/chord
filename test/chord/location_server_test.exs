defmodule Chord.LocationServerTest do
  use ExUnit.Case

  describe "node_request" do
    test "returns nil when there are no nodes in the location server" do
      {:ok, location_server} = Chord.LocationServer.start_link([])
      assert is_nil(Chord.LocationServer.node_request(location_server, "127.0.0.1"))
    end

    test "is not nil when there is request for node and there are some nodes in the table" do
      {:ok, location_server} = Chord.LocationServer.start_link([])
      Chord.LocationServer.node_request(location_server, "127.0.0.1")
      assert !is_nil(Chord.LocationServer.node_request(location_server, "127.0.0.2"))
    end

    test "returns ip address and pid of a random node when there is at least 1 node in the location server" do
      {:ok, location_server} = Chord.LocationServer.start_link([])
      Chord.LocationServer.node_request(location_server, "127.0.0.1")
      {_pid, ip_addr} = Chord.LocationServer.node_request(location_server, "127.0.0.2")
      assert ip_addr == "127.0.0.1"
    end
  end
end
