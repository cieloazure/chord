defmodule Chord.Node.DistributedHashTable do
  def initiate() do
    # Chord.Node.start_link()
    # Chord.Node.initiate_chord
  end

  def insert(_data) do
    # Get a unique key for the data
    #
    # Find a node responsible for storing the key
    #
    # If it is our node, then store the data in the state
    #
    # Else if it is not our node communicate with the block storage server on that node to store the data
    # with that key
  end

  def lookup(_key) do
    # Chord.Node.find_successor(key)
    #
  end
end
