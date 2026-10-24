class_name Hud
extends CanvasLayer
## All player-facing information, built in code so it stays easy to change and
## never drifts from the systems it reads.

const PANEL_WIDTH := 520
const FUEL_BAR_WIDTH := 260.0

var player: Player
var village: Village
var director: NightDirector

var _root: Control
var _status: Label
var _counts: Label
var _fuel_fill: ColorRect
var _fuel_label: Label
var _fuel_seconds: Label
var _crosshair: Label
var _prompt: Label
var _progress_bg: ColorRect
var _progress_fill: ColorRect
var _doors: Label
var _toast: Label
var _debug: Label
var _panel_layer: Control
var _dusk_panel: PanelContainer
var _tally_panel: PanelContainer
var _pause_panel: PanelContainer
var _over_panel: PanelContainer
var _tally_body: Label
var _over_body: Label
var _choice_buttons: Array[Button] = []
var _choice_ids: PackedStringArray = []

var _toast_timer := 0.0
var _debug_visible := false
var _frame_samples: Array[float] = []
var _fps_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	EventBus.toast.connect(_on_toast)
	EventBus.dusk_choice_made.connect(_on_choice_made)


func setup(player_node: Player, world: Village, horde: NightDirector) -> void:
	player = player_node
	village = world
	director = horde
	_frame_samples.clear()


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_status = _label(_root, 26, Palette.AMBER_HOT)
	_status.position = Vector2(26, 20)
	_status.size = Vector2(560, 34)

	_counts = _label(_root, 17, Color("c9d4e0"))
	_counts.position = Vector2(26, 58)
	_counts.size = Vector2(560, 60)

	var fuel_bg := ColorRect.new()
	fuel_bg.color = Color(0.03, 0.05, 0.07, 0.72)
	fuel_bg.position = Vector2(26, 946)
	fuel_bg.size = Vector2(FUEL_BAR_WIDTH + 24, 92)
	_root.add_child(fuel_bg)

	_fuel_label = _label(fuel_bg, 16, Color("e6e0d2"))
	_fuel_label.position = Vector2(12, 6)
	_fuel_label.size = Vector2(240, 24)

	_fuel_seconds = _label(fuel_bg, 16, Color("e6e0d2"))
	_fuel_seconds.position = Vector2(12, 30)
	_fuel_seconds.size = Vector2(240, 22)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.12, 0.14, 0.16, 1.0)
	bar_bg.position = Vector2(12, 60)
	bar_bg.size = Vector2(FUEL_BAR_WIDTH, 18)
	fuel_bg.add_child(bar_bg)

	_fuel_fill = ColorRect.new()
	_fuel_fill.color = Palette.AMBER
	_fuel_fill.position = Vector2(12, 60)
	_fuel_fill.size = Vector2(FUEL_BAR_WIDTH, 18)
	fuel_bg.add_child(_fuel_fill)

	_crosshair = _label(_root, 20, Color(1, 1, 1, 0.65))
	_crosshair.text = "+"
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position = Vector2(-6, -14)
	_crosshair.size = Vector2(30, 30)

	_prompt = _label(_root, 18, Color("f0e6d2"))
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-340, -136)
	_prompt.size = Vector2(680, 26)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_progress_bg = ColorRect.new()
	_progress_bg.color = Color(0.05, 0.06, 0.07, 0.8)
	_progress_bg.visible = false
	_progress_bg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_progress_bg.position = Vector2(-150, -104)
	_progress_bg.size = Vector2(300, 10)
	_root.add_child(_progress_bg)

	_progress_fill = ColorRect.new()
	_progress_fill.color = Palette.AMBER
	_progress_fill.position = Vector2.ZERO
	_progress_fill.size = Vector2(0, 10)
	_progress_bg.add_child(_progress_fill)

	_doors = _label(_root, 16, Color("c9d4e0"))
	_doors.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_doors.position = Vector2(-360, 20)
	_doors.size = Vector2(336, 170)
	_doors.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_toast = _label(_root, 20, Color("ffd9a0"))
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position = Vector2(-420, 118)
	_toast.size = Vector2(840, 60)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0

	_debug = _label(_root, 14, Color("9fe0a0"))
	_debug.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_debug.position = Vector2(-360, 200)
	_debug.size = Vector2(336, 260)
	_debug.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_debug.visible = false

	_panel_layer = Control.new()
	_panel_layer.name = "Panels"
	_panel_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel_layer)

	_dusk_panel = _make_panel("Dusk", 3)
	_tally_panel = _make_panel("Dawn", 0)
	_pause_panel = _make_panel("Paused", 0)
	_over_panel = _make_panel("Run over", 0)
	_tally_body = _panel_body(_tally_panel)
	_over_body = _panel_body(_over_panel)


