# Chord
## Project 3

A simulation of Chord algorithm based on [paper](https://pdos.csail.mit.edu/papers/ton:chord/paper-ton.pdf)


### How to run the project? 

```
mix run <nodes> <requests>
```
For example, 
    ```
    mix run 1000 10
   ```
### Sample Output for the above example
   ```
   20:49:54.107 [info]  Creating Nodes....
|=========================================================================| 100%

20:52:26.027 [info]  Waiting 10s for stabalization...

20:52:36.028 [info]  Inserting dummy  data for simulation....
|=========================================================================| 100%

20:52:37.865 [info]  Sending 10 requests from each node....

20:52:53.179 [info]  Average number of hops is: 4.8625
   ```
### Team Member
- Akash Shingte UFID: 4874-1966

### What is working
- Basic chord protocol without failure
- Chord API 
   - find_successor
   - lookup
   - insert
   - join
   - stabalization
   - fingers
- Insertion and retrieval of data

###  Largest network I managed to deal with
2000 nodes in around 5 minutes on a 2 core Macbook Air
