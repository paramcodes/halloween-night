extends Node3D
## Composition root: builds the village, the player, the horde and the HUD, then
## runs the dusk -> night -> dawn -> day loop until the run ends.

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
const VILLAGER_SCENE := preload("res://scenes/actors/villager.tscn")
const PERF_SCENE := "res://scenes/systems/perf_harness.tscn"

const VILLAGER_NAMES := [
	"Ada",
	"Bram",
	"Cael",
	"Dara",
	"Ede",
	"Fen",
	"Greta",
	"Hale",
	"Ivo",
	"Jori",
	"Kesh",
	"Lira",
	"Mab",
	"Nell",
	"Odo",
	"Pell",
	"Quin",
	"Rill",
]

const DUSK_OPTIONS := [
	{"id": "fuel", "title": "Fuel cache", "detail": "Refill the flamethrower to full"},
	{"id": "planks", "title": "Plank cache", "detail": "Three planks for doors"},
	{"id": "repair", "title": "Tool cache", "detail": "Repair every door by 150"},
]

var village: Village
var player: Player
var director: NightDirector
var hud: Hud
var moon: DirectionalLight3D
var world_environment: WorldEnvironment

var _choice_open := false
var _run_ended := false
var _tally_timer := 0.0
var _light_target := {
	"energy": 0.85, "color": Palette.MOON, "pitch": -42.0, "yaw": -25.0, "fog": 0.008
}
var _smoke := false
var _capture := false
var _smoke_report := {"phases": [], "nights": [], "spawned": 0, "finished": false}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--perf" in args:
		get_tree().call_deferred("change_scene_to_file", PERF_SCENE)
		return
	_smoke = "--smoke" in args
	_capture = "--capture" in args
	if _smoke:
		_configure_smoke()
	_build_environment()
	_load_save()
	village = Village.new()
	village.name = "Village"
	add_child(village)
	village.build(Game.tuning)
	_spawn_player()
	director = NightDirector.new()
	director.name = "NightDirector"
	add_child(director)
	director.setup(village, player)
	_spawn_villagers()
	_apply_saved_doors()
	hud = Hud.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(player, village, director)
	_connect_signals()
	_apply_phase_lighting(GameClock.phase, true)
	if _capture:
		_start_capture()
		return
	GameClock.start(Game.night())
	EventBus.toast.emit("Hold a street. The rest will burn without you.")
	if _smoke:
		Engine.time_scale = 6.0


func _configure_smoke() -> void:
	Game.headless = true
	Game.tuning.day_seconds = 2.0
	Game.tuning.dusk_seconds = 1.0
	Game.tuning.night_seconds = 6.0
	Game.tuning.dawn_seconds = 1.0


## Movie Maker take: night lighting, a full tank, a staged crowd and no clock.
## The clip is produced from the real loop; see src/core/capture_rig.gd.
func _start_capture() -> void:
	var args := OS.get_cmdline_user_args()
	var seconds := 8.0
	for i in range(args.size()):
		if args[i] == "--seconds" and i + 1 < args.size():
			seconds = float(args[i + 1])
	GameClock.stop()
	GameClock.phase = GameClock.Phase.NIGHT
	GameClock.night = Game.tuning.total_nights
	Game.set_night(Game.tuning.total_nights)
	director.night = Game.tuning.total_nights
	_apply_phase_lighting(GameClock.Phase.NIGHT, true)
	player.god_mode = true
	player.flamethrower.setup(Game.tuning.fuel_capacity)
	# A captured mouse would let the operator's hand move the camera mid-take.
	if not Game.headless:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var rig := CaptureRig.new()
	rig.name = "CaptureRig"
	add_child(rig)
	rig.setup(player, director, village, seconds)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.22, 0.30)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.08, 0.12)
	env.fog_density = 0.008
	env.fog_sky_affect = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85
	env.adjustment_contrast = 1.05
	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = env
	add_child(world_environment)

	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Palette.MOON
	moon.light_energy = 0.85
	moon.rotation_degrees = Vector3(-42, -25, 0)
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_max_distance = 110.0
	moon.directional_shadow_split_1 = 0.12
	moon.directional_shadow_blend_splits = true
	moon.shadow_bias = 0.06
	add_child(moon)


func _load_save() -> void:
	var args := OS.get_cmdline_user_args()
	if "--fresh" in args:
		SaveGame.clear()
		return
	if not SaveGame.has_save():
		return
	var data := SaveGame.read()
	if data.is_empty():
		push_warning("save could not be read: %s" % SaveGame.last_error)
		return
	Game.run = data
	Game.run_active = true
	Game.set_night(int(data.get("night", 1)))
	push_warning("resumed night %d from save" % Game.night())


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.position = Vector3(0, 0.2, 8)
	add_child(player)
	player.flamethrower.setup(Game.fuel())
	if _smoke:
		player.god_mode = true


