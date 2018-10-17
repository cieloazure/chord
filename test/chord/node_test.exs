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
      assert !is_nil(state[:finger_fixer])
      assert !is_nil(state[:stabalizer])
    end
  end

  describe ": Find_successor ->" do
    setup do
      {:ok, location_server} = Chord.LocationServer.start_link([])

      {:ok, node} =
        Chord.Node.start_link(
          ip_addr: "127.0.0.1",
          location_server: location_server,
          identifier: 1
        )

      {:ok, node2} =
        Chord.Node.start_link(
          ip_addr: "127.0.0.2",
          location_server: location_server,
          identifier: 2
        )

      [location_server: location_server, node: node, node2: node2]
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

    test "when it the only node in the ring then `find_successor` will return the node itself",
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

    test "with two nodes `find_successor` of one node with id of other will return the same node",
         context do
      Chord.Node.join(context[:node])
      Chord.Node.join(context[:node2])
      Process.sleep(5000)
      state1 = :sys.get_state(context[:node])
      state2 = :sys.get_state(context[:node2])
      assert state1[:successor][:pid] == context[:node2]
      assert state2[:successor][:pid] == context[:node]
      successor = Chord.Node.find_successor(context[:node], state2[:identifier])
      assert successor[:pid] == context[:node2]
    end
  end

  describe ": Node joins as first node on the chord->" do
    setup do
      {:ok, location_server} = Chord.LocationServer.start_link([])

      number_of_bits = 16

      {:ok, node} =
        Chord.Node.start_link(
          ip_addr: "127.0.0.1",
          location_server: location_server,
          number_of_bits: number_of_bits
        )

      [location_server: location_server, node: node, number_of_bits: number_of_bits]
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
      Process.sleep(16000)
      state = :sys.get_state(context[:node])
      assert length(Map.keys(state[:finger_table])) == context[:number_of_bits]
    end

    test "stabalizer starts with successor of the node as itself", context do
      Chord.Node.join(context[:node])
      state = :sys.get_state(context[:node])
      old_successor = state[:successor]
      Process.sleep(1000)
      assert state[:successor] == old_successor
    end
  end

  describe ": Simulation for 2 nodes ->" do
    setup do
      {:ok, location_server} = Chord.LocationServer.start_link([])

      {:ok, node1} =
        Chord.Node.start_link(
          ip_addr: "127.0.0.1",
          location_server: location_server,
          identifier: 1,
          number_of_bits: 3
        )

      {:ok, node2} =
        Chord.Node.start_link(
          ip_addr: "192.168.0.3",
          location_server: location_server,
          identifier: 2,
          number_of_bits: 3
        )

      [location_server: location_server, node1: node1, node2: node2]
    end

    test "stabalize makes each node successor and predeccessor of each other", context do
      Chord.Node.join(context[:node1])
      Process.sleep(5000)
      Chord.Node.join(context[:node2])
      Process.sleep(5000)
      state1 = :sys.get_state(context[:node1])
      state2 = :sys.get_state(context[:node2])
      assert state1[:successor][:pid] == context[:node2]
      assert state1[:predeccessor][:pid] == context[:node2]
      assert state2[:successor][:pid] == context[:node1]
      assert state2[:predeccessor][:pid] == context[:node1]
    end

    test "finger fixer updates the appropriate entries", context do
      Chord.Node.join(context[:node1])
      Process.sleep(5000)
      Chord.Node.join(context[:node2])
      Process.sleep(10000)
      state1 = :sys.get_state(context[:node1])
      state2 = :sys.get_state(context[:node2])
      finger_table_1 = state1[:finger_table]
      finger_table_2 = state2[:finger_table]
      Logger.debug(inspect(finger_table_1))
      Logger.debug(inspect(finger_table_2))

      key_values_for_identifier_1 = [2, 3, 5]
      values_for_identifier_1 = [2, 1, 1]
      key_values_for_identifier_2 = [3, 4, 6]
      values_for_identifier_2 = [1, 1, 1]

      Enum.each(finger_table_1, fn {{idx, key}, value} ->
        assert key == Enum.at(key_values_for_identifier_1, idx - 1)
        assert value[:identifier] == Enum.at(values_for_identifier_1, idx - 1)
      end)

      Enum.each(finger_table_2, fn {{idx, key}, value} ->
        assert key == Enum.at(key_values_for_identifier_2, idx - 1)
        assert value[:identifier] == Enum.at(values_for_identifier_2, idx - 1)
      end)
    end
  end

  describe ": Simulation for 3 nodes ->" do
    setup do
      {:ok, location_server} = Chord.LocationServer.start_link([])

      {:ok, node1} =
        Chord.Node.start_link(
          ip_addr: "127.0.0.1",
          location_server: location_server,
          identifier: 1,
          number_of_bits: 3
        )

      {:ok, node2} =
        Chord.Node.start_link(
          ip_addr: "192.168.0.3",
          location_server: location_server,
          identifier: 2,
          number_of_bits: 3
        )

      {:ok, node3} =
        Chord.Node.start_link(
          ip_addr: "192.168.0.1",
          location_server: location_server,
          identifier: 5,
          number_of_bits: 3
        )

      [location_server: location_server, node1: node1, node2: node2, node3: node3]
    end

    test "stabalize makes successor and predeccessor point appropriately", context do
      Chord.Node.join(context[:node1])
      Process.sleep(5000)
      Chord.Node.join(context[:node2])
      Process.sleep(5000)
      Chord.Node.join(context[:node3])
      Process.sleep(10000)
      state1 = :sys.get_state(context[:node1])
      state2 = :sys.get_state(context[:node2])
      state3 = :sys.get_state(context[:node3])
      assert state1[:successor][:identifier] == state2[:identifier]
      assert state1[:predeccessor][:identifier] == state3[:identifier]
      assert state2[:successor][:identifier] == state3[:identifier]
      assert state2[:predeccessor][:identifier] == state1[:identifier]
      assert state3[:successor][:identifier] == state1[:identifier]
      assert state3[:predeccessor][:identifier] == state2[:identifier]
    end

    test "finger table has appropriate entries", context do
      Chord.Node.join(context[:node1])
      Process.sleep(5000)
      Chord.Node.join(context[:node2])
      Process.sleep(5000)
      Chord.Node.join(context[:node3])
      Process.sleep(10000)
      state1 = :sys.get_state(context[:node1])
      state2 = :sys.get_state(context[:node2])
      state3 = :sys.get_state(context[:node3])
      finger_table_1 = state1[:finger_table]
      values_for_identifier_1 = [2, 5, 5]
      finger_table_2 = state2[:finger_table]
      values_for_identifier_2 = [5, 5, 1]
      finger_table_3 = state3[:finger_table]
      values_for_identifier_3 = [1, 1, 1]

      Enum.each(finger_table_1, fn {{idx, key}, value} ->
        assert value[:identifier] == Enum.at(values_for_identifier_1, idx - 1)
      end)

      Enum.each(finger_table_2, fn {{idx, key}, value} ->
        assert value[:identifier] == Enum.at(values_for_identifier_2, idx - 1)
      end)

      Enum.each(finger_table_3, fn {{idx, key}, value} ->
        assert value[:identifier] == Enum.at(values_for_identifier_3, idx - 1)
      end)
    end
  end
end
