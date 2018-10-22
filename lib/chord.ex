defmodule Chord do
  @moduledoc """
  Documentation for Chord.
  """
  use Application

  @doc """
  Start the Simulation Application
  """
  def start(_type, _args) do
    SimulationSupervisor.start_link([])
  end
end
