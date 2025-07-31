defmodule MissionControl.FuelServer do
  use GenServer

  defstruct [:planets]

  @type t :: %__MODULE__{
          planets: %{
            String.t() => float()
          }
        }

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

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
