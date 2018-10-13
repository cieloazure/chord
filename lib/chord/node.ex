defmodule Chord.Node do
  @moduledoc """
  Chord.Node

  Module to simulate a node in chord network
  """
  use GenServer
  require Logger

  # Number of bits for the identifier
  @m 160

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

  @doc """
  Chord.Node.find_successor

  An API method to find the successor of a given id
  """
  def find_successor(node, id) do
    GenServer.call(node, {:find_successor, id})
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
    identifier = :crypto.hash(:sha, ip_addr) |> Base.encode16() |> binary_part(0, 2)

    # Get the location_server from the address
    location_server = Keyword.get(opts, :location_server)

    if is_nil(location_server),
      do:
        raise(ArgumentError, message: "A Location Server is required for joining a chord network")

    # Distributed Hash table - responsible for storing, caching and replication
    # of blocks 

    # Block storage server - responsible to read or write a block

    # Finger table
    finger_table = :ets.new(:finger_table, [:set, :protected])

    {:ok,
     [
       ip_addr: ip_addr,
       identifier: identifier,
       location_server: location_server,
       predeccesor: nil,
       successor: nil,
       finger_table: finger_table
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
        successor = Chord.Node.find_successor(chord_node, state[:identifier])
        Keyword.put(state, :successor, Chord.Node.find_successor(chord_node, state[:identifier]))
      else
        state = Keyword.put(state, :predeccessor, nil)
        succ_state = [identifier: state[:identifier], ip_addr: state[:ip_addr], pid: self()]
        Keyword.put(state, :successor, succ_state)
      end

    {:noreply, state}
  end

  @doc """
  Chord.Node.handle_call for `:find_successor`

  A callback to find the successor node for a sha id provided. Used in both `lookup(key)` and `n.join(n')` operations. In lookup it finds the successor for the `key` of the data. In join operation it find the node which should be the successor of that node.
  """
  @impl true
  def handle_call({:find_successor, id}, _from, state) do
    if id < state[:successor][:identifier] do
      {:reply, state[:successor], state}
    else
      {identifier, ip_addr, pid} = closest_preceding_node(id, state)

      if pid != self() do
        successor = Chord.Node.find_successor(pid, id)
        {:reply, successor, state}
      else
        {:reply, state[:successor], state}
      end
    end
  end

  ###### PRIVATE FUNCTIONS ########

  # Chord.Node.closest_preceding_node
  # A helper function for `find_successor` callback implementation which
  # iterates through the finger table to find the node which is closest
  # predeccessor of the given id
  defp closest_preceding_node(id, state) do
    finger_table_entries = :ets.match_object(state[:finger_table], {:_, :_, :_})

    Enum.each(finger_table_entries, fn {entry_identifier, entry_ip_addr, entry_pid} ->
      if(entry_identifier >= state[:identifier] and entry_identifier <= id) do
        {entry_identifier, entry_ip_addr, entry_pid}
      end
    end)

    {state[:identifier], state[:ip_addr], self()}
  end
end
