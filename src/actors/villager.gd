class_name Villager
extends CharacterBody3D
## Villager with a utility brain: works by day, sprints home at dusk, hides
## inside, and panics when a door fails. Stuck time is instrumented because a
## villager wedged on a wall looks like a bug even when the night is fine.

signal died(villager: Villager)

enum State { IDLE, TO_WORK, WORK, TO_HOME, HIDDEN, FLEE, DEAD }

const WALK_SPEED := 1.25
const PANIC_SPEED := 3.6
const THREAT_RADIUS := 22.0
const STUCK_LIMIT := 5.0
const VISUAL_KINDS := ["villager_a", "villager_b", "villager_c", "villager_d"]

var display_name := "Villager"
var home: House
var shelter: House
var job_kind := "wood"
var job_position := Vector3.ZERO
var state: int = State.IDLE
var hidden := false
var dead := false
var stuck_time := 0.0
var stuck_events := 0
var threat := 0.0
var decisions := 0

var village: Village
var director: NightDirector

var _body: CharacterVisual
var _shape: CollisionShape3D
var _think_timer := 0.0
var _stuck_timer := 0.0
var _last_position := Vector3.ZERO
var _work_timer := 0.0
var _target := Vector3.ZERO
var _gait := 0.0
var _sidestep_time := 0.0
var _sidestep := 1.0


func _ready() -> void:
	_body = get_node_or_null("Body") as CharacterVisual
	_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	_last_position = global_position


func setup(
	label: String,
	home_house: House,
	spot: Dictionary,
	world: Village,
	director_node: NightDirector,
	tint: int
) -> void:
	display_name = label
	home = home_house
	village = world
	director = director_node
	job_kind = str(spot.get("kind", "wood"))
	job_position = spot.get("position", Vector3.ZERO)
	if director != null:
		director.register_villager(self)
	_build_visual(tint)
	state = State.WORK


func _build_visual(tint: int) -> void:
	if _body == null:
		return
	var kind: String = VISUAL_KINDS[posmod(tint, VISUAL_KINDS.size())]
	_body.setup(kind, "villager")
	collision_layer = 8
	collision_mask = 1 | 16


func is_hidden() -> bool:
	return hidden


func is_dead() -> bool:
	return dead


func kill(_reason: String) -> void:
	if dead:
		return
	dead = true
	state = State.DEAD
	velocity = Vector3.ZERO
	if hidden and home != null:
		home.release(self)
	if shelter != null and shelter != home:
		shelter.release(self)
	hidden = false
	EventBus.villager_died.emit(display_name)
	Game.add_stat("villagers_lost", 1)
	died.emit(self)
	if _body != null:
		_body.play_state("death", 0.08, 1.0, true)
	collision_layer = 0
	collision_mask = 0
	if _shape != null:
		_shape.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if dead:
		if _body != null:
			_body.tick(delta, 0)
		return
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = 0.5
		_think()
	if hidden:
		_tick_hidden(delta)
		return
	_move(delta)
	_tick_stuck(delta)
	animate_gait(delta)


func animate_gait(delta: float) -> void:
	if _body == null:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	var animation := "idle"
	if state == State.WORK:
		animation = "work"
	elif speed > 2.0:
		animation = "run"
	elif speed > 0.15:
		animation = "walk"
	_body.play_state(animation, 0.18, clampf(speed / WALK_SPEED, 0.7, 1.4))
	if speed > 0.15:
		var target_yaw := atan2(velocity.x, velocity.z) - rotation.y
		_body.rotation.y = lerp_angle(_body.rotation.y, target_yaw, 1.0 - exp(-delta / 0.16))
	elif state == State.WORK:
		var to_work := job_position - global_position
		if to_work.length_squared() > 0.04:
			var work_yaw := atan2(to_work.x, to_work.z) - rotation.y
			_body.rotation.y = lerp_angle(_body.rotation.y, work_yaw, 1.0 - exp(-delta / 0.25))
	_body.tick(delta, 0)


func _think() -> void:
	if dead:
		return
	var phase := GameClock.phase
	var shelter_window := phase != GameClock.Phase.DAY
	if hidden:
		if phase == GameClock.Phase.DAY:
			_leave_house("dawn")
		elif _current_shelter() != null and _current_shelter().door_broken():
			_leave_house("door breached")
		return
	threat = (
		float(director.threat_near(global_position, THREAT_RADIUS)) if director != null else 0.0
	)
	var home_ok := home != null and home.door != null and not home.door_broken()
	var home_target := _approach_point(home)
	var home_distance := global_position.distance_to(home_target)
	var work_distance := global_position.distance_to(job_position)
	var flee_house := _best_intact_house()
	var flee_distance := global_position.distance_to(_approach_point(flee_house))
	var action := UtilityBrain.choose(
		threat,
		shelter_window,
		1.0,
		home_distance,
		work_distance,
		flee_distance,
		home_ok,
		flee_house != null and flee_house != home
	)
	decisions += 1
	match action:
		0:
			state = State.TO_HOME
			_target = home_target
		2:
			state = State.FLEE
			shelter = flee_house
			_target = _approach_point(flee_house)
		_:
			if state != State.WORK:
				state = State.TO_WORK
				_target = job_position
	if state == State.WORK and _work_timer <= 0.0:
		_work_timer = randf_range(6.0, 12.0)
		state = State.TO_WORK
		_target = job_position


