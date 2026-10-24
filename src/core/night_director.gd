class_name NightDirector
extends Node3D
## Owns the horde: wave budget, spawn pacing, the alive cap, the spatial hash
## used for separation and threat queries, and the flow-field refresh.

const ZOMBIE_SCENE := preload("res://scenes/actors/zombie.tscn")
const HASH_CELL := 2.6
const MAX_SPAWNS_PER_FRAME := 8

var village: Village
var player: Player
var zombies: Array[Zombie] = []
var villagers: Array[Villager] = []
var rng := RandomNumberGenerator.new()
var active := false
var night := 0
var spawned_total := 0

var _hash: Dictionary = {}
var _pending := 0
var _pending_house := false
var _wave_times: Array[float] = []
var _wave_sizes: Array[int] = []
var _wave_index := 0
var _elapsed := 0.0


func _ready() -> void:
	rng.randomize()


func setup(world: Village, target: Player) -> void:
	village = world
	player = target


func register_villager(villager: Villager) -> void:
	if not villagers.has(villager):
		villagers.append(villager)


func start_night(night_number: int) -> void:
	night = night_number
	active = true
	_elapsed = 0.0
	_wave_index = 0
	spawned_total = 0
	_pending = 0
	_build_wave_plan(night_number)


func end_night() -> void:
	active = false
	_pending = 0
	for zombie: Zombie in zombies.duplicate():
		if is_instance_valid(zombie) and zombie.alive:
			zombie.dawn_die()
	zombies.clear()


func clear_all() -> void:
	for zombie: Zombie in zombies:
		if is_instance_valid(zombie):
			zombie.queue_free()
	zombies.clear()
	_pending = 0
	active = false


func alive_count() -> int:
	var count := 0
	for zombie: Zombie in zombies:
		if is_instance_valid(zombie) and zombie.alive:
			count += 1
	return count


func zombie_cap() -> int:
	return Game.tuning.zombie_cap


func on_zombie_died(zombie: Zombie) -> void:
	var index := zombies.find(zombie)
	if index >= 0:
		zombies.remove_at(index)


func _build_wave_plan(night_number: int) -> void:
	_wave_times.clear()
	_wave_sizes.clear()
	var tuning := Game.tuning
	var waves := tuning.waves_for_night(night_number)
	var per_wave := tuning.night_wave_size(night_number)
	var duration := tuning.night_seconds
	for i in range(waves):
		var fraction := 0.04 + 0.9 * (float(i) / float(maxi(1, waves)))
		_wave_times.append(duration * fraction)
		_wave_sizes.append(per_wave)


func _process(delta: float) -> void:
	if village == null or player == null:
		return
	_rebuild_hash()
	village.update_flow(player.global_position, delta, Game.tuning.flow_field_hz)
	if not active:
		return
	_elapsed += delta
	while _wave_index < _wave_times.size() and _elapsed >= _wave_times[_wave_index]:
		_request_wave(_wave_sizes[_wave_index])
		_wave_index += 1
	_drain_pending()


func _request_wave(count: int) -> void:
	var scaled := int(round(float(count) * Game.spawn_multiplier()))
	_pending += scaled
	EventBus.wave_spawned.emit(scaled, alive_count())


func _drain_pending() -> void:
	if _pending <= 0:
		return
	var budget := MAX_SPAWNS_PER_FRAME
	while budget > 0 and _pending > 0:
		if alive_count() >= zombie_cap():
			return
		_spawn_one()
		_pending -= 1
		budget -= 1


## Staged spawn: no wave budget and no edge spawner. The perf and capture
## harnesses place the crowd themselves so the frame reflects a visible horde.
func stage_zombie(position: Vector3, kind: int) -> Zombie:
	var zombie: Zombie = ZOMBIE_SCENE.instantiate()
	zombie.position = position
	add_child(zombie)
	zombie.setup(village, player, self, kind, Zombie.Objective.PLAYER, null)
	zombies.append(zombie)
	spawned_total += 1
	return zombie


