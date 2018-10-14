defmodule Chord.Node.FingerFixer do
  require Logger
  @mongering_interval 5000

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

  def run(next, m, node_identifier, node_pid, finger_table, ticker_pid) do
    receive do
      {:tick, _index} = message ->
        Logger.debug(inspect(message))
        next = next + 1
        Logger.debug(next)

        next =
          if next > m do
            1
          else
            next
          end

        next_finger_id =
          :binary.encode_unsigned(
            :crypto.bytes_to_integer(node_identifier) + round(:math.pow(2, next - 1))
          )

        successor =
          Chord.Node.find_successor(
            node_pid,
            next_finger_id
          )

        Logger.debug(inspect(next_finger_id))

        Logger.debug(inspect(successor))

        new_finger_table = Map.put(finger_table, {next - 1, next_finger_id}, successor)
        Logger.debug(inspect(new_finger_table))
        Chord.Node.update_finger_table(node_pid, new_finger_table)
        run(next, m, node_identifier, node_pid, new_finger_table, ticker_pid)

      {:fix_fingers, next, m, finger_table} ->
        ticker_pid = start(self())
        Logger.debug(inspect(ticker_pid))
        run(next, m, node_identifier, node_pid, finger_table, ticker_pid)

      {:update_finger_table, new_finger_table} ->
        Logger.debug("updating finger table in finger fixer")
        Logger.debug(inspect(new_finger_table))
        run(next, m, node_identifier, node_pid, new_finger_table, ticker_pid)

      {:last_tick, _index} ->
        :ok

      {:stop, _reason} ->
        stop(ticker_pid)
        run(next, m, node_identifier, node_pid, finger_table, ticker_pid)
    end
  end
end
