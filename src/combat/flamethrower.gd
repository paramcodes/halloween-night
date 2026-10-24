class_name Flamethrower
extends Node3D
## 12-ray fan at 10 Hz, cone damage, particle plume, flickering light.
##
## Damage is applied per unique target per tick, so the number of rays shapes
## the cone without multiplying damage. Direct DPS plus a burn that refreshes.

const ZOMBIE_MASK := 4
const FUEL_UI_EPSILON := 0.75

var camera: Camera3D
var firing := false
var fuel := 100.0
var fuel_capacity := 100.0
var nozzle: Node3D

var _tick_accumulator := 0.0
var _rng := RandomNumberGenerator.new()
var _particles: GPUParticles3D
var _smoke: GPUParticles3D
var _light: OmniLight3D
var _last_emitted_fuel := -1.0
var _empty_emitted := false
var _flicker := 0.0


func _ready() -> void:
	_rng.randomize()
	fuel_capacity = Game.tuning.fuel_capacity
	fuel = clampf(Game.fuel(), 0.0, fuel_capacity)
	_build_gun()
	_build_particles()
	_build_light()


func setup(start_fuel: float) -> void:
	fuel_capacity = Game.tuning.fuel_capacity
	fuel = clampf(start_fuel, 0.0, fuel_capacity)
	_publish_fuel(true)


func add_fuel(amount: float) -> void:
	fuel = clampf(fuel + amount, 0.0, fuel_capacity)
	_publish_fuel(true)


func fuel_fraction() -> float:
	if fuel_capacity <= 0.0:
		return 0.0
	return clampf(fuel / fuel_capacity, 0.0, 1.0)


func seconds_left() -> float:
	return fuel / maxf(0.1, Game.tuning.burn_rate_per_second)


func _process(delta: float) -> void:
	if camera != null:
		global_transform = camera.global_transform
		_place_gun()
	var wants_fire := firing and fuel > 0.0
	if wants_fire:
		var burn := Game.tuning.burn_rate_per_second
		fuel = maxf(0.0, fuel - burn * delta)
		Game.set_fuel(fuel)
		Game.add_stat("fuel_spent", burn * delta)
		_tick_accumulator += delta
		var interval := 1.0 / maxf(1.0, Game.tuning.flame_tick_hz)
		while _tick_accumulator >= interval:
			_tick_accumulator -= interval
			_damage_tick()
		if fuel <= 0.0 and not _empty_emitted:
			_empty_emitted = true
			firing = false
			EventBus.fuel_empty.emit()
		_publish_fuel()
	_set_emitting(wants_fire)
	_flicker_light(delta, wants_fire)


## The camera owns aiming, but the gun belongs to the defender. Without this the
## barrel would sit on the camera and fill a third-person frame.
func _place_gun() -> void:
	if nozzle == null or camera == null:
		return
	var holder := get_parent() as Node3D
	if holder == null:
		return
	var forward := -camera.global_transform.basis.z
	nozzle.global_position = holder.global_position + Vector3(0.0, 1.15, 0.0) + forward * 0.35
	nozzle.global_rotation = camera.global_rotation


func _set_emitting(on: bool) -> void:
	if _particles != null and _particles.emitting != on:
		_particles.emitting = on
	if _smoke != null and _smoke.emitting != on:
		_smoke.emitting = on
	if _light != null:
		_light.visible = on


func _publish_fuel(force := false) -> void:
	if not force and absf(fuel - _last_emitted_fuel) < FUEL_UI_EPSILON:
		return
	_last_emitted_fuel = fuel
	EventBus.fuel_changed.emit(fuel, fuel_capacity)


func _damage_tick() -> void:
	if camera == null:
		return
	var space := get_world_3d().direct_space_state
	var cam_transform := camera.global_transform
	var forward := -cam_transform.basis.z
	var origin := cam_transform.origin + forward * 0.45
	var half_angle := deg_to_rad(Game.tuning.flame_cone_degrees * 0.5)
	var rays := Game.tuning.flame_ray_count
	var interval := 1.0 / maxf(1.0, Game.tuning.flame_tick_hz)
	var hits: Dictionary = {}
	for i in range(rays):
		var dir := _ray_direction(cam_transform.basis, half_angle, i, rays)
		var query := PhysicsRayQueryParameters3D.create(
			origin, origin + dir * Game.tuning.flame_range, ZOMBIE_MASK
		)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var collider: Object = hit.get("collider")
		if collider == null or not collider.has_method("take_damage"):
			continue
		hits[collider.get_instance_id()] = collider
	for id: int in hits:
		var target: Object = hits[id]
		if not is_instance_valid(target):
			continue
		target.call("take_damage", Game.tuning.flame_direct_dps * interval)
		if target.has_method("apply_burn"):
			target.call("apply_burn", Game.tuning.flame_burn_seconds)


