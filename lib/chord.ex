defmodule Chord do
  @moduledoc """
  Documentation for Chord.
  """
  use Application

  @doc """
  Hello world.

  ## Examples

      iex> Chord.hello()
      :world

  """
  def hello do
    :world
  end

  @doc """
  Start the Simulation Application
  """
  def start(_type, _args) do
    Chord.SimulationSupervisor.start_link([])
  end
end
