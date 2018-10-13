defmodule Chord.Node do
  @moduledoc """
  Chord.Node

  Module to simulate a node in chord network
  """
  use GenServer
  require Logger

  ###
  ###
  ### Client API
  ###
  ###

  @doc """
  Chord.Node.start_link

  An API Method to start the node with given options
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Chord.Node.join

  An API method to initiate the chord network for this node by either adding the node to the existing network or creating a new network with this node as the first node in the network
  """
  def join(node) do
    GenServer.cast(node, {:join})
  end

  def find_successor(node, id) do
    GenServer.cast(node, {:find_successor, id})
  end

  ###
  ###
  ### GenServer Callbacks 
  ###
  ###

  @doc """
  Chord.Node.init

  A callback to initiate the state of the node. The state of the node includes the following- 
  * ip address of the node
  * ip address of the location server
  * m-bit identifier using sha1 where m is 160 bit
  * predeccessor of the node
  * successor of the node
  """
  @impl true
  def init(opts) do
    # Get the ip address from the opts
    ip_addr = Keyword.get(opts, :ip_addr)

    # Check if the ip address is provided
    if is_nil(ip_addr),
      do: raise(ArgumentError, message: "A ip address is required for a node to initiate")

    # Assign a identifier based on the ip address 
    identifier = :crypto.hash(:sha, ip_addr) |> Base.encode16()

    # Get the location_server from the address
    location_server = Keyword.get(opts, :location_server)

    if is_nil(location_server),
      do:
        raise(ArgumentError, message: "A Location Server is required for joining a chord network")

    # Distributed Hash table - responsible for storing, caching and replication
    # of blocks 

    # Block storage server - responsible to read or write a block

    {:ok,
     [
       ip_addr: ip_addr,
       identifier: identifier,
       location_server: location_server,
       predeccesor: nil,
       successor: nil
     ]}
  end

  @doc """
  Chord.Node.handle_cast for `:join`

  A callback to get the node from the location server with which the successor of this node is found
  """
  @impl true
  def handle_cast({:join}, state) do
    chord_node = Chord.LocationServer.node_request(state[:location_server], state[:ip_addr])

    state =
      if !is_nil(chord_node) do
        state = Keyword.put(state, :predeccessor, nil)
        Keyword.put(state, :successor, Chord.Node.find_successor(chord_node, self()))
      else
        state = Keyword.put(state, :predeccessor, nil)
        Keyword.put(state, :successor, state[:identifier])
      end

    {:noreply, state}
  end

  @impl true
  def handle_call({:find_successor, id}, _from, state) do
    # if id lies between state[:idenfier] and state[:successor]
    # return state[:successor]
    # else
    # return Chord.Node.find_successor(state[:successor], id)
  end
end