func _ray_direction(basis: Basis, half_angle: float, index: int, count: int) -> Vector3:
	if index == 0:
		return -basis.z
	var angle := TAU * (float(index) / float(maxi(1, count - 1)))
	angle += _rng.randf_range(-0.25, 0.25)
	var radius := sqrt(_rng.randf()) * half_angle
	var local := Vector3(sin(radius) * cos(angle), sin(radius) * sin(angle), -cos(radius))
	return (basis * local).normalized()


func _build_gun() -> void:
	nozzle = Node3D.new()
	nozzle.name = "Nozzle"
	add_child(nozzle)
	var barrel := MeshInstance3D.new()
	barrel.mesh = MeshFactory.box(Vector3(0.1, 0.1, 0.72))
	barrel.material_override = Palette.material("stone")
	barrel.position = Vector3(0.22, -0.2, -0.55)
	nozzle.add_child(barrel)
	var tank := MeshInstance3D.new()
	tank.mesh = MeshFactory.box(Vector3(0.16, 0.26, 0.3))
	tank.material_override = Palette.material("wood")
	tank.position = Vector3(0.28, -0.3, -0.28)
	nozzle.add_child(tank)


func _build_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "FlameParticles"
	_particles.amount = 42
	_particles.lifetime = 0.55
	_particles.local_coords = false
	_particles.visibility_aabb = AABB(Vector3(-9, -4, -9), Vector3(18, 9, 18))
	_particles.process_material = _flame_process_material()
	_particles.draw_pass_1 = _particle_quad(Palette.material("flame_core"))
	_particles.emitting = false
	nozzle.add_child(_particles)

	_smoke = GPUParticles3D.new()
	_smoke.name = "SmokeParticles"
	_smoke.amount = 18
	_smoke.lifetime = 1.1
	_smoke.local_coords = false
	_smoke.visibility_aabb = AABB(Vector3(-9, -4, -9), Vector3(18, 9, 18))
	_smoke.process_material = _smoke_process_material()
	_smoke.draw_pass_1 = _particle_quad(Palette.material("smoke"))
	_smoke.emitting = false
	nozzle.add_child(_smoke)


func _build_light() -> void:
	_light = OmniLight3D.new()
	_light.name = "FlameLight"
	_light.light_color = Palette.AMBER_HOT
	_light.light_energy = 2.4
	_light.omni_range = 9.0
	_light.shadow_enabled = false
	_light.position = Vector3(0, 0, -2.0)
	_light.visible = false
	nozzle.add_child(_light)


func _flicker_light(delta: float, on: bool) -> void:
	if _light == null or not on:
		return
	_flicker += delta * 30.0
	var noise := sin(_flicker) * 0.35 + sin(_flicker * 2.7) * 0.2
	_light.light_energy = 2.4 + noise
	_light.position = Vector3(0, 0, -2.2 + sin(_flicker * 0.6) * 0.3)


func _flame_process_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.12
	mat.direction = Vector3(0, 0, -1)
	mat.spread = 7.0
	mat.initial_velocity_min = 6.0
	mat.initial_velocity_max = 10.0
	mat.gravity = Vector3(0, 1.6, 0)
	mat.damping_min = 2.0
	mat.damping_max = 4.0
	mat.scale_min = 0.2
	mat.scale_max = 0.55
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(0.35, 2.2))
	scale_curve.add_point(Vector2(1.0, 0.05))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = scale_curve
	mat.scale_curve = scale_texture
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	gradient.set_color(1, Color(0.9, 0.25, 0.05, 0.0))
	gradient.add_point(0.4, Color(1.0, 0.6, 0.15, 0.9))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	mat.color_ramp = ramp
	return mat


func _smoke_process_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.2
	mat.direction = Vector3(0, 0.7, -1)
	mat.spread = 14.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.5
	mat.gravity = Vector3(0, 1.1, 0)
	mat.damping_min = 1.5
	mat.damping_max = 3.0
	mat.scale_min = 0.4
	mat.scale_max = 0.9
	mat.color = Color(0.2, 0.19, 0.18, 0.5)
	return mat


func _particle_quad(material: Material) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	quad.material = material
	return quad
