class_name Village
extends Node3D
## Procedural greybox village: nine houses, three spawn edges, four street
## chokepoints, and the navigation data the horde needs.
##
## Everything is generated at runtime so the greybox stays reproducible and the
## layout can be tuned without touching a scene file.

const HOUSE_NAMES := [
	"Baker",
	"Smith",
	"Elder",
	"Herbalist",
	"Cooper",
	"Miller",
	"Widow",
	"Tanner",
	"Gatehouse",
]

const HORDE_BOUNDS := 58.0
const GRID_SPACING := 32.0

var houses: Array[House] = []
var doors: Array[Door] = []
var spawn_points: Array[Vector3] = []
var job_spots: Array[Dictionary] = []
var flow := FlowField.new()

var _blocked_rects: Array[Rect2] = []
var _layout_rng := RandomNumberGenerator.new()
var _flow_timer := 0.0


func build(tuning: Tuning) -> void:
	_layout_rng.seed = 1337
	_build_ground()
	_build_streets()
	_build_houses(tuning)
	_build_spawn_points()
	_build_job_spots()
	_build_props()
	_build_flow_field(tuning)


func update_flow(player_pos: Vector3, delta: float, hz: float) -> void:
	_flow_timer -= delta
	if _flow_timer > 0.0:
		return
	_flow_timer = 1.0 / maxf(0.5, hz)
	flow.build(player_pos)


func flow_direction(pos: Vector3) -> Vector3:
	return flow.sample(pos)


func nearest_door(pos: Vector3, max_distance := 4.0) -> Door:
	var best: Door = null
	var best_dist := max_distance * max_distance
	for door: Door in doors:
		if door.broken:
			continue
		var d := door.global_position.distance_squared_to(pos)
		if d < best_dist:
			best_dist = d
			best = door
	return best


func nearest_house(pos: Vector3) -> House:
	var best: House = null
	var best_dist := INF
	for house: House in houses:
		var d := house.interior_center.distance_squared_to(pos)
		if d < best_dist:
			best_dist = d
			best = house
	return best


func house_containing(pos: Vector3) -> House:
	for house: House in houses:
		if house.is_inside(pos):
			return house
	return null


func house_by_id(id: int) -> House:
	for house: House in houses:
		if house.house_id == id:
			return house
	return null


func spawn_position(rng: RandomNumberGenerator) -> Vector3:
	var base: Vector3 = spawn_points[rng.randi_range(0, spawn_points.size() - 1)]
	var offset := Vector3(rng.randf_range(-5.0, 5.0), 0.0, rng.randf_range(-5.0, 5.0))
	return base + offset


func raider_target(rng: RandomNumberGenerator) -> House:
	var candidates: Array[House] = []
	for house: House in houses:
		if not house.door_broken():
			candidates.append(house)
	if candidates.is_empty():
		return house_by_id(0)
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = MeshFactory.plane(Vector2(Game.tuning.village_size, Game.tuning.village_size), 4)
	ground.material_override = Palette.material("ground")
	ground.position.y = -0.02
	add_child(ground)

	var body := StaticBody3D.new()
	body.name = "GroundBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(Game.tuning.village_size, 1.0, Game.tuning.village_size)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	add_child(body)


func _build_streets() -> void:
	var street := Palette.material("street")
	_add_slab(Vector3(110, 0.04, 8), Vector3(0, 0.01, 0), street, "StreetEW")
	_add_slab(Vector3(8, 0.04, 110), Vector3(0, 0.01, 0), street, "StreetNS")
	_add_slab(Vector3(26, 0.05, 26), Vector3(0, 0.02, 0), street, "Square")


func _build_houses(tuning: Tuning) -> void:
	var plots: Array[Vector2] = []
	for row in range(-1, 2):
		for col in range(-1, 2):
			if row == 0 and col == 0:
				continue
			plots.append(Vector2(col * GRID_SPACING, row * GRID_SPACING))
	plots.append(Vector2(0, 50))
	var index := 0
	for plot: Vector2 in plots:
		var gatehouse := index == 8
		var size := Vector2(16, 10) if gatehouse else Vector2(12, 10)
		var center := Vector3(plot.x, 0.0, plot.y)
		var to_center := Vector3.ZERO - center
		var door_axis := "z"
		var door_side := 1.0
		if gatehouse:
			door_side = -1.0
		elif absf(to_center.x) > absf(to_center.z):
			door_axis = "x"
			door_side = signf(to_center.x)
		else:
			door_axis = "z"
			door_side = signf(to_center.z)
		var house := _create_house(
			index, HOUSE_NAMES[index], center, size, door_axis, door_side, gatehouse, tuning
		)
		houses.append(house)
		index += 1


