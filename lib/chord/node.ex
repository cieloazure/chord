defmodule Chord.Node do
  @moduledoc """
  Chord.Node

  Module to simulate a node in chord network
  """
  use GenServer
  require Logger

  # Number of bits for the identifier
  @m 16

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

  @doc """
  Chord.Node.update_finger_table

  An API method to update the finger table which passes on to the callback
  """
  def update_finger_table(node, new_finger_table) do
    GenServer.cast(node, {:update_finger_table, new_finger_table})
  end

  @doc """
  Chord.Node.notify

  An api method to "notify" about the node which thinks that it might be our predeccessor
  """
  def notify(node, new_predeccessor) do
    GenServer.cast(node, {:notify, new_predeccessor})
  end

  @doc """
  Chord.Node.get_predeccessor

  An api method to get the predeccessor of the node
  """
  def get_predeccessor(node) do
    GenServer.call(node, {:get_predeccessor})
  end

  @doc """
  Chord.Node.update_successor

  An api method to update the successor of the node
  """
  def update_successor(node, new_successor) do
    GenServer.cast(node, {:update_successor, new_successor})
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
  * finger table
  * pid of finger fixer
  """
  @impl true
  def init(opts) do
    # Get the ip address from the opts
    ip_addr = Keyword.get(opts, :ip_addr)

    # Check if the ip address is provided
    if is_nil(ip_addr),
      do: raise(ArgumentError, message: "A ip address is required for a node to initiate")

    # Assign a identifier based on the ip address 
    identifier = :crypto.hash(:sha, ip_addr) |> binary_part(0, 2)

    # Get the location_server from the address
    location_server = Keyword.get(opts, :location_server)

    if is_nil(location_server),
      do:
        raise(ArgumentError, message: "A Location Server is required for joining a chord network")

    # Distributed Hash table - responsible for storing, caching and replication
    # of blocks 

    # Block storage server - responsible to read or write a block

    # Finger table
    finger_table = %{}

    # finger_fixer
    finger_fixer =
      spawn(Chord.Node.FingerFixer, :run, [-1, @m, identifier, self(), finger_table, nil])

    # stabalizer
    stabalizer = spawn(Chord.Node.Stabalizer, :run, [nil, identifier, ip_addr, self(), nil])

    Logger.info(inspect(finger_fixer))

    {:ok,
     [
       ip_addr: ip_addr,
       identifier: identifier,
       location_server: location_server,
       predeccessor: nil,
       successor: nil,
       finger_table: finger_table,
       finger_fixer: finger_fixer,
       stabalizer: stabalizer
     ]}
  end

  @doc """
  Chord.Node.handle_cast for `:join`

  This callback is responsible for a node joining a chord network or creating a chord network if it is the only one
  It gets a node from the location server, if there is one,  with which the successor of this node is found
  It also intiates the `FingerFixer` process to periodically check the finger table

  Returns the new state of the node
  """
  @impl true
  def handle_cast({:join}, state) do
    # Get the random node from the location server
    chord_node = Chord.LocationServer.node_request(state[:location_server], state[:ip_addr])
    Logger.info(inspect(chord_node))

    # Check if the node exists, if it does then ask that node to find
    # a successor for this node
    # else create a new chord network
    state =
      if !is_nil(chord_node) do
        state = Keyword.put(state, :predeccessor, nil)
        {chord_node, _ip_addr} = chord_node
        successor = Chord.Node.find_successor(chord_node, state[:identifier])

        if successor[:identifier] > state[:identifier] do
          Keyword.put(state, :successor, successor)
        else
          Chord.Node.update_successor(successor[:pid],
            identifier: state[:identifier],
            ip_addr: state[:ip_addr],
            pid: self()
          )

          succ_state = [identifier: state[:identifier], ip_addr: state[:ip_addr], pid: self()]
          Keyword.put(state, :successor, succ_state)
        end
      else
        state = Keyword.put(state, :predeccessor, nil)
        succ_state = [identifier: state[:identifier], ip_addr: state[:ip_addr], pid: self()]
        Keyword.put(state, :successor, succ_state)
      end

    # Update the finger table for this newly created node
    send(state[:finger_fixer], {:fix_fingers, 0, @m, state[:finger_table]})

    # Start the stabalizer for this newly created node
    send(state[:stabalizer], {:run_stabalizer, state[:successor]})

    {:noreply, state}
  end

  @doc """
  Chord.Node.handle_cast for `:update_finger_table`

  A callback to handle the update of `state[:finger_table]` from  `Chord.Node.FingerFixer`. The `Chord.Node.FingerFixer` will run periodically and update the fingers in the finger table. The main node will update its state and pass on the new state to the `Chord.Node.FingerFixer` again which will use the new finger table to periodically run updates for the finger table 

  Returns the new state of the node with the finger table updated
  """
  @impl true
  def handle_cast({:update_finger_table, new_finger_table}, state) do
    state = Keyword.put(state, :finger_table, new_finger_table)
    send(state[:finger_fixer], {:update_finger_table, state[:finger_table]})
    {:noreply, state}
  end

  @doc """
  Chord.Node.handle_cast for `:notify`

  A callback for notify in which a node which thinks it might our predeccessor tells us to update our predeccessor field. We(the node in question) update it only if the predeccessor lies between the old predeccessor and our own value

  Returns the new state of the node with predeccessor field updated
  """
  @impl true
  def handle_cast({:notify, new_predeccessor}, state) do
    Logger.debug("Updating predeccessor via notify for #{inspect(self())}")

    state =
      if is_nil(state[:predeccessor]) or
           (new_predeccessor >= state[:predeccessor] and new_predeccessor <= state[:identifier]) do
        Keyword.put(state, :predeccessor, new_predeccessor)
      else
        state
      end

    {:noreply, state}
  end

  @doc """
  Chord.Node.handle_cast for `:update_successor`

  A callback to update successor of the node during the stabalization process
  """
  @impl true
  def handle_cast({:update_successor, new_successor}, state) do
    Logger.debug("Updating successor for #{inspect(self())}")
    state = Keyword.put(state, :successor, new_successor)
    send(state[:stabalizer], {:update_successor, new_successor})
    {:noreply, state}
  end

  @doc """
  Chord.Node.handle_call for `:find_successor`

  A callback to find the successor node for a sha id provided. Used in both `lookup(key)` and `n.join(n')` operations. In lookup it finds the successor for the `key` of the data. In join operation it find the node which should be the successor of that node.

  Returns `nil` if the node is not in the ring and therefore will not be able to find a successor
  Returns the `state[:successor]` which is its own successor if the id is less than that of the successor
  Returns the `successor` which it finds after delegating it to what it thinks is the  `closest_preceding_node` of the id in which case the `closest_preceding_node` takes the responsiblity of finding the successor
  """
  @impl true
  def handle_call({:find_successor, id}, _from, state) do
    if is_nil(state[:successor]) do
      {:reply, nil, state}
    else
      if id < state[:successor][:identifier] do
        Logger.info("id #{inspect(id)} is less than node's successor(which may be node itself)")
        {:reply, state[:successor], state}
      else
        Logger.info(
          "id #{inspect(id)} is greater than node's successor(which may be node itself), finding closest preceding node"
        )

        {_identifier, _ip_addr, pid} = closest_preceding_node(id, state)

        if pid != self() do
          successor = Chord.Node.find_successor(pid, id)
          {:reply, successor, state}
        else
          {:reply, state[:successor], state}
        end
      end
    end
  end

  @doc """
  Chord.Node.handle_call for `:get_predeccessor`

  A callback to get the predecessor of the node. This is needed in stabalizer in order to change the successor if a new node has joined
  """
  @impl true
  def handle_call({:get_predeccessor}, _from, state) do
    {:reply, state[:predeccessor], state}
  end

  ###### PRIVATE FUNCTIONS ########

  # Chord.Node.closest_preceding_node
  # A helper function for `find_successor` callback implementation which
  # iterates through the finger table to find the node which is closest
  # predeccessor of the given id
  defp closest_preceding_node(id, state) do
    item =
      Enum.find(state[:finger_table], fn {_idx,
                                          [
                                            identifier: entry_identifier,
                                            ip_addr: _entry_ip_addr,
                                            pid: _entry_pid
                                          ]} ->
        entry_identifier >= state[:identifier] and entry_identifier <= id
      end)

    if !is_nil(item) do
      {key,
       [
         identifier: identifier,
         ip_addr: ip_addr,
         pid: pid
       ]} = item

      Logger.info("Closest preceding node found in finger table is #{inspect(key)}")
      {identifier, ip_addr, pid}
    else
      Logger.info("No closest preceding node found in finger table, returning the node itself")
      {state[:identifier], state[:ip_addr], self()}
    end
  end
end