func _spawn_villagers() -> void:
	var saved := _saved_villagers()
	var index := 0
	for house: House in village.houses:
		for slot in range(2):
			if index >= VILLAGER_NAMES.size():
				break
			var label: String = VILLAGER_NAMES[index]
			if saved.has(label) and not bool(saved[label]):
				index += 1
				continue
			var villager: Villager = VILLAGER_SCENE.instantiate()
			var outward := (house.interior_center - Vector3(0, 1, 0)).normalized()
			if house.door != null:
				outward = (house.door.global_position - house.interior_center).normalized()
			var spawn := house.interior_center + outward * (3.4 + slot * 1.1)
			spawn.y = 0.2
			villager.position = spawn
			add_child(villager)
			var spot: Dictionary = village.job_spots[index % village.job_spots.size()]
			villager.setup(label, house, spot, village, director, index)
			index += 1
	EventBus.villagers_changed.emit(_living_villagers(), VILLAGER_NAMES.size())


func _saved_villagers() -> Dictionary:
	var result := {}
	var entries: Array = Game.run.get("villagers", [])
	for entry: Variant in entries:
		if typeof(entry) == TYPE_DICTIONARY:
			var row: Dictionary = entry
			result[str(row.get("name", ""))] = bool(row.get("alive", true))
	return result


func _apply_saved_doors() -> void:
	var saved: Dictionary = Game.run.get("doors", {})
	if saved.is_empty():
		return
	for house: House in village.houses:
		var key := str(house.house_id)
		if saved.has(key) and house.door != null:
			house.door.restore_state(float(saved[key]), Game.tuning.door_max_hp)


func _connect_signals() -> void:
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.night_started.connect(_on_night_started)
	EventBus.night_ended.connect(_on_night_ended)
	EventBus.dawn_tally.connect(_on_dawn_tally)
	EventBus.run_over.connect(_on_run_over)
	EventBus.player_died.connect(_on_player_died)
	EventBus.villager_died.connect(_on_villager_died)
	EventBus.door_breached.connect(_on_door_breached)
	EventBus.dusk_choice_made.connect(_on_dusk_choice)


func _process(delta: float) -> void:
	if _tally_timer > 0.0:
		_tally_timer -= delta
		if _tally_timer <= 0.0:
			hud.hide_tally()
	_lerp_lighting(delta)
	if _smoke and not _run_ended:
		_tick_smoke()


func _tick_smoke() -> void:
	_smoke_report["spawned"] = director.spawned_total
	if _smoke_report["phases"].find(GameClock.phase_name()) < 0:
		_smoke_report["phases"].append(GameClock.phase_name())
	if GameClock.phase == GameClock.Phase.NIGHT:
		if _smoke_report["nights"].find(GameClock.night) < 0:
			_smoke_report["nights"].append(GameClock.night)
	if Time.get_ticks_msec() > 120000:
		_finish_smoke(false, "timeout")


