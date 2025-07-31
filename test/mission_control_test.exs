defmodule MissionControlTest do
  use ExUnit.Case, async: false

  describe "calculate_mission_fuel/2" do
    test "calculates Apollo 11 mission fuel" do
      # From spec: launch Earth, land Moon, launch Moon, land Earth
      # Equipment: 28801 kg, Expected fuel: 51898 kg
      flight_path = [
        {"launch", "earth"},
        {"land", "moon"},
        {"launch", "moon"},
        {"land", "earth"}
      ]

      assert {:ok, 51898.0} = MissionControl.calculate_mission_fuel(28801, flight_path)
    end

    test "calculates Mars mission fuel" do
      # From spec: launch Earth, land Mars, launch Mars, land Earth
      # Equipment: 14606 kg, Expected fuel: 33388 kg
      flight_path = [
        {"launch", "earth"},
        {"land", "mars"},
        {"launch", "mars"},
        {"land", "earth"}
      ]

      assert {:ok, 33388.0} = MissionControl.calculate_mission_fuel(14606, flight_path)
    end

    test "calculates passenger ship mission fuel" do
      # From spec: launch Earth, land Moon, launch Moon, land Mars, launch Mars, land Earth
      # Equipment: 75432 kg, Expected fuel: 212161 kg
      flight_path = [
        {"launch", "earth"},
        {"land", "moon"},
        {"launch", "moon"},
        {"land", "mars"},
        {"launch", "mars"},
        {"land", "earth"}
      ]

      assert {:ok, 212_161.0} = MissionControl.calculate_mission_fuel(75432, flight_path)
    end

    test "handles simple single-step mission" do
      flight_path = [{"launch", "earth"}]
      assert {:ok, fuel} = MissionControl.calculate_mission_fuel(1000, flight_path)
      assert fuel > 0
    end

    test "returns error for unknown planet" do
      flight_path = [{"launch", "pluto"}]

      assert {:error, "Unsupported planet: pluto"} =
               MissionControl.calculate_mission_fuel(1000, flight_path)
    end

    test "returns error for unknown action" do
      flight_path = [{"teleport", "earth"}]

      assert {:error, "Unsupported action: teleport"} =
               MissionControl.calculate_mission_fuel(1000, flight_path)
    end
  end

  describe "validate_mission/1" do
    test "validates correct flight path" do
      flight_path = [{"launch", "earth"}, {"land", "moon"}]
      assert :ok = MissionControl.validate_mission(flight_path)
    end

    test "returns error for invalid planet" do
      flight_path = [{"launch", "jupiter"}]

      assert {:error, "Unsupported planet: jupiter"} =
               MissionControl.validate_mission(flight_path)
    end

    test "returns error for invalid action" do
      flight_path = [{"warp", "earth"}]

      assert {:error, "Unsupported action: warp"} =
               MissionControl.validate_mission(flight_path)
    end

    test "stops at first invalid step" do
      flight_path = [
        {"launch", "earth"},
        # This should cause the error
        {"land", "pluto"},
        # This should not be reached
        {"teleport", "mars"}
      ]

      assert {:error, "Unsupported planet: pluto"} =
               MissionControl.validate_mission(flight_path)
    end
  end
end
