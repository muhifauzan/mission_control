defmodule MissionControl do
  alias MissionControl.FuelServer

  def calculate_mission_fuel(mass, flight_path) do
    with :ok <- validate_mission(flight_path) do
      flight_path
      |> Enum.reverse()
      |> Enum.reduce_while({:ok, mass}, &process_flight_step/2)
      |> extract_fuel_total(mass)
    end
  end

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
