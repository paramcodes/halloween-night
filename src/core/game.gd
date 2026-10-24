extends Node
## Run-scoped state and shared tuning. Autoload: Game.
##
## Holds only data that must survive scene reloads and be writable to a save
## file. Behaviour lives in the systems that own it.

const TUNING_PATH := "res://resources/tuning.tres"
const SAVE_PATH := "user://godor_save.json"

var tuning: Tuning
var rng := RandomNumberGenerator.new()
var run: Dictionary = {}
var run_active := false
var headless := false
var perf_mode := false
var _bell_night := -1


func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	tuning = load(TUNING_PATH) as Tuning
	if tuning == null:
		push_warning("tuning.tres missing; using script defaults")
		tuning = Tuning.new()
	rng.randomize()
	new_run()


func new_run(night := 1) -> void:
	run = {
		"night": night,
		"fuel": tuning.fuel_capacity,
		"planks": tuning.starting_planks,
		"bell_charges": tuning.bell_charges,
		"doors": {},
		"villagers": [],
		"stats":
		{
			"kills": 0,
			"fuel_spent": 0.0,
			"doors_lost": 0,
			"villagers_lost": 0,
			"nights_survived": 0,
			"bell_uses": 0,
		},
	}
	run_active = true


func stat(key: String) -> float:
	var stats: Dictionary = run.get("stats", {})
	return float(stats.get(key, 0.0))


func add_stat(key: String, amount: float) -> void:
	if run.is_empty():
		return
	var stats: Dictionary = run["stats"]
	stats[key] = float(stats.get(key, 0.0)) + amount


func set_stat(key: String, value: float) -> void:
	if run.is_empty():
		return
	run["stats"][key] = value


func night() -> int:
	return int(run.get("night", 1))


func set_night(value: int) -> void:
	run["night"] = clampi(value, 1, tuning.total_nights)


func fuel() -> float:
	return float(run.get("fuel", tuning.fuel_capacity))


func set_fuel(value: float) -> void:
	run["fuel"] = clampf(value, 0.0, tuning.fuel_capacity)


func planks() -> int:
	return int(run.get("planks", 0))


func add_planks(amount: int) -> void:
	run["planks"] = maxi(0, planks() + amount)


func bell_charges() -> int:
	return int(run.get("bell_charges", 0))


func use_bell() -> bool:
	if bell_charges() <= 0:
		return false
	run["bell_charges"] = bell_charges() - 1
	add_stat("bell_uses", 1.0)
	return true


func spawn_multiplier() -> float:
	return 1.0 + (tuning.wave_bell_bonus if _bell_used_this_night() else 0.0)


func ring_bell_for_night(night_number: int) -> void:
	_bell_night = night_number
	if not use_bell():
		return
	EventBus.bell_rung.emit(bell_charges())


func _bell_used_this_night() -> bool:
	return _bell_night == night()


func summary() -> Dictionary:
	return {
		"night": night(),
		"kills": int(stat("kills")),
		"fuel_spent": stat("fuel_spent"),
		"doors_lost": int(stat("doors_lost")),
		"villagers_lost": int(stat("villagers_lost")),
		"nights_survived": int(stat("nights_survived")),
	}
