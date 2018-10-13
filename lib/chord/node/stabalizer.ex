defmodule Chord.Node.Stabalizer do
  require Logger
  @mongering_interval 1000

  @doc """
  Start the ticker for stabalizer
  Will keep receiving tick events of the form `{:tick, _index}` at every `@mongering_interval` time
  """
  def start(pid) do
    Ticker.start(pid, @mongering_interval)
  end

  @doc """
  Stop the ticker for stabalizer
  Will send a event of `{:last_tick, index}` to the fact monger
  """
  def stop(pid) do
    Ticker.stop(pid)
  end

  # def run(ticker_pid) do
  # receive do
  # {:tick, _index} = message ->
  # unknown_successor = Chord.Node.get_predecessor(successor[:pid])

  # {new_successor, old_successor} =
  # if unknown_successor >= identifier and unknown_successor <= successor do
  # Chord.Node.change_succesor(pid)
  # {unknown_successor, nil}
  # else
  # {nil, old_successor}
  # end

  # if !is_nil(old_successor) do
  # Chord.Node.notify(new_successor, n)
  # end

  # run()

  # {:last_tick, _index} = message ->
  # :ok

  # {:stop, _reason} ->
  # stop(ticker_pid)
  # run()
  # end
  # end
end
