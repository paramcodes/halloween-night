extends TestCase
## Flow field: open-field gradient, routing around a wall through a gap, and
## that a carved doorway makes a blocked house reachable.

var field := FlowField.new()


func _setup_field() -> void:
	field = FlowField.new()
	field.configure(Vector2(-10, -10), Vector2(20, 20), 2.0)


func _walk(start: Vector3, target: Vector3, steps: int) -> bool:
	var position := start
	for _i in range(steps):
		if position.distance_to(target) < 1.4:
			return true
		var direction := field.sample(position)
		if direction.length() < 0.01:
			break
		position += direction * 0.55
		if field.is_blocked_at(position):
			return false
	if position.distance_to(target) < 2.0:
		return true
	return false


func test_open_field_points_at_target() -> void:
	_setup_field()
	check(field.build(Vector3(6, 0, 6)), "field builds")
	var direction := field.sample(Vector3(-6, 0, -6))
	var expected := (Vector3(6, 0, 6) - Vector3(-6, 0, -6)).normalized()
	greater(direction.dot(expected), 0.8, "direction points at target")


func test_routes_around_wall_through_gap() -> void:
	_setup_field()
	field.block_rect(Rect2(0.0, -10.0, 1.0, 14.0))
	check(field.build(Vector3(8, 0, -8)), "field builds with wall")
	var start := Vector3(-8, 0, -8)
	check(not field.is_blocked_at(start), "start is open")
	check(_walk(start, Vector3(8, 0, -8), 120), "agent reaches other side via the gap")


func test_door_carve_reaches_inside() -> void:
	_setup_field()
	field.block_rect(Rect2(-6.0, -6.0, 12.0, 12.0))
	field.unblock_rect(Rect2(-4.0, -4.0, 8.0, 8.0))
	field.unblock_rect(Rect2(-1.8, 4.8, 3.6, 3.6))
	check(not field.is_blocked_at(Vector3(0, 0, 6.5)), "door cell is passable")
	check(field.build(Vector3(0, 0, 0)), "field builds inside house")
	check(_walk(Vector3(0, 0, 11), Vector3(0, 0, 0), 120), "agent walks through carved door")


func test_blocked_target_falls_back_to_nearest_open_cell() -> void:
	_setup_field()
	field.block_rect(Rect2(-2.0, -2.0, 4.0, 4.0))
	check(field.build(Vector3(0, 0, 0)), "field builds with blocked target")
	check(field.valid, "field stays valid")
