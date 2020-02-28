# Julia SQS Ephemerides Demo

Start a Julia REPL session with this repo as the active project.

```bash
julia --project
```

Request some ephemerides from a Docker container running on AWS ECS.

```julia
using JuliaSQSEphemerides

JuliaSQSEphemerides.get_ephemeris(:state, "2020-02-27T21:56:23.123", :sun, :jupiter)
```
