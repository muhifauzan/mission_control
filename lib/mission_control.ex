defmodule MissionControl do
  @moduledoc """
  Mission planning module for calculating total fuel requirements for space missions.

  This module handles multi-step flight paths, calculating the cumulative fuel needed
  for the entire mission. It processes flight steps in reverse order to account for
  the fact that fuel for later steps must be carried from the beginning of the mission.

  ## Examples

      # Apollo 11 mission
      flight_path = [
        {:launch, "earth"},
        {:land, "moon"},
        {:launch, "moon"},
        {:land, "earth"}
      ]

      MissionControl.calculate_mission_fuel(28801, flight_path)
      # => {:ok, 51898}
  """

  alias MissionControl.FuelServer

  @type mass :: number()
  @type flight_step :: {action :: String.t(), planet :: String.t()}
  @type flight_path :: [flight_step()]
  @type mission_result :: {:ok, non_neg_integer()} | {:error, String.t()}

  @doc """
  Calculates the total fuel required for a complete space mission.

  Processes the flight path in reverse order, accumulating fuel requirements
  for each step. This ensures that fuel needed for later mission phases is
  accounted for in the total mass from the beginning.

  ## Parameters

  - `mass` - The dry mass of the spacecraft in kg
  - `flight_path` - List of flight steps as `{action, planet}` tuples

  ## Returns

  - `{:ok, total_fuel}` - Total fuel required for the mission in kg
  - `{:error, reason}` - Validation error with descriptive message

  ## Examples

      iex> flight_path = [{"launch", "earth"}, {"land", "moon"}]
      iex> MissionControl.calculate_mission_fuel(1000, flight_path)
      {:ok, 536.0}

      iex> invalid_path = [{"launch", "pluto"}]
      iex> MissionControl.calculate_mission_fuel(1000, invalid_path)
      {:error, "Unsupported planet: pluto"}
  """
  @spec calculate_mission_fuel(mass(), flight_path()) :: mission_result()
  def calculate_mission_fuel(mass, flight_path) do
    with :ok <- validate_mission(flight_path) do
      flight_path
      |> Enum.reverse()
      |> Enum.reduce_while({:ok, mass}, &process_flight_step/2)
      |> extract_fuel_total(mass)
    end
  end

  @doc """
  Validates that all steps in a flight path are supported.

  Checks each flight step to ensure the action and planet are recognized
  by the FuelServer. Stops at the first invalid step encountered.

  ## Parameters

  - `flight_path` - List of flight steps to validate

  ## Returns

  - `:ok` - All steps are valid
  - `{:error, reason}` - First validation error encountered

  ## Examples

      iex> MissionControl.validate_mission([{"launch", "earth"}, {"land", "moon"}])
      :ok

      iex> MissionControl.validate_mission([{"launch", "earth"}, {"land", "pluto"}])
      {:error, "Unsupported planet: pluto"}
  """
  @spec validate_mission(flight_path()) :: :ok | {:error, String.t()}
  def validate_mission(flight_path) do
    flight_path
    |> Enum.reduce_while(:ok, fn {action, planet}, _acc ->
      case validate_step(action, planet) do
        :ok ->
          {:cont, :ok}

        error ->
          {:halt, error}
      end
    end)
  end

  ## Privates

  defp process_flight_step({action, planet}, {:ok, current_mass}) do
    case FuelServer.calculate_fuel(current_mass, action, planet) do
      {:ok, fuel_required} ->
        {:cont, {:ok, current_mass + fuel_required}}

      {:error, _reason} = error ->
        {:halt, error}
    end
  end

  defp extract_fuel_total({:ok, total_mass}, mass) do
    {:ok, total_mass - mass}
  end

  defp extract_fuel_total({:error, _reason} = error, _) do
    error
  end

  defp validate_step(action, planet) do
    case FuelServer.calculate_fuel(1, action, planet) do
      {:ok, _} ->
        :ok

      {:error, {:planet_not_supported, planet}} ->
        {:error, "Unsupported planet: #{planet}"}

      {:error, {:action_not_supported, action}} ->
        {:error, "Unsupported action: #{action}"}
    end
  end
end
