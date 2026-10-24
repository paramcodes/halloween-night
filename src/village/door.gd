class_name Door
extends StaticBody3D
## A door is a health pool with a collision shape. Zombies break it, the player
## boards it, and the house behind it becomes reachable when it opens.

var house_id := 0
var hp := 200.0
var max_hp := 200.0
var broken := false
var boards := 0
var position_hint := Vector3.ZERO

var _mesh: MeshInstance3D
var _shape: CollisionShape3D
var _audio_cooldown := 0.0


func setup(id: int, start_hp: float, cap_hp: float) -> void:
	house_id = id
	hp = start_hp
	max_hp = cap_hp
	collision_layer = 16
	collision_mask = 0
	position_hint = global_position
	_mesh = get_node_or_null("Mesh") as MeshInstance3D
	_shape = get_node_or_null("Shape") as CollisionShape3D


func take_damage(amount: float) -> void:
	if broken or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	EventBus.door_damaged.emit(house_id, hp, max_hp)
	if _audio_cooldown <= 0.0:
		_audio_cooldown = 1.2
	if hp <= 0.0:
		_break_open()


func board(amount: float) -> void:
	if broken:
		return
	hp = minf(max_hp, hp + amount)
	boards += 1
	_spawn_planks()
	EventBus.door_boarded.emit(house_id, hp)


func restore_state(saved_hp: float, cap_hp: float) -> void:
	max_hp = cap_hp
	hp = clampf(saved_hp, 0.0, cap_hp)
	if hp <= 0.5:
		_break_open()
	else:
		broken = false
		if _shape != null:
			_shape.disabled = false
		if _mesh != null:
			_mesh.rotation.y = 0.0
	EventBus.door_damaged.emit(house_id, hp, max_hp)


func repaired(amount: float) -> void:
	if broken:
		return
	hp = minf(max_hp, hp + amount)
	EventBus.door_boarded.emit(house_id, hp)


func _break_open() -> void:
	if broken:
		return
	broken = true
	hp = 0.0
	if _shape != null:
		_shape.set_deferred("disabled", true)
	if _mesh != null:
		_mesh.rotation.y = deg_to_rad(-82.0)
		_mesh.position.x += 0.8
	EventBus.door_breached.emit(house_id)


func _process(delta: float) -> void:
	if _audio_cooldown > 0.0:
		_audio_cooldown -= delta


func _spawn_planks() -> void:
	if _mesh == null:
		return
	for i in range(2):
		var plank := MeshInstance3D.new()
		plank.mesh = MeshFactory.box(Vector3(1.9, 0.22, 0.08))
		plank.material_override = Palette.material("plank")
		plank.position = Vector3(0.0, 0.5 + i * 0.55, 0.16)
		plank.rotation.z = deg_to_rad(-12.0 + i * 8.0)
		add_child(plank)
