class_name Zombie
extends CharacterBody3D
## One horde member. Shared mesh and material, throttled LOD, flow-field pathing
## for the player objective, direct steering for house raiders.

signal died(zombie: Zombie)

enum Archetype { SHAMBLER, RUNNER, BRUTE }
enum Objective { PLAYER, HOUSE }

var archetype: int = Archetype.SHAMBLER
var objective: int = Objective.PLAYER
var hp := 100.0
var max_hp := 100.0
var speed := 1.4
var alive := true
var player: Player
var village: Village
var director: NightDirector
var target_house: House
var home_spawn := Vector3.ZERO

var _body: CharacterVisual
var _shape: CollisionShape3D
var _burn_time := 0.0
var _burn_accumulator := 0.0
var _attack_cooldown := 0.0
var _lunge_time := 0.0
var _lunge_cooldown := 0.0
var _flinch := 0.0
var _attack_anim := 0.0
var _attacking_door := false
var _update_every := 1
var _frame_offset := 0
var _anim_lod := 0
var _stuck_time := 0.0
var _last_position := Vector3.ZERO
var _separation_seed := 0.0


func _ready() -> void:
	_body = get_node_or_null("Body") as CharacterVisual
	_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	_last_position = global_position
	_separation_seed = randf() * TAU
	_anim_lod = 0


func setup(
	world: Village,
	target_player: Player,
	director_node: NightDirector,
	kind: int,
	spawn_objective: int,
	house: House
) -> void:
	village = world
	player = target_player
	director = director_node
	archetype = kind
	objective = spawn_objective
	target_house = house
	home_spawn = global_position
	_apply_archetype()
	_frame_offset = randi() % 4
	_update_every = 1
	_last_position = global_position


func _apply_archetype() -> void:
	var tuning := Game.tuning
	var visual_kind := "shambler"
	var tint := Color(0.92, 1.0, 0.9)
	match archetype:
		Archetype.RUNNER:
			hp = tuning.runner_hp
			speed = tuning.runner_speed
			visual_kind = "runner"
			tint = Color(0.88, 0.94, 1.0)
		Archetype.BRUTE:
			hp = tuning.brute_hp
			speed = tuning.brute_speed
			visual_kind = "brute"
			tint = Color(1.0, 0.88, 0.82)
			if _shape != null:
				_shape.shape = _shape.shape.duplicate()
				var capsule := _shape.shape as CapsuleShape3D
				if capsule != null:
					capsule.radius = 0.55
					capsule.height = 2.2
				_shape.position.y = 1.1
		_:
			hp = tuning.zombie_hp
			speed = tuning.zombie_speed
	if _body != null:
		_body.setup(visual_kind, visual_kind, tint)
		var roll := director.rng.randf() if director != null else 0.5
		var spread := tuning.gait_variation
		if archetype == Archetype.RUNNER:
			spread *= 1.3
		elif archetype == Archetype.BRUTE:
			spread *= 0.6
		_body.set_gait(Feedback.gait_scale(roll, spread), roll)
	max_hp = hp


func is_burning() -> bool:
	return _burn_time > 0.0


func apply_burn(seconds: float) -> void:
	if not alive:
		return
	_burn_time = maxf(_burn_time, seconds)
	if _body != null:
		_body.set_burning(true)


