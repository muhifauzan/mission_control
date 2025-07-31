defmodule Mix.Tasks.Fuel.CalculateForMission do
  @moduledoc """
  Calculates fuel requirements for space missions.

  ## Usage

      mix fuel.calculate_for_mission [options] <mass> <action:planet> [<action:planet> ...]

  ## Options

      --help, -h       Show this help message
      --quiet, -q      Suppress output formatting
      --format FORMAT  Output format: table (default), json, simple

  ## Examples

      # Apollo 11 mission
      mix fuel.calculate_for_mission 28801 launch:earth land:moon launch:moon land:earth

      # Mars mission with JSON output
      mix fuel.calculate_for_mission --format json 14606 launch:earth land:mars launch:mars land:earth

      # Quiet mode
      mix fuel.calculate_for_mission --quiet 1000 launch:earth

  ## Arguments

  - `mass` - Spacecraft dry mass in kg
  - `action:planet` - Flight steps in format "action:planet"
    - Actions: launch, land
    - Planets: earth, moon, mars
  """

  use Mix.Task

  alias MissionControl.FuelServer

  @shortdoc "Calculates fuel requirements for space missions"

  @switches [
    help: :boolean,
    quiet: :boolean,
    format: :string
  ]

  @aliases [
    h: :help,
    q: :quiet,
    f: :format
  ]

  @doc """
  Runs the fuel mission calculation task.
  """
  @spec run([String.t()]) :: :ok
  def run(args) do
    {options, arguments, invalid} =
      OptionParser.parse(args, switches: @switches, aliases: @aliases)

    cond do
      options[:help] ->
        display_help()

      invalid != [] ->
        display_error("Invalid options: #{inspect(invalid)}")
        display_help()

      true ->
        case parse_arguments(arguments) do
          {:ok, mass, flight_path} ->
            ensure_application_started()
            calculate_and_display(mass, flight_path, options)

          {:error, reason} ->
            display_error(reason)
            display_help()
        end
    end
  end

  defp parse_arguments([]), do: {:error, "No arguments provided"}
  defp parse_arguments([_mass]), do: {:error, "No flight path provided"}

  defp parse_arguments([mass_str | flight_steps]) do
    with {:ok, mass} <- parse_mass(mass_str),
         {:ok, flight_path} <- parse_flight_path(flight_steps) do
      {:ok, mass, flight_path}
    end
  end

  defp parse_mass(mass_str) do
    case Integer.parse(mass_str) do
      {mass, ""} when mass > 0 ->
        {:ok, mass}

      {_mass, ""} ->
        {:error, "Mass must be positive"}

      _ ->
        {:error, "Invalid mass: #{mass_str}"}
    end
  end

  defp parse_flight_path(flight_steps) do
    flight_steps
    |> Enum.reduce_while({:ok, []}, fn step, {:ok, acc} ->
      case parse_flight_step(step) do
        {:ok, parsed_step} ->
          {:cont, {:ok, [parsed_step | acc]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, steps} -> {:ok, Enum.reverse(steps)}
      error -> error
    end
  end

  defp parse_flight_step(step) do
    case String.split(step, ":") do
      [action, planet]
      when action in ["launch", "land"] and planet in ["earth", "moon", "mars"] ->
        {:ok, {action, planet}}

      [action, _planet] when action not in ["launch", "land"] ->
        {:error, "Invalid action: #{action}. Use 'launch' or 'land'"}

      [_action, planet] ->
        {:error, "Invalid planet: #{planet}. Use 'earth', 'moon', or 'mars'"}

      _ ->
        {:error, "Invalid flight step format: #{step}. Use 'action:planet'"}
    end
  end

  defp ensure_application_started do
    case GenServer.whereis(FuelServer) do
      nil ->
        {:ok, _pid} = FuelServer.start_link()

      _pid ->
        :ok
    end
  end

  defp calculate_and_display(mass, flight_path, options) do
    case MissionControl.calculate_mission_fuel(mass, flight_path) do
      {:ok, fuel_required} ->
        format_output(mass, flight_path, fuel_required, options)

      {:error, reason} ->
        display_error("Mission calculation failed: #{reason}")
    end
  end

  defp format_output(mass, flight_path, fuel_required, options) do
    format = Keyword.get(options, :format, "table")
    quiet = Keyword.get(options, :quiet, false)

    case format do
      "json" ->
        output_json(mass, flight_path, fuel_required)

      "simple" ->
        output_simple(fuel_required, quiet)

      _ ->
        output_table(mass, flight_path, fuel_required, quiet)
    end
  end

  defp output_json(mass, flight_path, fuel_required) do
    result = %{
      equipment_mass_kg: mass,
      flight_path:
        Enum.map(flight_path, fn {action, planet} -> %{action: action, planet: planet} end),
      fuel_required_kg: fuel_required,
      total_mass_kg: mass + fuel_required
    }

    Mix.shell().info(Jason.encode!(result, pretty: true))
  rescue
    UndefinedFunctionError ->
      display_error(
        "JSON output requires the Jason library. Add {:jason, \"~> 1.0\"} to your deps."
      )

      output_simple(fuel_required, false)
  end

  defp output_simple(fuel_required, quiet) do
    if quiet do
      Mix.shell().info("#{fuel_required}")
    else
      Mix.shell().info("Fuel required: #{format_number(fuel_required)} kg")
    end
  end

  defp output_table(mass, flight_path, fuel_required, quiet) do
    unless quiet do
      Mix.shell().info("🚀 NASA Mission Fuel Calculator")
      Mix.shell().info("=" |> String.duplicate(40))
      Mix.shell().info("Equipment mass: #{format_number(mass)} kg")
      Mix.shell().info("Flight path:")

      flight_path
      |> Enum.with_index(1)
      |> Enum.each(fn {{action, planet}, index} ->
        Mix.shell().info(
          "  #{index}. #{String.capitalize(action)} from #{String.capitalize(planet)}"
        )
      end)

      Mix.shell().info("")
      Mix.shell().info("✅ Mission fuel calculated successfully!")
    end

    Mix.shell().info("Required fuel: #{format_number(fuel_required)} kg")

    unless quiet do
      Mix.shell().info("Total mission mass: #{format_number(mass + fuel_required)} kg")
    end
  end

  defp display_error(message) do
    Mix.shell().error("❌ Error: #{message}")
  end

  defp display_help do
    Mix.shell().info(@moduledoc)
  end

  defp format_number(number) do
    number
    |> to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end
end
