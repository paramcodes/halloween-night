class_name FlowField
extends RefCounted
## Breadth-first flow field on a coarse XZ grid.
##
## 2 m cells keep a full 120 m village rebuild under a millisecond, which is why
## the field can be refreshed at 4 Hz instead of precomputed per night.

const DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
]

var cell_size := 2.0
var origin := Vector2.ZERO
var cols := 0
var rows := 0
var blocked := PackedByteArray()
var directions := PackedVector2Array()
var target := Vector2.ZERO
var valid := false
var build_ms := 0.0

var _dist: PackedInt32Array = []
var _queue: PackedInt32Array = []


func configure(min_xz: Vector2, size_xz: Vector2, cell: float) -> void:
	cell_size = maxf(0.5, cell)
	origin = min_xz
	cols = int(ceil(size_xz.x / cell_size)) + 1
	rows = int(ceil(size_xz.y / cell_size)) + 1
	blocked.resize(cols * rows)
	blocked.fill(0)
	directions.resize(cols * rows)
	directions.fill(Vector2.ZERO)
	_dist.resize(cols * rows)
	_queue.resize(cols * rows)


func clear_blockers() -> void:
	blocked.fill(0)
	valid = false


func block_rect(rect: Rect2) -> void:
	block_cells(rect, 1)


func unblock_rect(rect: Rect2) -> void:
	block_cells(rect, 0)


func block_cells(rect: Rect2, value: int) -> void:
	var from := cell_of(Vector3(rect.position.x, 0.0, rect.position.y))
	var to := cell_of(Vector3(rect.end.x, 0.0, rect.end.y))
	for z in range(maxi(0, from.y), mini(rows, to.y + 1)):
		for x in range(maxi(0, from.x), mini(cols, to.x + 1)):
			blocked[z * cols + x] = value
	valid = false


func cell_of(pos: Vector3) -> Vector2i:
	var x := int(floor((pos.x - origin.x) / cell_size))
	var z := int(floor((pos.z - origin.y) / cell_size))
	return Vector2i(x, z)


func cell_center(cell: Vector2i) -> Vector3:
	return Vector3(
		origin.x + (cell.x + 0.5) * cell_size, 0.0, origin.y + (cell.y + 0.5) * cell_size
	)


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


func is_blocked_at(pos: Vector3) -> bool:
	var cell := cell_of(pos)
	if not is_inside(cell):
		return true
	return blocked[cell.y * cols + cell.x] != 0


func build(target_pos: Vector3) -> bool:
	var started := Time.get_ticks_usec()
	target = Vector2(target_pos.x, target_pos.z)
	var start := _nearest_open_cell(cell_of(target_pos))
	if start.x < 0:
		valid = false
		build_ms = (Time.get_ticks_usec() - started) / 1000.0
		return false
	_dist.fill(-1)
	directions.fill(Vector2.ZERO)
	var start_index := start.y * cols + start.x
	_dist[start_index] = 0
	var head := 0
	var tail := 0
	_queue[tail] = start_index
	tail += 1
	while head < tail:
		var index := _queue[head]
		head += 1
		var cx := index % cols
		var cz := index / cols
		var d := _dist[index]
		for dir: Vector2i in DIRS:
			var nx := cx + dir.x
			var nz := cz + dir.y
			if nx < 0 or nz < 0 or nx >= cols or nz >= rows:
				continue
			var nindex := nz * cols + nx
			if blocked[nindex] != 0 or _dist[nindex] != -1:
				continue
			if dir.x != 0 and dir.y != 0:
				if blocked[cz * cols + nx] != 0 or blocked[nz * cols + cx] != 0:
					continue
			_dist[nindex] = d + 1
			directions[nindex] = Vector2(cx - nx, cz - nz).normalized()
			_queue[tail] = nindex
			tail += 1
	valid = true
	build_ms = (Time.get_ticks_usec() - started) / 1000.0
	return true


func sample(pos: Vector3) -> Vector3:
	var cell := cell_of(pos)
	if not is_inside(cell):
		var to_target := target - Vector2(pos.x, pos.z)
		return Vector3(to_target.x, 0.0, to_target.y).normalized()
	var index := cell.y * cols + cell.x
	if blocked[index] != 0 or not valid:
		var to_target := target - Vector2(pos.x, pos.z)
		if to_target.length_squared() < 0.01:
			return Vector3.ZERO
		return Vector3(to_target.x, 0.0, to_target.y).normalized()
	var dir := directions[index]
	return Vector3(dir.x, 0.0, dir.y)


func open_cell_ratio() -> float:
	if blocked.is_empty():
		return 0.0
	var open := 0
	for value: int in blocked:
		if value == 0:
			open += 1
	return float(open) / float(blocked.size())


func _nearest_open_cell(start: Vector2i) -> Vector2i:
	if is_inside(start) and blocked[start.y * cols + start.x] == 0:
		return start
	for radius in range(1, 5):
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var cell := start + Vector2i(dx, dz)
				if is_inside(cell) and blocked[cell.y * cols + cell.x] == 0:
					return cell
	return Vector2i(-1, -1)
