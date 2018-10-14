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
      assert is_nil(state[:predescessor])
      assert is_nil(state[:successor])
      assert !is_nil(state[:identifier])
    end
  end

  describe ": Node joins as first node on the chord->" do
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

      assert state[:successor] == [
               identifier: state[:identifier],
               ip_addr: state[:ip_addr],
               pid: context[:node]
             ]
    end

    test "finger table of the node initializes in which all entries point to the node itself",
         context do
      Chord.Node.join(context[:node])
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
end
