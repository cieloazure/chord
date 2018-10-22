require Logger
Simulation.run(10)
Process.sleep(10000)

{:ok, supervisor} = SimulationSupervisor.start_link([])
a = SimulationSupervisor.start_simulation(supervisor, 30, 24)
