defmodule Chord.NodeTest do
  use ExUnit.Case
  require Logger

  describe ": Start a node->" do
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
      assert is_nil(state[:predeccessor])
      assert is_nil(state[:successor])
      assert !is_nil(state[:identifier])
    end
  end

  describe ": find_successor ->" do
    setup do
      {:ok, location_server} = Chord.LocationServer.start_link([])

      {:ok, node} = Chord.Node.start_link(ip_addr: "127.0.0.1", location_server: location_server)

      [location_server: location_server, node: node]
    end

    test "when the node has come alive and not yet joined the chord network the call to `find_successor` should return `nil`",
         context do
      successor =
        Chord.Node.find_successor(
          context[:node],
          "whyareyoulookingforsuccessoronanodewhichisnotconnected"
        )

      assert is_nil(successor)
    end

    test "when it the only node in the ring and `closest_preceding_node` will return the node itself then `find_successor` will return the node itself",
         context do
      state = :sys.get_state(context[:node])
      id = state[:identifier]
      x = id <> <<0>>
      replace_idx = length(:binary.bin_to_list(x)) - 2
      replace_val = :binary.at(x, replace_idx)
      replace_with_val = replace_val + 1

      new_id =
        :binary.replace(x, <<replace_val>>, <<replace_with_val>>)
        |> :binary.bin_to_list()
        |> Enum.slice(0..-2)
        |> :binary.list_to_bin()

      Chord.Node.join(context[:node])
      successor = Chord.Node.find_successor(context[:node], new_id)
      assert successor[:pid] == context[:node]
    end

    test "when id is less than the successor of the node it will return the node itself",
         context do
      state = :sys.get_state(context[:node])
      id = state[:identifier]
      x = id <> <<0>>
      replace_idx = length(:binary.bin_to_list(x)) - 2
      replace_val = :binary.at(x, replace_idx)
      replace_with_val = replace_val - 1

      new_id =
        :binary.replace(x, <<replace_val>>, <<replace_with_val>>)
        |> :binary.bin_to_list()
        |> Enum.slice(0..-2)
        |> :binary.list_to_bin()

      Chord.Node.join(context[:node])
      successor = Chord.Node.find_successor(context[:node], new_id)
      assert successor[:pid] == context[:node]
    end
  end

  describe ": Node joins as first node on the chord->" do
    setup do
      {:ok, location_server} = Chord.LocationServer.start_link([])

      {:ok, node} = Chord.Node.start_link(ip_addr: "127.0.0.1", location_server: location_server)

      [location_server: location_server, node: node]
    end

    test "predeccessor of the node is nil", context do
      Chord.Node.join(context[:node])
      state = :sys.get_state(context[:node])
      assert is_nil(state[:predeccessor])
    end

    test "successor of the node is the identifier of the node itself", context do
      Chord.Node.join(context[:node])
      state = :sys.get_state(context[:node])

      assert state[:successor] == [
               identifier: state[:identifier],
               ip_addr: state[:ip_addr],
               pid: context[:node]
             ]
    end

    test "finger table of the node initializes in which all entries point to the node itself",
         context do
      Chord.Node.join(context[:node])
      Process.sleep(107_000)
      state = :sys.get_state(context[:node])
      assert length(Map.keys(state[:finger_table])) == 16
    end

    test "stabalizer starts with successor of the node as itself", context do
      Chord.Node.join(context[:node])
      state = :sys.get_state(context[:node])
      old_successor = state[:successor]
      Process.sleep(1000)
      assert state[:successor] == old_successor
    end
  end

  describe ": Node joins as second node on the chord ring ->" do
    setup do
      {:ok, location_server} = Chord.LocationServer.start_link([])

      {:ok, node1} = Chord.Node.start_link(ip_addr: "127.0.0.1", location_server: location_server)

      {:ok, node2} = Chord.Node.start_link(ip_addr: "127.0.0.2", location_server: location_server)

      {:ok, node3} =
        Chord.Node.start_link(ip_addr: "192.168.0.1", location_server: location_server)

      [location_server: location_server, node1: node1, node2: node2, node3: node3]
    end

    test "id of second node is less than first node, then successor of second node is first node",
         context do
      Chord.Node.join(context[:node1])
      Chord.Node.join(context[:node3])
      state1 = :sys.get_state(context[:node1])
      state3 = :sys.get_state(context[:node3])
      assert state3[:identifier] < state1[:identifier]
      assert state1[:successor][:pid] == context[:node1]
      assert state3[:successor][:pid] == context[:node1]
    end

    test "id of second node is greater than first node, then successor of first node is second node",
         context do
      Chord.Node.join(context[:node1])
      Chord.Node.join(context[:node2])
      state2 = :sys.get_state(context[:node2])
      Process.sleep(1000)
      state1 = :sys.get_state(context[:node1])
      assert state1[:identifier] < state2[:identifier]
      assert state1[:successor][:pid] == context[:node2]
      assert state2[:successor][:pid] == context[:node2]
    end

    test "check stabalize when the successor of node3 is node1", context do
      Chord.Node.join(context[:node1])
      Process.sleep(2000)
      Chord.Node.join(context[:node3])
      Process.sleep(100_000)
      state1 = :sys.get_state(context[:node1])
      state2 = :sys.get_state(context[:node3])
      assert state1[:successor][:pid] == context[:node1]
      assert state1[:predeccessor][:pid] == context[:node3]
      assert state2[:successor][:pid] == context[:node1]
      assert is_nil(state2[:predeccessor])
    end

    test "check stabalize when the successor of node1 is node2", context do
      Chord.Node.join(context[:node1])
      Process.sleep(2000)
      Chord.Node.join(context[:node2])
      Process.sleep(100_000)
      state1 = :sys.get_state(context[:node1])
      state2 = :sys.get_state(context[:node2])
      assert state1[:successor][:pid] == context[:node2]
      assert is_nil(state1[:predeccessor])
      assert state2[:successor][:pid] == context[:node2]
      assert state2[:predeccessor][:pid] == context[:node1]
    end
  end
end
