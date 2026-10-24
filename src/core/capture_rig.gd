class_name CaptureRig
extends Node
## Scripted first-contact clip for Godot's Movie Maker mode.
##
## Run through `tools/capture.sh`, which passes `--write-movie`, `--fixed-fps`
## and `--capture`. The rig stages a crowd in the player's view, ignites it on
## camera, and quits when the scripted duration ends so the movie file is
## finalised. It writes `capture.json` beside `perf.json` for provenance.
##
## This is evidence tooling, not gameplay: the film is produced from the real
## game loop, but the crowd is staged and the player cannot die during the take.

const CROWD_SIZE := 40
const SUMMARY_PATH := "res://capture.json"
const SEED := 20251025
## A full tank is 16.6 s of fire, so a 60 s take would go dark after a quarter of
## the clip. The rig tops the tank up at the burn rate minus FUEL_NET_DRAIN, so
## the gauge drains slowly for the whole take instead of emptying at 17 s.
const FUEL_NET_DRAIN := 1.5
## Top-ups are applied once they reach this many units of fuel, which keeps the
## HUD from publishing every frame without changing the rate.
const FUEL_STEP := 0.5
## Lane slots in front of the player: x is lateral, y is forward distance.
## One body per slot, so burning targets never stack on the same point.
const CONTACT_SLOTS := [Vector2(-1.6, 4.4), Vector2(-0.1, 4.9), Vector2(1.4, 4.5)]

var player: Player
var director: NightDirector
var village: Village
var duration := 8.0

var _elapsed := 0.0
var _frames := 0
var _contact_timer := 0.0
var _top_up_timer := 0.0
var _fuel_credit := 0.0
var _firing := false
var _rng := RandomNumberGenerator.new()
var _kills_at_start := 0.0
var _camera: Camera3D
var _cam_from := Vector3.ZERO
var _cam_to := Vector3.ZERO
var _look_from := Vector3.ZERO
var _look_to := Vector3.ZERO
var _slot_holders: Array[Zombie] = []


func setup(target: Player, horde: NightDirector, world: Village, seconds: float) -> void:
	player = target
	director = horde
	village = world
	duration = maxf(2.0, seconds)
	_rng.seed = SEED
	director.rng.seed = SEED
	_kills_at_start = Game.stat("kills")
	_slot_holders.resize(CONTACT_SLOTS.size())
	_build_crowd()
	_build_camera()
	Input.action_press("aim")
	print(
		(
			"[CAPTURE] staged %d zombies for %.1fs; aim held, fire starts at 0.8s"
			% [director.alive_count(), duration]
		)
	)


## One frame of the staged top-up. Returns `[credit, amount]`: fuel is only added
## once the credit reaches `FUEL_STEP`, but the credit carries over, so the
## average stays at `burn_rate - net_drain` whatever the frame time. A fixed-fps
## render quantised a fixed-interval drip down to 4.05 fuel/s and ran the tank
## dry at 51 s of a 60 s take.
static func fuel_step(delta: float, credit: float, burn_rate: float, net_drain: float) -> Array:
	credit += maxf(0.0, burn_rate - net_drain) * delta
	if credit < FUEL_STEP:
		return [credit, 0.0]
	return [0.0, credit]


func _process(delta: float) -> void:
	_elapsed += delta
	_frames += 1
	if not _firing and _elapsed >= 0.8:
		_firing = true
		Input.action_press("fire")
	if _firing and _elapsed >= maxf(1.0, duration - 1.8):
		_firing = false
		Input.action_release("fire")
	_drift_camera()
	_contact_timer -= delta
	if _firing and _contact_timer <= 0.0:
		_contact_timer = 0.25
		_fill_slots()
	_top_up_timer -= delta
	if _top_up_timer <= 0.0:
		_top_up_timer = 0.5
		_top_up_crowd()
	if _firing:
		var step := fuel_step(delta, _fuel_credit, Game.tuning.burn_rate_per_second, FUEL_NET_DRAIN)
		_fuel_credit = step[0]
		if step[1] > 0.0:
			player.flamethrower.add_fuel(step[1])
	if _elapsed >= duration:
		_finish()


func _build_crowd() -> void:
	for index in range(CROWD_SIZE):
		var kind := Zombie.Archetype.SHAMBLER
		if index % 9 == 4:
			kind = Zombie.Archetype.RUNNER
		elif index % 13 == 7:
			kind = Zombie.Archetype.BRUTE
		_stage(_crowd_position(), kind)


