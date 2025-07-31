# MissionControl

A NASA-grade fuel calculation system for space missions, built with Elixir/OTP for maximum reliability.

## Overview

This application calculates fuel requirements for spacecraft missions between Earth, Moon, and Mars. It accounts for both base fuel needs and the additional fuel required to carry that fuel, using NASA's specified formulas.

## Features

- **Reliable Fuel Calculations**: GenServer-based service with supervisor oversight
- **Multi-Planet Support**: Earth, Moon, and Mars with accurate gravity values
- **Mission Planning**: Calculate fuel for complete multi-step flight paths
- **Command Line Interface**: Easy-to-use Mix task for mission planning
- **Multiple Output Formats**: Table, JSON, and simple formats
- **Fault Tolerance**: Supervised processes ensure system reliability

## Installation

1. Clone the repository
2. Install dependencies: `mix deps.get`
3. Compile: `mix compile`

## Usage

### Command Line Interface

```bash
# Apollo 11 mission
mix fuel.mission 28801 launch:earth land:moon launch:moon land:earth

# Mars mission with JSON output
mix fuel.mission --format json 14606 launch:earth land:mars launch:mars land:earth

# Simple output for scripting
mix fuel.mission --format simple 1000 launch:earth

# Get help
mix fuel.mission --help
```

### Programmatic Usage

```elixir
# Start the application
{:ok, _} = Application.ensure_all_started(:mission_control)

# Calculate single-step fuel
{:ok, fuel} = MissionControl.FuelServer.calculate_fuel(1000, "launch", "earth")

# Calculate complete mission fuel
flight_path = [
  {"launch", "earth"},
  {"land", "moon"},
  {"launch", "moon"},
  {"land", "earth"}
]
{:ok, total_fuel} = MissionControl.calculate_mission_fuel(28801, flight_path)
```

## Fuel Calculation Formulas

- **Launch**: `mass * gravity * 0.042 - 33` (rounded down)
- **Landing**: `mass * gravity * 0.033 - 42` (rounded down)

### Planet Gravity Values
- **Earth**: 9.807 m/s²
- **Moon**: 1.62 m/s²
- **Mars**: 3.711 m/s²

## Verified NASA Test Cases

| Mission | Equipment Mass | Flight Path | Total Fuel |
|---------|----------------|-------------|------------|
| Apollo 11 | 28,801 kg | Earth→Moon→Earth | 51,898 kg |
| Mars Mission | 14,606 kg | Earth→Mars→Earth | 33,388 kg |
| Passenger Ship | 75,432 kg | Earth→Moon→Mars→Earth | 212,161 kg |

## Architecture & Fault Tolerance

### Supervision Strategy

The application uses OTP's supervision principles for maximum reliability:

```elixir
defmodule MissionControl.Application do
  use Application

  def start(_type, _args) do
    children = [
      MissionControl.FuelServer
    ]

    opts = [strategy: :one_for_one, name: MissionControl.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### Supervisor Restart Behavior

The supervisor will restart the `FuelServer` GenServer under the following circumstances:

#### When Restarts Occur:
- **Process Crashes**: Unhandled exceptions, pattern match failures, or explicit exits
- **Memory Issues**: Out-of-memory conditions or excessive heap usage
- **Timeout Errors**: GenServer calls that exceed timeout limits
- **Network/IO Failures**: If the server were extended to use external resources

#### Restart Limits:
The supervisor has built-in limits:

- **Max Restarts**: 3 attempts (default)
- **Time Window**: Within 5 seconds (default)
- **Failure Behavior**: If the GenServer crashes more than 3 times within 5 seconds, the supervisor gives up and terminates itself

#### Strategy Details:
- **`:one_for_one`**: Only the crashed child is restarted, other processes continue running
- **Restart Type**: `:permanent` - The GenServer is always restarted if it terminates
- **Shutdown**: `:brutal_kill` - GenServer is forcefully terminated if it doesn't shut down gracefully

#### Custom Restart Configuration:
You can customize restart behavior:

```elixir
# More tolerant configuration
opts = [
  strategy: :one_for_one,
  name: MissionControl.Supervisor,
  max_restarts: 10,    # Allow more restart attempts
  max_seconds: 60      # Over a longer time window
]
```

This design ensures that temporary failures (network blips, memory spikes) don't bring down the entire fuel calculation system, but persistent failures that indicate serious problems will eventually stop restart attempts to prevent infinite crash loops.

## Testing

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover
```

## Development

The codebase follows Elixir best practices:
- Functional programming patterns with pipelines
- Pattern matching for control flow
- GenServer for stateful service management
- Comprehensive documentation and type specs
- Fault-tolerant supervision trees