func _finish_smoke(victory: bool, reason: String) -> void:
	if _run_ended and _smoke_report["finished"]:
		return
	_smoke_report["finished"] = true
	_smoke_report["victory"] = victory
	_smoke_report["reason"] = reason
	_smoke_report["summary"] = Game.summary()
	_smoke_report["alive_zombies"] = director.alive_count()
	var file := FileAccess.open("res://smoke.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_smoke_report, "\t"))
		file.close()
	print("[SMOKE] ", JSON.stringify(_smoke_report))
	get_tree().quit(0 if reason != "timeout" else 1)


func _on_phase_changed(phase: int, night: int) -> void:
	_apply_phase_lighting(phase, false)
	match phase:
		GameClock.Phase.DUSK:
			hud.hide_tally()
			_autosave()
			_open_dusk_choice()
			EventBus.toast.emit("Night %d. Choose your cache." % night)
		GameClock.Phase.NIGHT:
			hud.hide_dusk_choice()
			_choice_open = false
			EventBus.toast.emit("Night %d. They are coming." % night)
		GameClock.Phase.DAWN:
			EventBus.toast.emit("Dawn. The dead burn out.")
		GameClock.Phase.DAY:
			hud.hide_tally()
			EventBus.toast.emit("Day %d. Repair what you can." % night)


func _on_night_started(night: int) -> void:
	director.start_night(night)


func _on_night_ended(_night: int, _survived: bool) -> void:
	director.end_night()
	Game.add_stat("nights_survived", 1.0)


func _on_dawn_tally(summary: Dictionary) -> void:
	hud.show_tally(summary)
	_tally_timer = 7.0


func _on_run_over(victory: bool, _summary: Dictionary) -> void:
	_end_run(victory, "night 7 reached" if victory else "run ended")


func _on_player_died() -> void:
	_end_run(false, "player died")


func _on_villager_died(display_name: String) -> void:
	EventBus.toast.emit("%s is gone." % display_name)
	EventBus.villagers_changed.emit(_living_villagers(), VILLAGER_NAMES.size())
	call_deferred("_check_village_empty")


func _check_village_empty() -> void:
	if _run_ended or player == null or not is_instance_valid(player) or not player.alive:
		return
	if _living_villagers() <= 0:
		_end_run(false, "no villagers left")


func _living_villagers() -> int:
	var count := 0
	for villager: Villager in director.villagers:
		if is_instance_valid(villager) and not villager.is_dead():
			count += 1
	return count


func _on_door_breached(house_id: int) -> void:
	Game.add_stat("doors_lost", 1)
	var house := village.house_by_id(house_id)
	var name := house.display_name if house != null else "A house"
	EventBus.toast.emit("%s's door is open!" % name)


func _open_dusk_choice() -> void:
	_choice_open = true
	hud.show_dusk_choice(DUSK_OPTIONS)


func _on_dusk_choice(option_id: String) -> void:
	if not _choice_open:
		return
	_choice_open = false
	match option_id:
		"fuel":
			player.flamethrower.add_fuel(Game.tuning.fuel_per_canister)
			Game.set_fuel(player.flamethrower.fuel)
			EventBus.toast.emit("Canister carried in. The tank is full.")
		"planks":
			Game.add_planks(3)
			EventBus.toast.emit("Three planks carried in.")
		"repair":
			for house: House in village.houses:
				if house.door != null and not house.door.broken:
					house.door.repaired(150.0)
			EventBus.toast.emit("Every door patched.")
		_:
			EventBus.toast.emit("Nothing carried in.")
	_autosave()


func _apply_phase_lighting(phase: int, immediate: bool) -> void:
	match phase:
		GameClock.Phase.DAY:
			_light_target = {
				"energy": 1.15,
				"color": Color("fff1da"),
				"pitch": -58.0,
				"yaw": -38.0,
				"fog": 0.0025
			}
		GameClock.Phase.DUSK:
			_light_target = {
				"energy": 0.55, "color": Color("ff9a4a"), "pitch": -18.0, "yaw": -22.0, "fog": 0.006
			}
		GameClock.Phase.NIGHT:
			_light_target = {
				"energy": 0.85, "color": Palette.MOON, "pitch": -42.0, "yaw": -25.0, "fog": 0.008
			}
		_:
			_light_target = {
				"energy": 0.6, "color": Color("c9b8d8"), "pitch": -20.0, "yaw": -30.0, "fog": 0.008
			}
	if immediate:
		_lerp_lighting(1.0)


func _lerp_lighting(delta: float) -> void:
	if moon == null:
		return
	var rate := clampf(delta * 1.4, 0.0, 1.0)
	moon.light_energy = lerpf(moon.light_energy, float(_light_target["energy"]), rate)
	moon.light_color = moon.light_color.lerp(_light_target["color"], rate)
	var target_rot := Vector3(float(_light_target["pitch"]), float(_light_target["yaw"]), 0)
	moon.rotation_degrees = moon.rotation_degrees.lerp(target_rot, rate)
	if world_environment != null and world_environment.environment != null:
		var env := world_environment.environment
		env.fog_density = lerpf(env.fog_density, float(_light_target["fog"]), rate)


func _autosave() -> void:
	if _run_ended:
		return
	Game.run["night"] = GameClock.night
	Game.run["fuel"] = Game.fuel()
	var villagers: Array = []
	for villager: Villager in director.villagers:
		if not is_instance_valid(villager):
			continue
		(
			villagers
			. append(
				{
					"name": villager.display_name,
					"alive": not villager.is_dead(),
					"home": villager.home.house_id if villager.home != null else -1,
				}
			)
		)
	Game.run["villagers"] = villagers
	var doors := {}
	for house: House in village.houses:
		if house.door != null:
			doors[str(house.house_id)] = house.door.hp
	Game.run["doors"] = doors
	if not SaveGame.write(Game.run):
		push_warning("autosave failed: %s" % SaveGame.last_error)


func _end_run(victory: bool, reason: String) -> void:
	if _run_ended:
		return
	_run_ended = true
	GameClock.stop()
	director.active = false
	director.clear_all()
	if player != null and is_instance_valid(player):
		player.set_controls_enabled(false)
	hud.hide_tally()
	hud.hide_dusk_choice()
	hud.show_run_over(victory, Game.summary())
	if not victory:
		SaveGame.clear()
	EventBus.toast.emit("")
	if _smoke:
		_finish_smoke(victory, reason)
