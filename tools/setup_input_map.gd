extends SceneTree
## One-off generator for the input map stored in project.godot.
##
## Run: godot --headless --path . --script res://tools/setup_input_map.gd
## The generated [input] section is committed; this script only exists so the
## map can be rebuilt reproducibly.

const KEYBOARD_ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"interact": [KEY_E],
	"bell": [KEY_Q],
	"pause": [KEY_ESCAPE],
	"debug_overlay": [KEY_F3],
	"choice_1": [KEY_1],
	"choice_2": [KEY_2],
	"choice_3": [KEY_3],
	"skip_phase": [KEY_F9],
}

const MOUSE_ACTIONS := {
	"fire": MOUSE_BUTTON_LEFT,
	"aim": MOUSE_BUTTON_RIGHT,
}


func _init() -> void:
	for action: String in KEYBOARD_ACTIONS:
		_register(action, _keys_to_events(KEYBOARD_ACTIONS[action]))
	for action: String in MOUSE_ACTIONS:
		_register(action, [_mouse_event(MOUSE_ACTIONS[action])])
	var err := ProjectSettings.save()
	print("input map saved: ", error_string(err))
	quit(0 if err == OK else 1)


func _register(action: String, events: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.2)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)
	ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})


func _keys_to_events(keys: Array) -> Array:
	var events: Array = []
	for key: int in keys:
		events.append(_key_event(key))
	return events


func _key_event(key: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = key
	return event


func _mouse_event(button: int) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event
