defmodule Chord.LocationServer do
  @moduledoc """
  Location Server to get a node n' to join a network.l  

  TODO:  A scalable solution to location service. http://cs.brown.edu/~jj/papers/grid-mobicom00.pdf  
  """
  use GenServer
  require Logger

  ###
  ###
  ### Client API
  ###
  ###

  @doc """
  Chord.LocationServer.start_link

  Starts the location server with given options
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, name: Chord.LocationServer)
  end

  @doc """
  Chord.LocationServer.node_request

  Handles the request for a node in the chord. 

  Returns a random node ip address if it exits, else return nil
  """
  def node_request(location_server, from_ip) do
    GenServer.call(location_server, {:node_request, from_ip})
  end

  ###
  ###
  ### GenServer Callbacks 
  ###
  ###

  @doc """
  Chord.LocationServer.init

  A genserver callback to initiate the state of the location server
  """
  def init(_opts) do
    # A map of ip_address and process id
    # TODO: a map with information such as ip_address, coordinates, process_id,
    # etc. Consider a ets table for implementing such functionality
    chord_nodes = %{}
    {:ok, chord_nodes}
  end

  @doc """
  Chord.LocationServer.handle_call

  A genserver callback to handle the `:node_request` message from a node which is looking to join the chord network
  """
  def handle_call({:node_request, ip_address}, {from_pid, _from_ref}, chord_nodes) do
    if Enum.empty?(chord_nodes) do
      chord_nodes = Map.put(chord_nodes, from_pid, ip_address)
      {:reply, nil, chord_nodes}
    else
      {:reply, Enum.random(chord_nodes), chord_nodes}
    end
  end
end
