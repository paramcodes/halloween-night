class_name Player
extends CharacterBody3D
## Third-person defender: camera-relative movement, sprint stamina, aim mode,
## boarding interaction and damage. Owns the flamethrower.

var health := 100.0
var max_health := 100.0
var alive := true
var aiming := false
var controls_enabled := true
var god_mode := false
var stamina := 5.0
var interact_progress := 0.0
var interact_text := ""
var interact_target: Door
var _last_interact_target: Door

var _yaw := 0.0
var _pitch := -0.08
var _target_yaw := 0.0
var _target_pitch := -0.08
var _coyote := 0.0
var _exhausted := false
var _shake := 0.0
var _recoil := 0.0
var _interact_cooldown := 0.0
var _hit_timer := 0.0

@onready var body_visual: CharacterVisual = $Body
@onready var pivot: Node3D = $CameraPivot
@onready var spring: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var flamethrower: Flamethrower = $Flamethrower


func _ready() -> void:
	var tuning := Game.tuning
	max_health = tuning.player_max_hp
	health = max_health
	stamina = tuning.sprint_stamina_seconds
	body_visual.setup("player")
	body_visual.rotation.y = PI
	pivot.position = Vector3(tuning.shoulder_offset, tuning.pivot_height, 0)
	spring.spring_length = tuning.boom_length
	spring.margin = 0.15
	spring.collision_mask = 1 | 16
	spring.add_excluded_object(get_rid())
	camera.fov = tuning.fov
	flamethrower.camera = camera
	flamethrower.setup(Game.fuel())
	if not Game.headless:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	flamethrower.firing = false
	if not enabled and not Game.headless:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func take_damage(amount: float) -> void:
	if not alive or amount <= 0.0 or god_mode:
		return
	health = maxf(0.0, health - amount)
	_shake = minf(
		Game.tuning.camera_shake_max_deg,
		_shake + Feedback.shake_amplitude(amount, Game.tuning),
	)
	_hit_timer = 0.22
	EventBus.player_damaged.emit(health, max_health)
	if health <= 0.0:
		alive = false
		flamethrower.firing = false
		EventBus.player_died.emit()


func heal(amount: float) -> void:
	if not alive:
		return
	health = minf(max_health, health + amount)
	EventBus.player_healed.emit(health, max_health)


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sensitivity := Game.tuning.mouse_sensitivity
		_target_yaw -= motion.relative.x * sensitivity
		_target_pitch -= motion.relative.y * sensitivity
		_target_pitch = clampf(
			_target_pitch,
			deg_to_rad(Game.tuning.pitch_min_deg),
			deg_to_rad(Game.tuning.pitch_max_deg)
		)
	elif event.is_action_pressed("bell"):
		_ring_bell()
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _ring_bell() -> void:
	if GameClock.phase != GameClock.Phase.DUSK and GameClock.phase != GameClock.Phase.NIGHT:
		EventBus.toast.emit("The bell only answers at dusk or night.")
		return
	if Game.bell_charges() <= 0:
		EventBus.toast.emit("The bell rope is slack. No charges left.")
		return
	Game.ring_bell_for_night(GameClock.night)
	EventBus.toast.emit("Bell rung: the dead come 20% thicker tonight.")


func _physics_process(delta: float) -> void:
	if not alive or not controls_enabled:
		velocity = Vector3.ZERO
		return
	var tuning := Game.tuning
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis := Basis(Vector3.UP, _yaw)
	var direction := basis * Vector3(input_dir.x, 0.0, input_dir.y)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	var wants_sprint := Input.is_action_pressed("sprint") and input_dir.length() > 0.1
	aiming = Input.is_action_pressed("aim")
	var speed := tuning.walk_speed
	if aiming:
		speed = tuning.aim_speed
	elif wants_sprint and not _exhausted and stamina > 0.0:
		speed = tuning.sprint_speed
		stamina = maxf(0.0, stamina - delta)
		if stamina <= 0.0:
			_exhausted = true
	else:
		stamina = minf(
			tuning.sprint_stamina_seconds, stamina + tuning.stamina_regen_per_second * delta
		)
		if _exhausted and stamina > tuning.sprint_stamina_seconds * 0.25:
			_exhausted = false
	var target_velocity := direction * speed
	var accel := tuning.ground_accel if is_on_floor() else tuning.air_accel
	velocity.x = move_toward(velocity.x, target_velocity.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, accel * delta)
	if is_on_floor():
		_coyote = tuning.coyote_time
		velocity.y = -0.5
	else:
		_coyote = maxf(0.0, _coyote - delta)
		velocity.y -= tuning.gravity * delta
	move_and_slide()
	_rotate_visual(direction, delta)