func _tick_hidden(delta: float) -> void:
	state = State.HIDDEN
	_work_timer = maxf(0.0, _work_timer - delta)


func _move(delta: float) -> void:
	if state == State.WORK or state == State.IDLE:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		_work_timer = maxf(0.0, _work_timer - delta)
		if _work_timer <= 0.0:
			_think()
		_apply_gravity(delta)
		move_and_slide()
		return
	var to_target := _target - global_position
	to_target.y = 0.0
	if to_target.length() < 1.3:
		_arrive()
		_apply_gravity(delta)
		move_and_slide()
		return
	var direction := to_target.normalized()
	direction = _avoid_obstacles(direction, delta)
	var speed := WALK_SPEED
	if state == State.FLEE:
		speed = PANIC_SPEED
	elif state == State.TO_HOME and GameClock.phase == GameClock.Phase.DUSK:
		speed = PANIC_SPEED
	velocity.x = move_toward(velocity.x, direction.x * speed, 12.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 12.0 * delta)
	_apply_gravity(delta)
	move_and_slide()


func _avoid_obstacles(direction: Vector3, delta: float) -> Vector3:
	if _sidestep_time > 0.0:
		_sidestep_time -= delta
		return direction.rotated(Vector3.UP, _sidestep * 0.85)
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3.UP * 0.9
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 1.4, 1)
	query.exclude = [get_rid()]
	if not space.intersect_ray(query).is_empty():
		_sidestep_time = 0.7
		_sidestep = 1.0 if randf() < 0.5 else -1.0
		return direction.rotated(Vector3.UP, _sidestep * 0.85)
	return direction


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= Game.tuning.gravity * delta


func _arrive() -> void:
	match state:
		State.TO_HOME:
			if home != null and not home.door_broken():
				_enter_house(home)
			else:
				state = State.FLEE
				shelter = _best_intact_house()
				if shelter != null:
					_target = _approach_point(shelter)
		State.FLEE:
			if shelter != null and not shelter.door_broken():
				_enter_house(shelter)
			else:
				state = State.IDLE
		State.TO_WORK:
			state = State.WORK
			_work_timer = randf_range(6.0, 12.0)


func _enter_house(house: House) -> void:
	if house == null or house.door_broken():
		return
	if house.occupants.size() >= 6:
		state = State.FLEE
		shelter = _best_intact_house()
		return
	hidden = true
	state = State.HIDDEN
	velocity = Vector3.ZERO
	house.occupy(self)
	global_position = house.interior_center
	collision_layer = 0
	collision_mask = 0
	if _shape != null:
		_shape.set_deferred("disabled", true)
	if _body != null:
		_body.visible = false


func _leave_house(reason: String) -> void:
	var house := _current_shelter()
	if house != null:
		house.release(self)
		var door := house.door
		if door != null:
			var outward := door.global_position - house.interior_center
			outward.y = 0.0
			if outward.length() < 0.01:
				outward = Vector3.BACK
			global_position = door.global_position + outward.normalized() * 1.8
	hidden = false
	state = State.IDLE
	collision_layer = 8
	collision_mask = 1 | 16
	if _shape != null:
		_shape.set_deferred("disabled", false)
	if _body != null:
		_body.visible = true
	_last_position = global_position
	if reason == "door breached":
		_sidestep_time = 1.2
		_sidestep = 1.0


func _current_shelter() -> House:
	if shelter != null and hidden:
		return shelter
	return home


func _approach_point(house: House) -> Vector3:
	if house == null:
		return global_position
	if house.door != null and not house.door_broken():
		var outward := house.door.global_position - house.interior_center
		outward.y = 0.0
		if outward.length() < 0.01:
			return house.door.global_position
		return house.door.global_position + outward.normalized() * 1.5
	return house.interior_center


func _best_intact_house() -> House:
	var best: House = null
	var best_distance := INF
	for house: House in village.houses:
		if house == home or house.door_broken():
			continue
		if house.occupants.size() >= 6:
			continue
		var distance := house.interior_center.distance_squared_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = house
	return best


func _tick_stuck(delta: float) -> void:
	_stuck_timer += delta
	if _stuck_timer < 1.0:
		return
	_stuck_timer = 0.0
	var moved := global_position.distance_to(_last_position)
	_last_position = global_position
	var walking := state == State.TO_HOME or state == State.TO_WORK or state == State.FLEE
	if not walking or moved >= 0.25:
		stuck_time = 0.0
		return
	stuck_time += 1.0
	if stuck_time < STUCK_LIMIT:
		return
	stuck_time = 0.0
	stuck_events += 1
	EventBus.villager_stuck.emit(display_name)
	_unstick()


func _unstick() -> void:
	var space := get_world_3d().direct_space_state
	for radius: float in [1.8, 3.0, 4.5]:
		for i in range(8):
			var angle := TAU * float(i) / 8.0
			var candidate: Vector3 = global_position + Vector3(cos(angle), 0, sin(angle)) * radius
			if village != null and village.flow.is_blocked_at(candidate):
				continue
			var query := PhysicsRayQueryParameters3D.create(
				candidate + Vector3.UP * 2.0, candidate + Vector3.DOWN * 2.0, 1
			)
			if space.intersect_ray(query).is_empty():
				continue
			global_position = candidate
			_last_position = candidate
			return