func _create_house(
	id: int,
	label: String,
	center: Vector3,
	size: Vector2,
	door_axis: String,
	door_side: float,
	gatehouse: bool,
	tuning: Tuning
) -> House:
	var house := House.new()
	house.name = "House_%d_%s" % [id, label]
	house.position = center
	add_child(house)

	var height := 10.0 if gatehouse else 8.0
	var wall_mat := Palette.material("wall_alt" if gatehouse else "wall")
	var trim_mat := Palette.material("wood")
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	house.add_child(body)

	var half := size * 0.5
	var gap := 2.6
	var thickness := 0.4
	var door_position := Vector3.ZERO
	var door_rotation := 0.0

	# Two walls run the full width; the front wall is split around the door.
	for axis: String in ["x", "z"]:
		for side: float in [-1.0, 1.0]:
			var is_front := axis == door_axis and is_equal_approx(side, door_side)
			if is_front:
				var segment: float = (size.x - gap) * 0.5 if axis == "z" else (size.y - gap) * 0.5
				for segment_side: float in [-1.0, 1.0]:
					var offset: float = segment_side * (gap * 0.5 + segment * 0.5)
					if axis == "z":
						_add_wall(
							house,
							body,
							Vector3(segment, height, thickness),
							Vector3(offset, height * 0.5, side * half.y),
							wall_mat,
							seg_name(axis, side, segment_side)
						)
					else:
						_add_wall(
							house,
							body,
							Vector3(thickness, height, segment),
							Vector3(side * half.x, height * 0.5, offset),
							wall_mat,
							seg_name(axis, side, segment_side)
						)
			else:
				if axis == "z":
					_add_wall(
						house,
						body,
						Vector3(size.x, height, thickness),
						Vector3(0, height * 0.5, side * half.y),
						wall_mat,
						seg_name(axis, side, 0.0)
					)
				else:
					_add_wall(
						house,
						body,
						Vector3(thickness, height, size.y),
						Vector3(side * half.x, height * 0.5, 0),
						wall_mat,
						seg_name(axis, side, 0.0)
					)

	# Door sits in the gap. Its collision is the only thing between the street
	# and the people inside.
	var door_node := Door.new()
	door_node.name = "Door"
	if door_axis == "z":
		door_position = Vector3(0, 0, door_side * half.y)
	else:
		door_position = Vector3(door_side * half.x, 0, 0)
		door_rotation = PI * 0.5
	door_node.position = door_position
	door_node.rotation.y = door_rotation
	var door_body_shape := CollisionShape3D.new()
	door_body_shape.name = "Shape"
	var door_box := BoxShape3D.new()
	door_box.size = Vector3(2.4, 2.6, 0.3)
	door_body_shape.shape = door_box
	door_body_shape.position.y = 1.3
	door_node.add_child(door_body_shape)
	var door_mesh := MeshInstance3D.new()
	door_mesh.name = "Mesh"
	door_mesh.mesh = MeshFactory.box(Vector3(2.3, 2.5, 0.14))
	door_mesh.material_override = Palette.material("door")
	door_mesh.position.y = 1.25
	door_node.add_child(door_mesh)
	house.add_child(door_node)
	door_node.setup(id, tuning.door_hp, tuning.door_max_hp)
	doors.append(door_node)

	# Corner posts, roof, windows, floor.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			post.mesh = MeshFactory.box(Vector3(0.5, height + 0.6, 0.5))
			post.material_override = trim_mat
			post.position = Vector3(sx * half.x, height * 0.5, sz * half.y)
			house.add_child(post)

	var roof_mat := Palette.material("roof")
	for side: float in [-1.0, 1.0]:
		var slope := MeshInstance3D.new()
		slope.mesh = MeshFactory.box(Vector3(size.x + 1.2, 0.35, size.y * 0.66))
		slope.material_override = roof_mat
		slope.position = Vector3(0, height + 0.75, side * size.y * 0.26)
		slope.rotation.x = deg_to_rad(32.0 * side)
		house.add_child(slope)

	var window_mat := Palette.material("window")
	for side: float in [-1.0, 1.0]:
		var window_mesh := MeshInstance3D.new()
		window_mesh.mesh = MeshFactory.box(Vector3(0.12, 1.1, 0.9))
		window_mesh.material_override = window_mat
		window_mesh.position = Vector3(side * half.x, height * 0.56, 0)
		house.add_child(window_mesh)

	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = MeshFactory.box(Vector3(size.x - 0.6, 0.1, size.y - 0.6))
	floor_mesh.material_override = Palette.material("wood")
	floor_mesh.position.y = 0.06
	house.add_child(floor_mesh)

	var light := OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(0, 2.4, 0)
	light.light_color = Palette.AMBER
	light.light_energy = 1.1
	light.omni_range = 8.0
	light.shadow_enabled = false
	house.add_child(light)

	var rect := Rect2(center.x - size.x * 0.5, center.z - size.y * 0.5, size.x, size.y)
	house.setup(id, label, rect, door_node, center + Vector3(0, 1, 0), gatehouse)
	_blocked_rects.append(rect.grow(0.3))
	return house


func seg_name(axis: String, side: float, segment_side: float) -> String:
	return "%s_%s_%s" % [axis, str(side), str(segment_side)]


func _add_wall(
	house: House,
	body: StaticBody3D,
	size: Vector3,
	position: Vector3,
	material: Material,
	label: String
) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "Wall_" + label
	mesh.mesh = MeshFactory.box(size)
	mesh.material_override = material
	mesh.position = position
	house.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = position
	body.add_child(shape)


