defmodule Simulation do
  require Logger

  def run(numNodes) do
    # create a location server for the nodes to get a node to join chord
    {:ok, location_server} = Chord.LocationServer.start_link([])

    # bits or m
    number_of_bits = 40
    # create `numNodes` number of nodes
    api_list =
      for _n <- 0..(numNodes - 1) do
        {:ok, api} =
          Chord.API.start_link(
            ip_addr: get_ip_addr(),
            location_server: location_server,
            number_of_bits: number_of_bits
          )

        Process.sleep(2000)
        api
      end

    node_list =
      Enum.map(api_list, fn api ->
        {node, _} = :sys.get_state(api)
        # :sys.statistics(node, true)
        # :sys.trace(node, true)
        node
      end)

    {api_list, node_list}

    # create dummy database and insert that data into the chord network using
    # random nodes
    # num_records = 100_000

    # database =
    # for n <- 0..num_records do
    # data = get_random_string()
    # random_api = Enum.random(api_list)
    # Chord.API.insert(random_api, data)
    # data
    # end

    # Request for random data from each node for `numRequests` times
    # Do this parallely
    # api_list
    # |> Enum.map(&Task.async(fn -> request(&1, database, numRequests) end))
    # |> Enum.map(&Task.await/1)

    # Collect the results for each request and the number of hops it required
    # for each node

    # Calculate the average number of hops for each node
  end

  defp get_ip_addr() do
    to_string(:rand.uniform(255)) <>
      "." <>
      to_string(:rand.uniform(255)) <>
      "." <> to_string(:rand.uniform(255)) <> "." <> to_string(:rand.uniform(255))
  end

  defp get_random_string() do
    length = :rand.uniform(10)
    :crypto.strong_rand_bytes(length) |> Base.url_encode64() |> binary_part(0, length)
  end

  defp request(api, database, numRequests) do
    for _n <- 0..numRequests do
      Logger.debug("#{inspect(api)} | Request: #{inspect(_n)}")
      data = Enum.random(database)
      {data, from, hops} = Chord.API.lookup(api, data)
      hops
    end
  end
end
