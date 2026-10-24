extends TestCase
## Locks the design constants from PLAN.md. If a tuning pass moves one of these,
## it must be a deliberate edit to both the plan and this test.

var tuning: Tuning


func _init() -> void:
	tuning = Game.tuning


func test_clock_constants() -> void:
	equal(tuning.night_seconds, 300.0, "night is five minutes")
	almost(tuning.day_seconds, 210.0, 0.1, "day is three and a half minutes")
	equal(tuning.total_nights, 7, "seven nights")


func test_flamethrower_budget() -> void:
	equal(tuning.fuel_capacity, 100.0, "fuel capacity")
	equal(tuning.burn_rate_per_second, 6.0, "burn rate")
	almost(tuning.fuel_capacity / tuning.burn_rate_per_second, 16.67, 0.05, "16.6 s continuous")
	equal(tuning.flame_range, 8.0, "eight metre reach")
	equal(tuning.flame_cone_degrees, 45.0, "45 degree cone")
	equal(tuning.flame_direct_dps, 18.0, "18 direct dps")
	equal(tuning.flame_burn_dps, 12.0, "12 burn dps")
	equal(tuning.flame_burn_seconds, 3.0, "3 s burn")
	equal(tuning.flame_ray_count, 12, "12-ray fan")


func test_actor_speeds() -> void:
	equal(tuning.walk_speed, 2.6, "walk speed")
	equal(tuning.sprint_speed, 5.2, "sprint speed")
	equal(tuning.aim_speed, 1.6, "aim speed")
	equal(tuning.zombie_speed, 1.4, "shamble speed")
	equal(tuning.zombie_lunge_speed, 4.5, "lunge speed")
	equal(tuning.zombie_hp, 100.0, "zombie hp")
	equal(tuning.zombie_door_dps, 15.0, "zombie door dps")
	almost(tuning.door_hp / tuning.zombie_door_dps, 13.3, 0.1, "door holds ~13 s")


func test_village_constants() -> void:
	equal(tuning.house_count, 9, "nine houses")
	equal(tuning.door_hp, 200.0, "door hp")
	equal(tuning.boarding_bonus, 150.0, "boarding adds 150")
	equal(tuning.boarding_seconds, 4.0, "boarding takes four seconds")
	equal(tuning.bell_charges, 3, "three bell charges")
	equal(tuning.wave_bell_bonus, 0.2, "bell adds 20 percent")
	equal(tuning.zombie_cap, 200, "horde cap")


func test_wave_budget() -> void:
	equal(tuning.night_wave_size(1), 14, "night 1 wave is 14")
	equal(tuning.night_wave_size(7), 50, "night 7 wave is 50")
	equal(tuning.waves_for_night(1), 4, "night 1 has four waves")
	equal(tuning.waves_for_night(7), 10, "night 7 has ten waves")
	equal(tuning.night_wave_size(7) * tuning.waves_for_night(7), 500, "night 7 total budget")