## Bodies are held in place: a walking crowd reaches the player in six seconds
## and fills the lens. The take is a composition, not a playthrough.
func _stage(point: Vector3, kind: int) -> void:
	var zombie := director.stage_zombie(point, kind)
	zombie.hold_at(point)


## Wedge in front of the player: the camera looks down -Z, so this is the area
## the clip actually sees. A square root spends more bodies near the lens.
func _crowd_position() -> Vector3:
	var angle := _rng.randf_range(-0.62, 0.62)
	var distance := lerpf(9.0, 26.0, sqrt(_rng.randf()))
	var offset := Vector3(sin(angle) * distance, 0.05, -cos(angle) * distance)
	return player.global_position + offset


## A side camera, not the player's: firing straight away from an over-the-
## shoulder lens foreshortens the plume into a blob. From the right flank the
## stream crosses the frame and the burning front stays readable.
func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "CaptureCamera"
	_camera.fov = 52.0
	add_child(_camera)
	_cam_from = player.global_position + Vector3(4.4, 2.3, 1.4)
	_cam_to = player.global_position + Vector3(4.8, 2.4, 2.8)
	_look_from = player.global_position + Vector3(0.0, 1.0, -4.2)
	_look_to = player.global_position + Vector3(0.0, 1.1, -3.6)
	_camera.global_position = _cam_from
	_camera.look_at(_look_from, Vector3.UP)
	_camera.current = true


## A fixed camera for a minute reads as a still. This eases back a metre and a
## half so the player keeps his third of the frame while the contact zone grows.
func _drift_camera() -> void:
	if _camera == null:
		return
	var t := clampf(_elapsed / duration, 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	_camera.global_position = _cam_from.lerp(_cam_to, eased)
	_camera.look_at(_look_from.lerp(_look_to, eased), Vector3.UP)


## The camera sits behind the player and the flame reaches 8 m from the lens,
## so a slot is 4.4-4.9 m in front of the player. Shamblers only: a brute would
## outlive the take. A body stays in its slot until it dies.
func _fill_slots() -> void:
	for index in range(CONTACT_SLOTS.size()):
		var holder := _slot_holders[index]
		if is_instance_valid(holder) and holder.alive:
			continue
		_slot_holders[index] = _pull_one(index)


func _pull_one(slot: int) -> Zombie:
	var spot: Vector2 = CONTACT_SLOTS[slot]
	var point := player.global_position + Vector3(spot.x, 0.05, -spot.y)
	for zombie: Zombie in director.zombies.duplicate():
		if not is_instance_valid(zombie) or not zombie.alive:
			continue
		if zombie.archetype != Zombie.Archetype.SHAMBLER or zombie.is_burning():
			continue
		if _slot_holders.has(zombie):
			continue
		if zombie.global_position.distance_to(player.global_position) < 8.0:
			continue
		zombie.hold_at(point)
		return zombie
	return null


func _top_up_crowd() -> void:
	var guard := 0
	while director.alive_count() < CROWD_SIZE and guard < 4:
		_stage(_crowd_position(), Zombie.Archetype.SHAMBLER)
		guard += 1


func _finish() -> void:
	Input.action_release("fire")
	Input.action_release("aim")
	var slot_hp := []
	for holder in _slot_holders:
		# A holder that has died or been freed counts as spent.
		slot_hp.append(roundf(holder.hp) if (is_instance_valid(holder) and holder.alive) else 0.0)
	var report := {
		"timestamp": Time.get_datetime_string_from_system(true),
		"engine": Engine.get_version_info()["string"],
		"gpu": RenderingServer.get_video_adapter_name(),
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"seconds": duration,
		"frames": _frames,
		"zombies_alive": director.alive_count(),
		"kills_during_capture": int(Game.stat("kills") - _kills_at_start),
		"kills_total": Game.stat("kills"),
		"slot_hp": slot_hp,
		"staged": true,
		"player_invulnerable": true,
		"fuel_top_up_rate": Game.tuning.burn_rate_per_second - FUEL_NET_DRAIN,
		"fuel_net_drain": FUEL_NET_DRAIN,
		"fuel_end": roundf(player.flamethrower.fuel),
	}
	var file := FileAccess.open(SUMMARY_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("[CAPTURE] ", JSON.stringify(report))
	get_tree().quit(0)
