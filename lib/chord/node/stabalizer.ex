defmodule Chord.Node.Stabalizer do
  require Logger
  @mongering_interval 5000

  @doc """
  Chord.Node.Stabalizer.start 

  Start the ticker for stabalizer
  Will keep receiving tick events of the form `{:tick, _index}` at every `@mongering_interval` time
  """
  def start(pid) do
    Ticker.start(pid, @mongering_interval)
  end

  @doc """
  Chord.Node.Stabalizer.stop

  Stop the ticker for stabalizer
  Will send a event of `{:last_tick, index}` to the fact monger
  """
  def stop(pid) do
    Ticker.stop(pid)
  end

  @doc """
   Chord.Node.Stabalizer.run

   Periodic runner for the stabalizer. A method to run the receive loop. This loop will receive various events like -
   * {:tick, _index} : A tick event which comes periodically from ticker which tells the node to check it's successor and in case of a new successor notify that new successor to change its predeccessor to itself
   * {:update_successor, new_successor} : A event to update the successor in the receive loop
   * {:run_stabalizer, new_successor}: A event to start the ticker and run the receive loop periodically
   * {:stop, reason} : A event to stop the timer
   * {:last_tick, _index}: A event when it's last tick of the ticker maybe used for any clean up work
  """
  def run(node_successor, node_identifier, node_ip_addr, node_pid, ticker_pid) do
    receive do
      # Event: tick
      {:tick, _index} ->
        state = :sys.get_state(node_pid)
        Logger.debug("#{inspect(node_pid)}: successor: #{inspect(state[:successor])}")
        Logger.debug("#{inspect(node_pid)}: predeccessor: #{inspect(state[:predeccessor])}")
        predeccessor_of_successor = Chord.Node.get_predeccessor(node_successor[:pid])

        if is_nil(predeccessor_of_successor) do
          Logger.debug("#{inspect(node_pid)}: Predeccessor is nil")

          if node_successor[:pid] != node_pid do
            Logger.debug(
              "#{inspect(node_pid)}:Predeccessor is nil but successor does not point to itself"
            )

            Chord.Node.notify(node_successor[:pid],
              identifier: node_identifier,
              ip_addr: node_ip_addr,
              pid: node_pid
            )
          end
        else
          {pred_id, pred_ip, pred_pid} =
            {predeccessor_of_successor[:identifier], predeccessor_of_successor[:ip_addr],
             predeccessor_of_successor[:pid]}

          {new_successor_id, new_successor_ip, new_successor_pid} =
            cond do
              pred_id == node_identifier ->
                Logger.debug(
                  "#{inspect(node_pid)} Predeccessor of my successor is me! hence continuing with same successor"
                )

                {node_successor[:identifier], node_successor[:ip_addr], node_successor[:pid]}

              pred_id != node_identifier and pred_id >= node_identifier and
                  pred_id <= node_successor[:identifier] ->
                Logger.debug(
                  "#{inspect(node_pid)}: Predeccessor of my successor is not me and the predeccessor of my successor statisfies the condition to be my successor, hence let the predeccessor of my Successor be my new Successor"
                )

                {pred_id, pred_ip, pred_pid}

              pred_id != node_identifier and
                  (pred_id <= node_identifier or pred_id >= node_successor[:identifier]) ->
                Logger.debug(
                  "#{inspect(node_pid)}: Predeccessor of my successor is not me and the predeccessor of my successor DOES NOT statisfies the condition to be my successor, hence continuing with the same successor"
                )

                {node_successor[:identifier], node_successor[:ip_addr], node_successor[:pid]}
            end

          # if successor has changed
          if new_successor_id != node_successor[:identifier] do
            Logger.debug(
              "#{inspect(node_pid)}: Successor has changed! Updating successor and notifying the successor to make us as its predeccessor"
            )

            Chord.Node.update_successor(node_pid,
              identifier: new_successor_id,
              ip_addr: new_successor_ip,
              pid: new_successor_pid
            )

            Chord.Node.notify(new_successor_pid,
              identifier: node_identifier,
              ip_addr: node_ip_addr,
              pid: node_pid
            )
          end
        end

        run(node_successor, node_identifier, node_ip_addr, node_pid, ticker_pid)

      # Event: Update successor
      {:update_successor, new_node_successor} ->
        run(new_node_successor, node_identifier, node_ip_addr, node_pid, ticker_pid)

      # Event: Run stabalizer
      {:run_stabalizer, node_successor} ->
        ticker_pid = start(self())
        Logger.info(inspect(ticker_pid))
        run(node_successor, node_identifier, node_ip_addr, node_pid, ticker_pid)

      # Event: Last tick
      # TODO: When and if we have  to use this?
      {:last_tick, _index} ->
        :ok

      # Event: Stop the finger fixer
      # TODO: When and if we have to use this?
      {:stop, _reason} ->
        stop(ticker_pid)
        run(node_successor, node_identifier, node_ip_addr, node_pid, ticker_pid)
    end
  end
end
