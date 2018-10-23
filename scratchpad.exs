require Logger
Simulation.run(10)
Process.sleep(10000)

{:ok, supervisor} = SimulationSupervisor.start_link([])
a = SimulationSupervisor.start_simulation(supervisor, 5, 16)
ac = [a1, a2, a3] = Enum.take(a, 3)

nodes =
  Enum.map(a, fn e ->
    {n, _} = :sys.get_state(e)
    n
  end)

n2 = Enum.at(nodes, 1)
n2s = :sys.get_state(n2)
DynamicSupervisor.terminate_child(supervisor, a2)