func _spawn_one() -> void:
	var archetype := _roll_archetype()
	var house: House = null
	var objective := Zombie.Objective.PLAYER
	var raider_chance := 0.25
	if archetype == Zombie.Archetype.BRUTE:
		raider_chance = 0.8
	if rng.randf() < raider_chance and village.houses.size() > 0:
		house = village.raider_target(rng)
		objective = Zombie.Objective.HOUSE
	var zombie: Zombie = ZOMBIE_SCENE.instantiate()
	var spawn := village.spawn_position(rng)
	zombie.position = spawn
	add_child(zombie)
	zombie.setup(village, player, self, archetype, objective, house)
	zombies.append(zombie)
	spawned_total += 1
	EventBus.zombie_spawned.emit(alive_count())


func _roll_archetype() -> int:
	var tuning := Game.tuning
	if night >= tuning.brute_from_night and rng.randf() < 0.1:
		return Zombie.Archetype.BRUTE
	if night >= tuning.runner_from_night and rng.randf() < 0.35:
		return Zombie.Archetype.RUNNER
	return Zombie.Archetype.SHAMBLER


func _rebuild_hash() -> void:
	_hash.clear()
	for zombie: Zombie in zombies:
		if not is_instance_valid(zombie) or not zombie.alive:
			continue
		var key := _cell_key(zombie.global_position)
		if _hash.has(key):
			var bucket: Array = _hash[key]
			bucket.append(zombie)
		else:
			_hash[key] = [zombie]


func _cell_key(position: Vector3) -> Vector2i:
	return Vector2i(int(floor(position.x / HASH_CELL)), int(floor(position.z / HASH_CELL)))


func separation_for(zombie: Zombie) -> Vector3:
	var key := _cell_key(zombie.global_position)
	var push := Vector3.ZERO
	var counted := 0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var bucket: Array = _hash.get(key + Vector2i(dx, dz), [])
			for other: Zombie in bucket:
				if other == zombie or not is_instance_valid(other) or not other.alive:
					continue
				var away := zombie.global_position - other.global_position
				away.y = 0.0
				var distance := away.length()
				if distance < 0.01:
					away = Vector3(1, 0, 0)
					distance = 0.01
				if distance < 1.25:
					push += away.normalized() * (1.25 - distance)
					counted += 1
					if counted >= 6:
						return push
	return push


func threat_near(position: Vector3, radius: float) -> int:
	if _hash.is_empty():
		return 0
	var cells := int(ceil(radius / HASH_CELL))
	var key := _cell_key(position)
	var radius_sq := radius * radius
	var count := 0
	for dz in range(-cells, cells + 1):
		for dx in range(-cells, cells + 1):
			var bucket: Array = _hash.get(key + Vector2i(dx, dz), [])
			for zombie: Zombie in bucket:
				if not is_instance_valid(zombie) or not zombie.alive:
					continue
				if zombie.global_position.distance_squared_to(position) <= radius_sq:
					count += 1
	return count


func nearest_villager(position: Vector3, radius: float) -> Villager:
	var best: Villager = null
	var best_distance := radius * radius
	for villager: Villager in villagers:
		if not is_instance_valid(villager) or villager.is_hidden() or villager.is_dead():
			continue
		var distance := villager.global_position.distance_squared_to(position)
		if distance < best_distance:
			best_distance = distance
			best = villager
	return best


func nearest_zombie(position: Vector3, radius: float) -> Zombie:
	var cells := int(ceil(radius / HASH_CELL))
	var key := _cell_key(position)
	var best: Zombie = null
	var best_distance := radius * radius
	for dz in range(-cells, cells + 1):
		for dx in range(-cells, cells + 1):
			var bucket: Array = _hash.get(key + Vector2i(dx, dz), [])
			for zombie: Zombie in bucket:
				if not is_instance_valid(zombie) or not zombie.alive:
					continue
				var distance := zombie.global_position.distance_squared_to(position)
				if distance < best_distance:
					best_distance = distance
					best = zombie
	return best