func take_damage(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	hp -= amount
	_flinch = 0.18
	if hp <= 0.0:
		_die()


func dawn_die() -> void:
	if not alive:
		return
	_burn_time = 2.0
	if _body != null:
		_body.set_burning(true)
	_die()


func _die() -> void:
	if not alive:
		return
	alive = false
	collision_layer = 0
	collision_mask = 0
	if _shape != null:
		_shape.set_deferred("disabled", true)
	EventBus.zombie_died.emit(global_position, archetype)
	Game.add_stat("kills", 1)
	if director != null:
		director.on_zombie_died(self)
	died.emit(self)
	if _body != null:
		_body.play_state("death", 0.08, 1.0, true)
		var tween := create_tween()
		tween.tween_interval(0.55)
		tween.tween_property(_body, "scale", Vector3(1.35, 0.04, 1.35), 0.3)
		tween.parallel().tween_property(_body, "position:y", _body.position.y - 0.08, 0.3)
		tween.tween_callback(queue_free)
	else:
		queue_free()


func _physics_process(delta: float) -> void:
	if not alive:
		if _body != null:
			_body.tick(delta, 0)
		return
	if player == null or village == null:
		return
	_update_lod()
	if _body != null:
		_body.tick(delta, _anim_lod)
	if _update_every > 1 and (Engine.get_physics_frames() + _frame_offset) % _update_every != 0:
		return
	var dt := delta * _update_every
	_tick_effects(dt)
	if not alive:
		return
	_steer(dt)
	move_and_slide()
	_attack(dt)
	_animate(dt)


func _update_lod() -> void:
	var distance := global_position.distance_to(player.global_position)
	if distance < 15.0:
		_anim_lod = 0
		_update_every = 1
	elif distance < 35.0:
		_anim_lod = 1
		_update_every = 2
	else:
		_anim_lod = 2
		_update_every = 4
	if _body != null:
		_body.visible = distance < 80.0


func _tick_effects(dt: float) -> void:
	if _attack_cooldown > 0.0:
		_attack_cooldown -= dt
	if _lunge_cooldown > 0.0:
		_lunge_cooldown -= dt
	if _lunge_time > 0.0:
		_lunge_time -= dt
	if _flinch > 0.0:
		_flinch -= dt
	if _attack_anim > 0.0:
		_attack_anim -= dt
		if _attack_anim <= 0.0:
			_attacking_door = false
	if is_burning():
		_burn_time -= dt
		_burn_accumulator += dt
		var tick := 0.5
		while _burn_accumulator >= tick:
			_burn_accumulator -= tick
			hp -= Game.tuning.flame_burn_dps * tick
			if hp <= 0.0:
				_die()
				return
	else:
		_burn_accumulator = 0.0
		if _body != null:
			_body.set_burning(false)


func _steer(dt: float) -> void:
	var desired := Vector3.ZERO
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var player_distance := to_player.length()
	if objective == Objective.HOUSE and target_house != null and not target_house.door_broken():
		var door := target_house.door
		if door != null:
			var to_door := door.global_position - global_position
			to_door.y = 0.0
			desired = to_door.normalized()
			if to_door.length() < 2.2:
				_attack_door(dt, door)
				desired = Vector3.ZERO
			if target_house.is_inside(global_position):
				objective = Objective.PLAYER
	else:
		objective = Objective.PLAYER
		if player_distance > 0.01:
			desired = village.flow_direction(global_position)
			if player_distance < 14.0:
				desired = (desired * 0.35 + to_player.normalized() * 0.65).normalized()
	if desired == Vector3.ZERO:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * dt)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * dt)
	else:
		var separation := director.separation_for(self) if director != null else Vector3.ZERO
		desired = (desired + separation * 0.85).normalized()
		var current_speed := speed
		if _lunge_time > 0.0:
			current_speed = Game.tuning.zombie_lunge_speed
		elif player_distance < Game.tuning.zombie_lunge_range and _lunge_cooldown <= 0.0:
			if archetype != Archetype.BRUTE:
				_lunge_time = Game.tuning.zombie_lunge_seconds
				_lunge_cooldown = Game.tuning.zombie_lunge_cooldown
				current_speed = Game.tuning.zombie_lunge_speed
		if _flinch > 0.0:
			current_speed *= 0.2
		velocity.x = move_toward(velocity.x, desired.x * current_speed, 10.0 * dt)
		velocity.z = move_toward(velocity.z, desired.z * current_speed, 10.0 * dt)
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= Game.tuning.gravity * dt
	_check_stuck(dt)


func _attack(dt: float) -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() <= Game.tuning.zombie_attack_range and _attack_cooldown <= 0.0:
		_attack_cooldown = 1.0
		_attack_anim = 0.5
		_attacking_door = false
		player.take_damage(Game.tuning.zombie_attack_dps)
		return
	var victim := director.nearest_villager(global_position, 1.4) if director != null else null
	if victim != null and _attack_cooldown <= 0.0:
		_attack_cooldown = 1.0
		_attack_anim = 0.5
		_attacking_door = false
		victim.kill("zombie")
		return
	if objective == Objective.PLAYER:
		var door := village.nearest_door(global_position, 2.1)
		if door != null:
			_attack_door(dt, door)


func _attack_door(_dt: float, door: Door) -> void:
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown = 1.0
	_attack_anim = 0.5
	_attacking_door = true
	var damage := Game.tuning.zombie_door_dps
	if archetype == Archetype.BRUTE:
		damage *= Game.tuning.brute_door_multiplier
	door.take_damage(damage)


func _check_stuck(dt: float) -> void:
	var moved := global_position.distance_to(_last_position)
	_last_position = global_position
	if moved > 0.02:
		_stuck_time = maxf(0.0, _stuck_time - dt * 2.0)
	else:
		_stuck_time += dt
	if _stuck_time > 3.0:
		_stuck_time = 0.0
		var away := global_position - player.global_position
		away.y = 0.0
		if away.length() < 0.1:
			away = Vector3(0, 0, 1)
		var candidate: Vector3 = global_position + away.normalized() * 1.6
		if village != null and not village.flow.is_blocked_at(candidate):
			global_position = candidate


func _animate(dt: float) -> void:
	if _body == null:
		return
	var horizontal := Vector2(velocity.x, velocity.z).length()
	var state := "idle"
	if _attack_anim > 0.0:
		state = "door" if _attacking_door else "attack"
	elif _lunge_time > 0.0:
		state = "lunge"
	elif _flinch > 0.0:
		state = "hit"
	elif horizontal > 0.2:
		state = "run" if archetype == Archetype.RUNNER else "walk"
	var playback := clampf(horizontal / maxf(0.1, speed), 0.65, 1.35)
	if state == "idle":
		playback = Feedback.breath_speed(Time.get_ticks_msec(), _body.gait_phase, Game.tuning)
	_body.play_state(state, 0.18, playback)
	var look := Vector3.ZERO
	if horizontal > 0.2:
		look = Vector3(velocity.x, 0.0, velocity.z)
	elif objective == Objective.HOUSE and target_house != null and target_house.door != null:
		look = target_house.door.global_position - global_position
	elif player != null:
		look = player.global_position - global_position
	if look.length_squared() > 0.04:
		var target_yaw := atan2(look.x, look.z) - rotation.y
		_body.rotation.y = lerp_angle(_body.rotation.y, target_yaw, 1.0 - exp(-dt / 0.14))
