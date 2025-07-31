defmodule MissionControl.FuelServerTest do
  use ExUnit.Case, async: false

  alias MissionControl.FuelServer

  describe "calculate_fuel/3" do
    test "calculates fuel for Apollo 11 landing on Earth" do
      assert {:ok, 13447.0} = FuelServer.calculate_fuel(28801, "land", "earth")
    end

    test "calculates fuel for launch operations" do
      assert {:ok, fuel} = FuelServer.calculate_fuel(1000, "launch", "earth")
      assert fuel > 0
    end

    test "handles different planets" do
      assert {:ok, _} = FuelServer.calculate_fuel(1000, "launch", "moon")
      assert {:ok, _} = FuelServer.calculate_fuel(1000, "launch", "mars")
    end

    test "returns error for unknown planet" do
      assert {:error, {:planet_not_supported, "pluto"}} =
               FuelServer.calculate_fuel(1000, "launch", "pluto")
    end

    test "returns error for unknown action" do
      assert {:error, {:action_not_supported, "teleport"}} =
               FuelServer.calculate_fuel(1000, "teleport", "earth")
    end
  end
end
