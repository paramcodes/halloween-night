extends Node3D
## Stress harness: 200 live zombies, full LOD path, flame VFX, 60 s sample.
##
## Run: godot --path . -- --perf --seconds 60
## Headless runs measure simulation only; rendering metrics need a window.

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
const OUTPUT_PATH := "res://perf.json"

var village: Village
var player: Player
var director: NightDirector
var flame_origin: Node3D

var _warmup := 3.0
var _duration := 20.0
var _elapsed := 0.0
var _sampling := false
var _done := false
var _frame_ms: Array[float] = []
var _draw_calls: Array[float] = []
var _triangles: Array[float] = []
var _process_ms: Array[float] = []
var _gpu_ms: Array[float] = []
var _screenshot_taken := false


func _ready() -> void:
	_parse_args()
	_build_environment()
	village = Village.new()
	village.name = "Village"
	add_child(village)
	village.build(Game.tuning)
	player = PLAYER_SCENE.instantiate()
	player.position = Vector3(0, 0.2, 8)
	add_child(player)
	player.god_mode = true
	# Keep the camera boom from collapsing into the staged horde; the harness
	# measures render cost, not obstruction.
	player.spring.collision_mask = 0
	player.flamethrower.setup(Game.tuning.fuel_capacity)
	director = NightDirector.new()
	director.name = "NightDirector"
	add_child(director)
	director.setup(village, player)
	director.night = 7
	_fill_horde()
	_stage_horde()
	# The player rewrites `firing` from the input map every frame, so press the
	# action instead of setting the boolean. This keeps the flame VFX in the
	# measured load.
	Input.action_press("fire")
	if not Game.headless:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	print("[PERF] warming up %.1fs then sampling %.1fs" % [_warmup, _duration])


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--seconds" and i + 1 < args.size():
			_duration = float(args[i + 1])
		elif args[i] == "--warmup" and i + 1 < args.size():
			_warmup = float(args[i + 1])


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
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.08, 0.12)
	env.fog_density = 0.008
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var moon := DirectionalLight3D.new()
	moon.light_color = Palette.MOON
	moon.light_energy = 0.85
	moon.rotation_degrees = Vector3(-42, -25, 0)
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_max_distance = 110.0
	add_child(moon)


func _fill_horde() -> void:
	var guard := 0
	while director.alive_count() < Game.tuning.zombie_cap and guard < 500:
		director._spawn_one()
		guard += 1


## The horde spawns on the village edge, which leaves most of it outside the
## camera frustum and understates the renderer cost. Stage it in a semicircle
## in front of the player so draw calls and triangles reflect 200 visible bodies.
func _stage_horde() -> void:
	var radius_min := 8.0
	var radius_max := 40.0
	var count := director.zombies.size()
	for i in range(count):
		var zombie: Zombie = director.zombies[i]
		if zombie == null or not is_instance_valid(zombie) or not zombie.alive:
			continue
		var angle := lerpf(-0.9, 0.9, fmod(float(i) * 0.61803398875, 1.0))
		var radius := sqrt(
			lerpf(
				radius_min * radius_min, radius_max * radius_max, fmod(float(i) * 0.7548776662, 1.0)
			)
		)
		var offset := Vector3(sin(angle) * radius, 0.05, -cos(angle) * radius)
		zombie.global_position = player.global_position + offset
		zombie.rotation.y = atan2(-offset.x, -offset.z)
		# The flame is part of the load, but kills are not: without this the
		# visible horde burns down and replacements spawn at the far edges,
		# which turns a render benchmark into a spawn-rate benchmark.
		zombie.max_hp = 1.0e9
		zombie.hp = 1.0e9
		# Hold the staged ring: a walking horde collapses onto the player in a
		# few seconds and turns the sample into a close-up of a dozen bodies.
		zombie.speed = 0.0


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	if not _sampling:
		if _elapsed >= _warmup:
			_sampling = true
			_elapsed = 0.0
		_keep_horde()
		return
	_capture_sample(delta)
	if not _screenshot_taken and not Game.headless and _elapsed > 1.0:
		_screenshot_taken = true
		_capture_screenshot()
	_keep_horde()
	if _elapsed >= _duration:
		_done = true
		_write_report()
		get_tree().quit(0)


func _keep_horde() -> void:
	var guard := 0
	while director.alive_count() < Game.tuning.zombie_cap and guard < 8:
		director._spawn_one()
		guard += 1
	# The harness measures the tank, not the fuel economy.
	player.flamethrower.fuel = Game.tuning.fuel_capacity
	player.flamethrower.firing = true


func _capture_sample(delta: float) -> void:
	_frame_ms.append(delta * 1000.0)
	_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_triangles.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 3.0)
	_process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_gpu_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 0.0)


func _capture_screenshot() -> void:
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("res://docs/evidence/perf_frame.png")


func _percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(int(round((sorted.size() - 1) * fraction)), 0, sorted.size() - 1)
	return sorted[index]


func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


func _write_report() -> void:
	var report := {
		"timestamp": Time.get_datetime_string_from_system(true),
		"engine": Engine.get_version_info()["string"],
		"gpu": RenderingServer.get_video_adapter_name(),
		"cpu": OS.get_processor_name(),
		"headless": Game.headless,
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"vsync_disabled": not Game.headless,
		"duration_s": _duration,
		"samples": _frame_ms.size(),
		"zombies_target": Game.tuning.zombie_cap,
		"zombies_end": director.alive_count(),
		"frame_ms":
		{
			"p50": _percentile(_frame_ms, 0.5),
			"p95": _percentile(_frame_ms, 0.95),
			"p99": _percentile(_frame_ms, 0.99),
			"avg": _average(_frame_ms),
		},
		"fps_p50": 1000.0 / maxf(0.1, _percentile(_frame_ms, 0.5)),
		"process_ms": {"p50": _percentile(_process_ms, 0.5), "p95": _percentile(_process_ms, 0.95)},
		"draw_calls":
		{
			"p50": _percentile(_draw_calls, 0.5),
			"p95": _percentile(_draw_calls, 0.95),
			"max": _maximum(_draw_calls),
		},
		"triangles": {"p50": _percentile(_triangles, 0.5), "max": _maximum(_triangles)},
		"vram_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0),
		"budget": {"frame_p95_ms": 16.6, "draw_calls": 800, "triangles": 1500000, "vram_mb": 2500},
	}
	report["within_budget"] = {
		"frame_p95": float(report["frame_ms"]["p95"]) <= 16.6,
		"draw_calls": float(report["draw_calls"]["p95"]) <= 800.0,
		"triangles": float(report["triangles"]["p50"]) <= 1500000.0,
		"vram": float(report["vram_mb"]) <= 2500.0,
	}
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	var user_copy := FileAccess.open("user://perf.json", FileAccess.WRITE)
	if user_copy != null:
		user_copy.store_string(JSON.stringify(report, "\t"))
		user_copy.close()
	print(
		"[PERF] ",
		JSON.stringify(report["frame_ms"]),
		" draw ",
		JSON.stringify(report["draw_calls"]),
		" tris p50 ",
		report["triangles"]["p50"],
		" vram ",
		report["vram_mb"],
		" MB"
	)
	print("[PERF] within budget: ", JSON.stringify(report["within_budget"]))


func _maximum(values: Array[float]) -> float:
	var best := 0.0
	for value: float in values:
		best = maxf(best, value)
	return best