func _process(delta: float) -> void:
	if not alive:
		flamethrower.firing = false
		body_visual.play_state("death", 0.12)
		body_visual.tick(delta, 0)
		return
	if not controls_enabled:
		flamethrower.firing = false
		body_visual.play_state("idle")
		body_visual.tick(delta, 0)
		return
	var tuning := Game.tuning
	_yaw = lerp_angle(_yaw, _target_yaw, 1.0 - exp(-delta / maxf(0.001, tuning.rotation_smoothing)))
	_pitch = lerp(_pitch, _target_pitch, 1.0 - exp(-delta / maxf(0.001, tuning.rotation_smoothing)))
	pivot.rotation = Vector3(_pitch, _yaw, 0.0)
	var target_position := Vector3(tuning.shoulder_offset, tuning.pivot_height, 0.0)
	var pos_smoothing := 1.0 - exp(-delta / maxf(0.001, tuning.position_smoothing))
	pivot.position = pivot.position.lerp(target_position, pos_smoothing)
	var target_boom := tuning.boom_length_aim if aiming else tuning.boom_length
	spring.spring_length = lerpf(spring.spring_length, target_boom, pos_smoothing)
	var target_fov := tuning.fov_aim if aiming else tuning.fov
	camera.fov = lerpf(camera.fov, target_fov, pos_smoothing)
	flamethrower.firing = Input.is_action_pressed("fire")
	apply_feedback(delta, flamethrower.firing)
	pivot.rotation += Feedback.shake_rotation(_shake, Time.get_ticks_msec())
	pivot.rotation.x -= deg_to_rad(_recoil)
	_update_interaction(delta)
	_update_body_animation(delta)


## Camera feedback is separated from input so tests can drive it directly.
func apply_feedback(delta: float, firing: bool) -> void:
	var tuning := Game.tuning
	_recoil = Feedback.recoil_step(_recoil, firing, delta, tuning)
	_shake = Feedback.shake_step(_shake, delta, tuning)


func camera_recoil_degrees() -> float:
	return _recoil


func camera_shake_degrees() -> float:
	return _shake


func _update_interaction(delta: float) -> void:
	_interact_cooldown = maxf(0.0, _interact_cooldown - delta)
	var target := _find_door()
	if target != _last_interact_target:
		interact_progress = 0.0
	_last_interact_target = target
	interact_target = target
	interact_text = ""
	if target != null:
		interact_text = "Hold E: board door  (%d planks)" % Game.planks()
		if target.broken:
			interact_text = "Hold E: rebuild door  (2 planks)"
	if target == null or not Input.is_action_pressed("interact") or _interact_cooldown > 0.0:
		if not Input.is_action_pressed("interact"):
			interact_progress = 0.0
		return
	interact_progress += delta
	if interact_progress >= Game.tuning.boarding_seconds:
		interact_progress = 0.0
		_interact_cooldown = 0.4
		_complete_interaction(target)


func _complete_interaction(target: Door) -> void:
	if target.broken:
		if Game.planks() < 2:
			EventBus.toast.emit("Two planks to rebuild a door.")
			return
		Game.add_planks(-2)
		target.repair_full()
		EventBus.toast.emit("Door rebuilt.")
		return
	if Game.planks() <= 0:
		EventBus.toast.emit("No planks left.")
		return
	if target.hp >= target.max_hp:
		EventBus.toast.emit("That door is already sound.")
		return
	Game.add_planks(-1)
	target.board(Game.tuning.boarding_bonus)
	EventBus.toast.emit("Door boarded.")


func _find_door() -> Door:
	var space := get_world_3d().direct_space_state
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * 3.2, 16)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return null
	var collider: Object = hit.get("collider")
	if collider is Door:
		var door := collider as Door
		if door.global_position.distance_to(global_position) > 3.4:
			return null
		return door
	return null


func _rotate_visual(direction: Vector3, delta: float) -> void:
	var facing := direction
	if aiming:
		facing = Basis(Vector3.UP, _yaw) * Vector3(0.0, 0.0, -1.0)
	if facing.length_squared() < 0.02:
		return
	var target_yaw := atan2(facing.x, facing.z) - rotation.y
	body_visual.rotation.y = lerp_angle(
		body_visual.rotation.y, target_yaw, 1.0 - exp(-delta / 0.12)
	)


func _update_body_animation(delta: float) -> void:
	if _hit_timer > 0.0:
		_hit_timer = maxf(0.0, _hit_timer - delta)
		body_visual.play_state("hit", 0.08)
	elif interact_progress > 0.0 and Input.is_action_pressed("interact"):
		body_visual.play_state("interact", 0.15)
	elif flamethrower.firing:
		body_visual.play_state("fire", 0.12)
	elif aiming:
		body_visual.play_state("aim", 0.15)
	else:
		var horizontal := Vector2(velocity.x, velocity.z).length()
		if horizontal > 3.1:
			body_visual.play_state(
				"run", 0.15, clampf(horizontal / Game.tuning.sprint_speed, 0.75, 1.35)
			)
		elif horizontal > 0.2:
			body_visual.play_state(
				"walk", 0.15, clampf(horizontal / Game.tuning.walk_speed, 0.7, 1.35)
			)
		else:
			(
				body_visual
				. play_state(
					"idle",
					0.2,
					Feedback.breath_speed(
						Time.get_ticks_msec(), body_visual.gait_phase, Game.tuning
					),
				)
			)
	body_visual.tick(delta, 0)
