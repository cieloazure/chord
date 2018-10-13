defmodule Chord.Node.FingerFixer do
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

  # def run(next, m, ticker_pid) do
  # receive do
  # {:tick, _index} = message ->
  # next = next + 1

  # successor =
  # Chord.Node.find_successor(node[:pid], node[:identifier] + round(:math.pow(2, next - 1)))

  # Chord.Node.update_finger_table(node[:pid], successor)

  # run(next + 1, m, ticker_pid)

  # {:last_tick, _index} = message ->
  # :ok

  # {:start_fix, next, m} ->
  # ticker_pid = start(self())
  # run(next, m, ticker_pid)

  # {:stop, _reason} ->
  # stop(ticker_pid)
  # run()
  # end
  # end
end
