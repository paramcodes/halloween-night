class_name House
extends Node3D
## A dwelling: interior volume, one door, occupancy, and the rule that a broken
## door eventually costs the people inside.

const BREACH_KILL_INTERVAL := 2.6

var house_id := 0
var display_name := "House"
var door: Door
var is_gatehouse := false
var interior_rect := Rect2()
var interior_center := Vector3.ZERO
var occupants: Array[Node3D] = []

var _breach_timer := 0.0
var _light: OmniLight3D


func setup(
	id: int, label: String, rect: Rect2, door_node: Door, center: Vector3, gatehouse := false
) -> void:
	house_id = id
	display_name = label
	interior_rect = rect
	door = door_node
	interior_center = center
	is_gatehouse = gatehouse
	_light = get_node_or_null("Light") as OmniLight3D


func is_inside(pos: Vector3) -> bool:
	return interior_rect.has_point(Vector2(pos.x, pos.z))


func occupant_count() -> int:
	return occupants.size()


func occupy(villager: Node3D) -> void:
	if occupants.has(villager):
		return
	occupants.append(villager)
	EventBus.house_occupied.emit(house_id, occupants.size())


func release(villager: Node3D) -> void:
	if occupants.has(villager):
		occupants.erase(villager)
		EventBus.house_occupied.emit(house_id, occupants.size())


func has_room() -> bool:
	return occupants.size() < 6


func set_lights(on: bool) -> void:
	if _light != null:
		_light.visible = on


func door_broken() -> bool:
	return door != null and door.broken


func _process(delta: float) -> void:
	if not door_broken() or occupants.is_empty():
		return
	_breach_timer += delta
	if _breach_timer < BREACH_KILL_INTERVAL:
		return
	_breach_timer = 0.0
	var victim: Node3D = occupants[0]
	occupants.erase(victim)
	EventBus.house_occupied.emit(house_id, occupants.size())
	if victim.has_method("kill"):
		victim.call("kill", "house breached")
