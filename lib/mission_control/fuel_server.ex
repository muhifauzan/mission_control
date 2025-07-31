defmodule MissionControl.FuelServer do
  @moduledoc """
  A GenServer that calculates fuel requirements for space missions.

  Supports fuel calculations for launching from and landing on Earth, Moon, and Mars.
  The service calculates both base fuel requirements and additional fuel needed to
  carry that fuel, recursively until no additional fuel is required.

  ## Formulas

  - Launch: `mass * gravity * 0.042 - 33` (rounded down)
  - Landing: `mass * gravity * 0.033 - 42` (rounded down)

  ## Examples

      iex> MissionControl.FuelServer.calculate_fuel(28801, "land", "earth")
      {:ok, 13447}

      iex> MissionControl.FuelServer.calculate_fuel(1000, "launch", "unknown")
      {:error, {:planet_not_supported, "unknown"}}
  """

  use GenServer

  defstruct [:planets]

  @type t :: %__MODULE__{
          planets: %{
            String.t() => float()
          }
        }

  @type action :: String.t()
  @type mass :: number()
  @type planet :: String.t()

  @type fuel_result ::
          {:ok, non_neg_integer()}
          | {:error, {:planet_not_supported | :action_not_supported, term()}}

  @doc """
  Starts the FuelServer GenServer.

  ## Options

  - `:planets` - Additional planets with their gravity values (optional)

  ## Examples

      MissionControl.FuelServer.start_link()
      MissionControl.FuelServer.start_link(planets: %{"jupiter" => 24.79})
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc """
  Calculates the total fuel required for a space mission action.

  ## Parameters

  - `mass` - The mass of the spacecraft in kg
  - `action` - Either "launch" or "land"
  - `planet` - The target planet ("earth", "moon", or "mars")

  ## Returns

  - `{:ok, fuel_amount}` - The total fuel required in kg
  - `{:error, {:planet_not_supported, planet}}` - Unknown planet
  - `{:error, {:action_not_supported, action}}` - Invalid action

  ## Examples

      iex> calculate_fuel(28801, "land", "earth")
      {:ok, 13447}

      iex> calculate_fuel(1000, "takeoff", "earth")
      {:error, {:action_not_supported, "takeoff"}}
  """
  @spec calculate_fuel(mass(), action(), planet()) :: fuel_result()
  def calculate_fuel(mass, action, planet) do
    GenServer.call(__MODULE__, {:calculate_fuel, mass, action, planet})
  end

  ## Callbacks

  @impl true
  def init(init_arg) do
    planets = Keyword.get(init_arg, :planets, %{})

    default_planets = %{
      "earth" => 9.807,
      "moon" => 1.62,
      "mars" => 3.711
    }

    {:ok, %__MODULE__{planets: Map.merge(default_planets, planets)}}
  end

  @impl true
  def handle_call({:calculate_fuel, mass, action, planet}, _from, %__MODULE__{} = state) do
    case Map.get(state.planets, planet) do
      nil ->
        {:reply, {:error, {:planet_not_supported, planet}}, state}

      gravity ->
        case do_calculate_fuel(action, mass, gravity) do
          {:ok, _fuel_required} = result ->
            {:reply, result, state}

          {:error, {:action_error, action}} ->
            {:reply, {:error, {:action_not_supported, action}}, state}
        end
    end
  end

  ## Privates

  defp do_calculate_fuel(action, mass, gravity) do
    case calculate_base_fuel(action, mass, gravity) do
      {:ok, base_fuel} ->
        additional_fuel = calculate_additional_fuel(base_fuel, action, gravity)
        {:ok, base_fuel + additional_fuel}

      error ->
        error
    end
  end

  defp calculate_additional_fuel(required, action, gravity) do
    calculate_additional_fuel(required, action, gravity, 0)
  end

  defp calculate_additional_fuel(required, _, _, total) when required <= 0 do
    total
  end

  defp calculate_additional_fuel(required, action, gravity, total) do
    case calculate_base_fuel(action, required, gravity) do
      {:ok, required} when required > 0 ->
        calculate_additional_fuel(required, action, gravity, total + required)

      {:ok, required} ->
        calculate_additional_fuel(required, action, gravity, total)
    end
  end

  defp calculate_base_fuel("launch", mass, gravity) do
    {:ok, :math.floor(mass * gravity * 0.042 - 33)}
  end

  defp calculate_base_fuel("land", mass, gravity) do
    {:ok, :math.floor(mass * gravity * 0.033 - 42)}
  end

  defp calculate_base_fuel(action, _, _) do
    {:error, {:action_error, action}}
  end
end
