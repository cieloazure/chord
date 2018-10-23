usage_string =
  "Invalid arguments to the command\nUsage: mix run proj2.exs --no-halt <num_nodes:int> <num_requests:int>"

if length(System.argv()) != 2 do
  raise(ArgumentError, usage_string)
end

# TODO: optional parameters
number_of_bits = 24
num_records = 1000
[num_nodes, num_requests] = Enum.map(System.argv(), &String.to_integer/1)

Simulation.run(num_nodes, num_requests, number_of_bits, num_records)