func _add_slab(size: Vector3, position: Vector3, material: Material, label: String) -> void:
	var slab := MeshInstance3D.new()
	slab.name = label
	slab.mesh = MeshFactory.box(size)
	slab.material_override = material
	slab.position = position
	add_child(slab)


func _build_spawn_points() -> void:
	spawn_points.clear()
	spawn_points.append(Vector3(-HORDE_BOUNDS, 0, 0))
	spawn_points.append(Vector3(HORDE_BOUNDS, 0, 0))
	spawn_points.append(Vector3(0, 0, -HORDE_BOUNDS))


func _build_job_spots() -> void:
	job_spots.clear()
	job_spots.append({"kind": "water", "position": Vector3(3.5, 0, 3.5)})
	job_spots.append({"kind": "wood", "position": Vector3(-44, 0, 14)})
	job_spots.append({"kind": "wood", "position": Vector3(-44, 0, 0)})
	job_spots.append({"kind": "wood", "position": Vector3(-44, 0, -14)})
	job_spots.append({"kind": "watch", "position": Vector3(6, 0, 42)})
	job_spots.append({"kind": "watch", "position": Vector3(-6, 0, 42)})
	job_spots.append({"kind": "repair", "position": Vector3(16, 0, 16)})
	job_spots.append({"kind": "repair", "position": Vector3(-16, 0, -16)})
	job_spots.append({"kind": "repair", "position": Vector3(16, 0, -16)})
	job_spots.append({"kind": "repair", "position": Vector3(-16, 0, 16)})
	job_spots.append({"kind": "wood", "position": Vector3(30, 0, 30)})
	job_spots.append({"kind": "rough", "position": Vector3(-30, 0, 30)})


func _build_props() -> void:
	_add_prop("well", Vector3(0, 0, 0), 0.0)
	_add_prop("bench", Vector3(4.5, 0, -1.5), PI * 0.5)
	_add_prop("bench", Vector3(-4.5, 0, 1.5), PI * 0.5)
	var torch_spots := [
		Vector3(12, 0, 12),
		Vector3(-12, 0, 12),
		Vector3(12, 0, -12),
		Vector3(-12, 0, -12),
	]
	for spot: Vector3 in torch_spots:
		_add_torch(spot)
	var prop_kinds := ["crate", "barrel", "cart", "hay", "post", "fence", "crate", "barrel"]
	for house: House in houses:
		var angle := _layout_rng.randf_range(0.0, TAU)
		var dist := _layout_rng.randf_range(7.0, 10.0)
		var offset := Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		var kind: String = prop_kinds[_layout_rng.randi_range(0, prop_kinds.size() - 1)]
		_add_prop(kind, house.position + offset, _layout_rng.randf_range(0, TAU))
	for i in range(14):
		var angle := _layout_rng.randf_range(0.0, TAU)
		var radius := _layout_rng.randf_range(18.0, 46.0)
		var pos := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		var kind: String = prop_kinds[_layout_rng.randi_range(0, prop_kinds.size() - 1)]
		_add_prop(kind, pos, _layout_rng.randf_range(0, TAU))


func _add_prop(kind: String, position: Vector3, rotation_y: float) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = MeshFactory.prop_mesh(kind)
	if kind == "fence" or kind == "post":
		mesh.material_override = Palette.material("wood")
	elif kind == "hay":
		mesh.material_override = Palette.material("villager")
	elif kind == "cart":
		mesh.material_override = Palette.material("plank")
	else:
		mesh.material_override = Palette.material("wood")
	mesh.position = position
	mesh.rotation.y = rotation_y
	add_child(mesh)


func _add_torch(position: Vector3) -> void:
	_add_prop("post", position, 0.0)
	var lantern := MeshInstance3D.new()
	lantern.mesh = MeshFactory.box(Vector3(0.34, 0.4, 0.34))
	lantern.material_override = Palette.material("window")
	lantern.position = position + Vector3(0.35, 2.2, 0)
	add_child(lantern)
	var light := OmniLight3D.new()
	light.position = position + Vector3(0, 2.2, 0)
	light.light_color = Palette.AMBER
	light.light_energy = 1.4
	light.omni_range = 11.0
	light.shadow_enabled = false
	add_child(light)


func _build_flow_field(tuning: Tuning) -> void:
	var half := tuning.village_size * 0.5
	flow.configure(
		Vector2(-half, -half),
		Vector2(tuning.village_size, tuning.village_size),
		tuning.flow_field_cell
	)
	for rect: Rect2 in _blocked_rects:
		flow.block_rect(rect)
	# Interiors are walkable once a door opens; only the wall ring blocks.
	for house: House in houses:
		var inner := house.interior_rect.grow(-2.0)
		flow.unblock_rect(inner)
	for door: Door in doors:
		var d := door.global_position
		flow.unblock_rect(Rect2(d.x - 1.8, d.z - 1.8, 3.6, 3.6))
