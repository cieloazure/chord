defmodule Simulation do
  require Logger

  def run(num_nodes \\ 1000, num_requests \\ 10, number_of_bits \\ 40, num_records \\ 1000) do
    # create a location server for the nodes to get a node to join chord
    {:ok, location_server} = Chord.LocationServer.start_link([])

    # create `numNodes` number of nodes
    Logger.info("Creating Nodes....")

    api_list =
      for n <- 0..(num_nodes - 1) do
        ProgressBar.render(n, num_nodes - 1)

        {:ok, api} =
          Chord.API.start_link(
            ip_addr: get_ip_addr(),
            location_server: location_server,
            number_of_bits: number_of_bits
          )

        Process.sleep(200)
        api
      end

    Logger.info("Waiting for stabalization...")
    Process.sleep(10000)

    # create dummy database and insert that data into the chord network using
    # random nodes

    Logger.info("Inserting dummy  data for simulation....")

    database =
      for n <- 0..num_records do
        ProgressBar.render(n, num_records)
        data = get_random_string()
        _r = Chord.API.insert(Enum.random(api_list), data)
        data
      end

    # {api_list, database}

    ### Request for random data from each node for `numRequests` times
    ### Do this parallely
    Logger.info("Sending #{num_requests} requests from each node....")

    results =
      api_list
      |> Enum.map(&Task.async(fn -> request(&1, database, num_requests) end))
      |> Enum.map(&Task.await(&1, :infinity))

    ## Collect the results for each request and the number of hops it required
    ## for each node
    results = List.flatten(results)

    ## Calculate the average number of hops for each node
    Enum.reduce(results, 0, fn result, acc -> result + acc end) / length(results)
  end

  defp get_ip_addr() do
    to_string(:rand.uniform(255)) <>
      "." <>
      to_string(:rand.uniform(255)) <>
      "." <> to_string(:rand.uniform(255)) <> "." <> to_string(:rand.uniform(255))
  end

  defp get_random_string() do
    length = :rand.uniform(100)
    :crypto.strong_rand_bytes(length) |> Base.url_encode64() |> binary_part(0, length)
  end

  defp request(api, database, num_requests) do
    for _n <- 0..num_requests do
      Process.sleep(1000)
      data = Enum.random(database)
      _reply = Chord.API.lookup(api, data)

      {item, _from, hops} =
        receive do
          {:lookup_result, result} -> result
        end

      Logger.debug(item)

      hops
    end
  end
end
