defmodule Chord.Node.FingerFixer do
  require Logger
  @mongering_interval 5000

  @doc """
  Chord.Node.FingerFixer.start

  Start the ticker for stabalizer
  Will keep receiving tick events of the form `{:tick, _index}` at every `@mongering_interval` time
  """
  def start(pid) do
    Ticker.start(pid, @mongering_interval)
  end

  @doc """
  Chord.Node.FingerFixer.stop

  Stop the ticker for stabalizer
  Will send a event of `{:last_tick, index}` to the fact monger
  """
  def stop(pid) do
    Ticker.stop(pid)
  end

  @doc """
  Chord.Node.FingerFixer.run

  A method to run the receive loop. This method will receive various events like - 
  *{:tick, _index} -> Receives a periodic event from `Ticker`
  *{:fix_fingers, next, m, finger_table} -> Received when the node joins a chord network and needs to initialize its finger table
  *{:update_finger_table, new_finger_table} -> Received when a finger table has been updated in the node and needs to be updated in this process as well
  """
  def run(next, m, node_identifier, node_pid, finger_table, ticker_pid) do
    receive do
      # Event: tick, a periodic tick received from Ticker
      {:tick, _index} = message ->
        Logger.info(inspect(message))
        next = next + 1
        Logger.info(next)

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

        Logger.info(inspect(next_finger_id))

        Logger.info(inspect(successor))

        new_finger_table = Map.put(finger_table, {next - 1, next_finger_id}, successor)
        Logger.info(inspect(new_finger_table))
        Chord.Node.update_finger_table(node_pid, new_finger_table)
        run(next, m, node_identifier, node_pid, new_finger_table, ticker_pid)

      # Event: Fix Fingers
      {:fix_fingers, next, m, finger_table} ->
        ticker_pid = start(self())
        Logger.info(inspect(ticker_pid))
        run(next, m, node_identifier, node_pid, finger_table, ticker_pid)

      # Event: Update finger table
      {:update_finger_table, new_finger_table} ->
        Logger.info("updating finger table in finger fixer")
        Logger.info(inspect(new_finger_table))
        run(next, m, node_identifier, node_pid, new_finger_table, ticker_pid)

      # Event: Last tick
      # TODO: When to use this?
      {:last_tick, _index} ->
        :ok

      # Event: Stop the finger fixer
      # TODO: When and if we have to use this?
      {:stop, _reason} ->
        stop(ticker_pid)
        run(next, m, node_identifier, node_pid, finger_table, ticker_pid)
    end
  end
end
