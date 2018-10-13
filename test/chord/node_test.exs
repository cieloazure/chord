defmodule Chord.NodeTest do
  use ExUnit.Case

  describe "start a node" do
    setup do
      {:ok, location_server} = Chord.LocationServer.start_link([])
      [location_server: location_server]
    end

    test "is initialized with ip address and location server", context do
      {:ok, node} =
        Chord.Node.start_link(ip_addr: "127.0.0.1", location_server: context[:location_server])

      state = :sys.get_state(node)
      assert state[:ip_addr] == "127.0.0.1"
      assert state[:location_server] == context[:location_server]
      assert is_nil(state[:predescessor])
      assert is_nil(state[:successor])
      assert !is_nil(state[:identifier])
    end
  end

  describe "node attempts to join the chord network and it is the first node on the network" do
    setup do
      {:ok, location_server} = Chord.LocationServer.start_link([])

      {:ok, node} = Chord.Node.start_link(ip_addr: "127.0.0.1", location_server: location_server)

      [location_server: location_server, node: node]
    end

    test "predescessor of the node is nil", context do
      Chord.Node.join(context[:node])
      state = :sys.get_state(context[:node])
      assert is_nil(state[:predeccessor])
    end

    test "successor of the node is the identifier of the node itself", context do
      Chord.Node.join(context[:node])
      state = :sys.get_state(context[:node])
      assert state[:successor] == state[:identifier]
    end
  end
end
