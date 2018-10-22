defmodule SimulationSupervisor do
  @moduledoc """
  Simulation Supervisor

  It's responsiblity is to create nodes and fail nodes.
  """
  use DynamicSupervisor
  require Logger

  @doc """
  Chord.SimulationSupervisor.start_link

  Starts the simulation supervisor
  """
  def start_link(_args) do
    Logger.info("Initiating SimulationSupervisor...")

    DynamicSupervisor.start_link(__MODULE__, name: Chord.SimulationSupervisor)
  end

  @doc """
  Chord.SimulationSupervisor.start_location_server

  Starts the location server for the entire network

  TODO: Distributed location service based on topology or geography
  """
  def start_location_server(supervisor) do
    Logger.info("Initiating LocationServer...")
    DynamicSupervisor.start_child(supervisor, {Chord.LocationServer, []})
  end

  @doc """
  Chord.SimulationSupervisor.start_node

  Starts the node in a network
  """
  def start_node(supervisor, location_server) do
    # Generate random ip address
    ip_addr = get_ip_addr()
    Logger.info("Initiaing node with ip address -> " <> ip_addr)
    # Come alive with that ip address
    DynamicSupervisor.start_child(
      supervisor,
      {Chord.Node, [ip_addr: ip_addr, location_server: location_server]}
    )
  end

  @doc """
  Chord.SimulationSupervisor.start_simulation

  Method to start the simulation of chord algorithm. Spawn nodes at random intervals and make them join the network
  """
  def start_simulation(supervisor) do
    {:ok, location_server} = start_location_server(supervisor)
    # Start multiple nodes at a specific time interval
    start_node(supervisor, location_server)
  end

  @doc """
  Chord.SimulationSupervisor.init

  A dynamicsupervisor callback for initiating the strategy and related options for dynamic supervisor
  """
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # Get a random ip address
  #
  # TODO: Get the ip address of a real node
  defp get_ip_addr() do
    to_string(:rand.uniform(255)) <>
      "." <>
      to_string(:rand.uniform(255)) <>
      "." <> to_string(:rand.uniform(255)) <> "." <> to_string(:rand.uniform(255))
  end
end
