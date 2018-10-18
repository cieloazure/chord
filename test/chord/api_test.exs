defmodule Chord.APITest do
  use ExUnit.Case
  require Logger

  describe "API: " do
    test "initializes the api" do
      {:ok, location_server} = Chord.LocationServer.start_link([])
      ip_addr = get_ip_addr()
      {:ok, api} = Chord.API.start_link(ip_addr: ip_addr, location_server: location_server)
      node = :sys.get_state(api)
      node_state = :sys.get_state(node)
      assert node_state[:ip_addr] == ip_addr
    end

    test "stores the data in a node using api" do
      {:ok, location_server} = Chord.LocationServer.start_link([])
      ip_addr = get_ip_addr()
      {:ok, api} = Chord.API.start_link(ip_addr: ip_addr, location_server: location_server)
      node = :sys.get_state(api)
      node_state = :sys.get_state(node)
      reply = Chord.API.insert(api, "akash")
      assert reply == :ok
    end

    test "lookup the data in the node using api" do
      {:ok, location_server} = Chord.LocationServer.start_link([])
      ip_addr = get_ip_addr()
      {:ok, api} = Chord.API.start_link(ip_addr: ip_addr, location_server: location_server)
      node = :sys.get_state(api)
      node_state = :sys.get_state(node)
      reply = Chord.API.insert(api, "akash")
      {response, from} = Chord.API.lookup(api, "akash")
      assert response == "akash"
      assert from[:pid] == node
    end
  end

  describe ": Multiple Nodes ->" do
    test "transfers keys from other nodes" do
      {:ok, location_server} = Chord.LocationServer.start_link([])
      ip_addr = get_ip_addr()

      {:ok, api} =
        Chord.API.start_link(ip_addr: ip_addr, location_server: location_server, identifier: 1)

      reply = Chord.API.insert(api, get_random_string(), 2)
      reply = Chord.API.insert(api, get_random_string(), 3)
      reply = Chord.API.insert(api, get_random_string(), 4)
      node = :sys.get_state(api)
      node_state = :sys.get_state(node)
      store_state1 = :sys.get_state(node_state[:block_storage_server])

      store_state_1 = :sys.get_state(node_state[:block_storage_server])
      Logger.debug(inspect(store_state_1))

      {:ok, api2} =
        Chord.API.start_link(ip_addr: ip_addr, location_server: location_server, identifier: 2)

      Process.sleep(2000)

      {_, store_state_1} = :sys.get_state(node_state[:block_storage_server])
      Logger.debug(inspect(store_state_1))
      assert Enum.empty?(store_state_1)

      node2 = :sys.get_state(api2)
      node_state_2 = :sys.get_state(node2)
      {_, store_state_2} = :sys.get_state(node_state_2[:block_storage_server])
      Logger.debug(inspect(store_state_2))
      keys = [2, 3, 4]

      Enum.with_index(store_state_2)
      |> Enum.each(fn {{k, v}, idx} -> assert k == Enum.at(keys, idx) end)
    end

    test "test case in the chord paper" do
      {:ok, location_server} = Chord.LocationServer.start_link([])
      identifiers = [1, 8, 14, 21, 32, 38, 42, 48, 51, 56]
      number_of_bits = 8

      data_identifier = [10, 24, 30, 38, 54]

      apis =
        Enum.map(identifiers, fn identifier ->
          {:ok, api} =
            Chord.API.start_link(
              ip_addr: get_ip_addr(),
              location_server: location_server,
              identifier: identifier,
              number_of_bits: number_of_bits
            )

          api
        end)

      Process.sleep(60000)

      nodes =
        Enum.map(apis, fn api ->
          state = :sys.get_state(api)
          node_state = :sys.get_state(state)
          state
        end)

      Enum.each(data_identifier, fn data ->
        r = Enum.random(apis)
        n = :sys.get_state(r)
        ns = :sys.get_state(n)
        Chord.API.insert(r, get_random_string(), data)
      end)

      Enum.each(nodes, fn node ->
        node_state = :sys.get_state(node)
        block_store = :sys.get_state(node_state[:block_storage_server])
      end)

      {:ok, new_api} =
        Chord.API.start_link(
          ip_addr: get_ip_addr(),
          location_server: location_server,
          identifier: 26,
          number_of_bits: number_of_bits
        )

      new_node = :sys.get_state(new_api)
      nodes = [new_node | nodes]
      Process.sleep(10000)

      Enum.each(nodes, fn node ->
        node_state = :sys.get_state(node)
        block_store = :sys.get_state(node_state[:block_storage_server])
        Logger.debug(inspect(node_state[:identifier]))
        Logger.debug(inspect(block_store))
      end)
    end
  end

  def get_ip_addr() do
    to_string(:rand.uniform(255)) <>
      "." <>
      to_string(:rand.uniform(255)) <>
      "." <> to_string(:rand.uniform(255)) <> "." <> to_string(:rand.uniform(255))
  end

  def get_random_string() do
    length = :rand.uniform(10)
    :crypto.strong_rand_bytes(length) |> Base.url_encode64() |> binary_part(0, length)
  end
end