func _make_panel(title: String, button_count: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-PANEL_WIDTH * 0.5, -220)
	panel.size = Vector2(PANEL_WIDTH, 420)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.name = "Box"
	margin.add_child(box)
	var heading := _label(box, 30, Palette.AMBER_HOT)
	heading.text = title
	heading.name = "Title"
	var body := _label(box, 17, Color("d7dde5"))
	body.name = "Body"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in range(button_count):
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 54)
		button.add_theme_font_size_override("font_size", 18)
		button.name = "Choice%d" % i
		button.visible = false
		box.add_child(button)
		_choice_buttons.append(button)
		button.pressed.connect(_on_choice_button.bind(i))
	return panel


func _panel_body(panel: PanelContainer) -> Label:
	var box := (
		panel.get_node("MarginContainer/Box") if panel.has_node("MarginContainer/Box") else null
	)
	if box == null:
		box = panel.get_child(0).get_child(0)
	return box.get_node("Body") as Label


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label


func _process(delta: float) -> void:
	_update_status()
	_update_fuel()
	_update_prompt()
	_update_doors()
	_update_toast(delta)
	_update_debug(delta)


func _update_status() -> void:
	var night := GameClock.night
	var total := Game.tuning.total_nights
	var seconds := int(ceil(GameClock.remaining()))
	_status.text = (
		"NIGHT %d / %d   ·   %s   ·   %d:%02d"
		% [night, total, GameClock.phase_name().to_upper(), seconds / 60, seconds % 60]
	)
	var zombies := director.alive_count() if director != null else 0
	_counts.text = (
		(
			"Villagers %d   ·   Inside %d   ·   Dead %d\n"
			+ "Horde %d   ·   Kills %d   ·   Planks %d   ·   Bells %d"
		)
		% [
			_living_villagers(),
			_inside_count(),
			int(Game.stat("villagers_lost")),
			zombies,
			int(Game.stat("kills")),
			Game.planks(),
			Game.bell_charges(),
		]
	)


func _living_villagers() -> int:
	var count := 0
	if director != null:
		for villager: Villager in director.villagers:
			if is_instance_valid(villager) and not villager.is_dead():
				count += 1
	return count


func _inside_count() -> int:
	var count := 0
	if director != null:
		for villager: Villager in director.villagers:
			if is_instance_valid(villager) and villager.is_hidden():
				count += 1
	return count


func _update_fuel() -> void:
	var fraction := 0.0
	var seconds := 0.0
	if player != null and is_instance_valid(player):
		fraction = player.flamethrower.fuel_fraction()
		seconds = player.flamethrower.seconds_left()
	else:
		fraction = clampf(Game.fuel() / Game.tuning.fuel_capacity, 0.0, 1.0)
	_fuel_fill.size.x = FUEL_BAR_WIDTH * fraction
	if fraction > 0.5:
		_fuel_fill.color = Color("8fd694")
	elif fraction > 0.22:
		_fuel_fill.color = Palette.AMBER
	else:
		_fuel_fill.color = Color("d95c4a")
	_fuel_label.text = "FUEL  %d / %d" % [int(round(fraction * 100.0)), 100]
	_fuel_seconds.text = "%.1f s of flame" % seconds
	if fraction < 0.22:
		_fuel_fill.color.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.008))


