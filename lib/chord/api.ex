defmodule Chord.API do
  @moduledoc """
  Chord.API

  The api methods to be exposed. includes important methods like insert and lookup data in the entire chord network.
  """
  use GenServer
  require Logger

  ###             ###
  ###             ###
  ### Client API  ###
  ###             ###
  ###             ###

  @doc """
  Chord.API.start_link

  Starts the genserver with given opts which include the ip address to start the node with
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Chord.API.insert 

  Inserts the data in the chord network
  """
  def insert(api, data, identifier \\ nil) do
    GenServer.call(api, {:insert, data, identifier})
  end

  @doc """
  Chord.API.lookup

  Lookup the data in the chord network
  """
  def lookup(api, data, identifier \\ nil) do
    GenServer.call(api, {:lookup, data, identifier})
  end

  ###                      ###
  ###                      ###
  ### GenServer Callbacks  ###
  ###                      ###
  ###                      ###

  @doc """
  Chord.API.init

  Initiate the api genserver with given options  and join the node with the chord network
  """
  @impl true
  def init(opts) do
    ip_addr = Keyword.get(opts, :ip_addr)
    location_server = Keyword.get(opts, :location_server)
    identifier = Keyword.get(opts, :identifier)
    number_of_bits = Keyword.get(opts, :number_of_bits)

    {:ok, node} =
      Chord.Node.start_link(
        ip_addr: ip_addr,
        location_server: location_server,
        identifier: identifier,
        number_of_bits: number_of_bits
      )

    Chord.Node.join(node)
    {:ok, node}
  end

  @doc """
  Chord.API callback for `:insert`

  Calculates the hash for the data, finds it's node and inserts it into that node
  """
  @impl true
  def handle_call({:insert, data, identifier}, _from, node) do
    # Get a unique key for the data
    key = identifier || :crypto.hash(:sha, data)

    # Find a node responsible for storing the key
    {successor, _hops} = Chord.Node.find_successor(node, key, 0)

    # Successor may be node itself or some other node in the ring
    # Write the data using block storage server of that node
    response = Chord.Node.insert(successor[:pid], key, data)
    {:reply, response, node}
  end

  @doc """
  Chord.API callback for `:lookup`

  Calculates the hash for the data and finds the node it resides on 
  """
  @impl true
  def handle_call({:lookup, data, identifier}, _from, node) do
    # Get the hash value for the data
    key = identifier || :crypto.hash(:sha, data)

    # Find the node
    {successor, hops} = Chord.Node.find_successor(node, key, 0)

    # Read  the data using block storage server of that node
    {item, from} = Chord.Node.lookup(successor[:pid], key)
    {:reply, {item, from, hops}, node}
  end
end