func _update_prompt() -> void:
	if player == null or not is_instance_valid(player):
		_prompt.text = ""
		_progress_bg.visible = false
		return
	_prompt.text = player.interact_text
	_progress_bg.visible = player.interact_progress > 0.01
	if _progress_bg.visible:
		var fraction := clampf(player.interact_progress / Game.tuning.boarding_seconds, 0.0, 1.0)
		_progress_fill.size.x = 300.0 * fraction


func _update_doors() -> void:
	if village == null or player == null or not is_instance_valid(player):
		_doors.text = ""
		return
	var sorted: Array = []
	for house: House in village.houses:
		sorted.append([house.interior_center.distance_to(player.global_position), house])
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var lines := PackedStringArray(["DOORS NEARBY"])
	for i in range(mini(3, sorted.size())):
		var house: House = sorted[i][1]
		var door := house.door
		if door == null:
			continue
		var filled := int(round(8.0 * clampf(door.hp / door.max_hp, 0.0, 1.0)))
		var state := "OPEN" if door.broken else "▮".repeat(filled) + "▯".repeat(8 - filled)
		lines.append("%-10s %s  %d" % [house.display_name, state, int(door.hp)])
	_doors.text = "\n".join(lines)


func _update_toast(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		_toast.modulate.a = minf(1.0, _toast_timer * 2.0)
	else:
		_toast.modulate.a = maxf(0.0, _toast.modulate.a - delta * 2.0)


func _update_debug(delta: float) -> void:
	_fps_timer += delta
	_frame_samples.append(delta * 1000.0)
	if _frame_samples.size() > 240:
		_frame_samples.pop_front()
	if _fps_timer < 0.5:
		return
	_fps_timer = 0.0
	if not _debug_visible:
		return
	var sorted := _frame_samples.duplicate()
	sorted.sort()
	var p50: float = sorted[int(sorted.size() * 0.5)] if not sorted.is_empty() else 0.0
	var p95: float = sorted[int(sorted.size() * 0.95)] if not sorted.is_empty() else 0.0
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	_debug.text = (
		(
			"frame p50 %.1f ms  p95 %.1f ms\nfps %d  draw %d  tris %.2fM\n"
			+ "zombies %d  stuck %d\nfuel %.1f  fps cap 60"
		)
		% [
			p50,
			p95,
			Engine.get_frames_per_second(),
			draw_calls,
			primitives / 3000000.0,
			director.alive_count() if director != null else 0,
			_stuck_count(),
			Game.fuel(),
		]
	)


func _stuck_count() -> int:
	var count := 0
	if director != null:
		for villager: Villager in director.villagers:
			if is_instance_valid(villager):
				count += villager.stuck_events
	return count


func _on_toast(text: String) -> void:
	if text.is_empty():
		return
	_toast.text = text
	_toast_timer = 3.5
	_toast.modulate.a = 1.0


func show_dusk_choice(options: Array) -> void:
	if options.is_empty():
		return
	_tally_panel.visible = false
	_dusk_panel.visible = true
	var box := _dusk_panel.get_child(0).get_child(0)
	var body := box.get_node("Body") as Label
	body.text = (
		"The light is going. One cache can be carried in before dark.\n"
		+ "Choose what you will not have tomorrow."
	)
	_choice_ids.clear()
	for i in range(_choice_buttons.size()):
		var button := _choice_buttons[i]
		if i >= options.size():
			button.visible = false
			continue
		var option: Dictionary = options[i]
		button.visible = true
		button.text = "%d. %s — %s" % [i + 1, option.get("title", ""), option.get("detail", "")]
		_choice_ids.append(str(option.get("id", "")))
	if not Game.headless:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_dusk_choice() -> void:
	_dusk_panel.visible = false
	if not Game.headless and is_instance_valid(player):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_choice_button(index: int) -> void:
	var buttons := _choice_buttons
	if index < 0 or index >= buttons.size() or not buttons[index].visible:
		return
	if index >= _choice_ids.size():
		return
	EventBus.dusk_choice_made.emit(_choice_ids[index])


func _on_choice_made(_option_id: String) -> void:
	hide_dusk_choice()


func show_tally(summary: Dictionary) -> void:
	if _dusk_panel.visible:
		return
	_tally_panel.visible = true
	_tally_body.text = (
		(
			"Nights survived: %d\nZombies burned: %d\nVillagers lost: %d\nDoors lost: %d\n"
			+ "Fuel spent: %d\n\nDawn is not mercy. It is time."
		)
		% [
			summary.get("nights_survived", 0),
			summary.get("kills", 0),
			summary.get("villagers_lost", 0),
			summary.get("doors_lost", 0),
			int(summary.get("fuel_spent", 0.0)),
		]
	)


func hide_tally() -> void:
	_tally_panel.visible = false


func show_run_over(victory: bool, summary: Dictionary) -> void:
	_over_panel.visible = true
	_pause_panel.visible = false
	var box := _over_panel.get_child(0).get_child(0)
	(box.get_node("Title") as Label).text = (
		"DAWN BROKE. THE VILLAGE HELD." if victory else "THE LINE BROKE."
	)
	_over_body.text = (
		(
			"Reached night %d of %d\nZombies burned: %d\nVillagers lost: %d\n"
			+ "Doors lost: %d\n\nPress R to begin again."
		)
		% [
			summary.get("night", 1),
			Game.tuning.total_nights,
			summary.get("kills", 0),
			summary.get("villagers_lost", 0),
			summary.get("doors_lost", 0),
		]
	)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if not Game.headless else Input.mouse_mode


func toggle_pause() -> void:
	if _over_panel.visible:
		return
	if get_tree().paused:
		_resume()
	else:
		_pause()


func _pause() -> void:
	get_tree().paused = true
	_pause_panel.visible = true
	if not Game.headless:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var box := _pause_panel.get_child(0).get_child(0)
	_panel_body(_pause_panel).text = (
		(
			"Fuel: %d / 100\nPlanks: %d\nBells: %d\n\n"
			+ "WASD move · Shift sprint · RMB aim · LMB flame\n"
			+ "E board · Q bell · Esc pause · F3 metrics"
		)
		% [int(Game.fuel()), Game.planks(), Game.bell_charges()]
	)
	var existing := box.get_node_or_null("Resume")
	if existing == null:
		var resume := Button.new()
		resume.name = "Resume"
		resume.text = "Resume"
		resume.custom_minimum_size = Vector2(0, 48)
		resume.pressed.connect(_resume)
		box.add_child(resume)
		var restart := Button.new()
		restart.name = "Restart"
		restart.text = "Restart run"
		restart.custom_minimum_size = Vector2(0, 48)
		restart.pressed.connect(restart_run)
		box.add_child(restart)


func _resume() -> void:
	get_tree().paused = false
	_pause_panel.visible = false
	if not Game.headless:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func restart_run() -> void:
	get_tree().paused = false
	Game.new_run()
	GameClock.stop()
	GameClock.night = 1
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_overlay"):
		_debug_visible = not _debug_visible
		_debug.visible = _debug_visible
		EventBus.debug_toggled.emit(_debug_visible)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skip_phase") and OS.is_debug_build():
		GameClock.skip_to_next_phase()
	elif _dusk_panel.visible:
		for i in range(_choice_buttons.size()):
			if event.is_action_pressed("choice_%d" % (i + 1)) and _choice_buttons[i].visible:
				_on_choice_button(i)
				break
	elif _over_panel.visible and event is InputEventKey:
		if (event as InputEventKey).pressed and (event as InputEventKey).physical_keycode == KEY_R:
			restart_run()
