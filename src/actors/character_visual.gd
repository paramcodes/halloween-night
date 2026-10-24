class_name CharacterVisual
extends Node3D
## One rigged, animated character. Instances share the imported scene's meshes,
## skeleton and animation library, so 200 zombies do not duplicate the 95 clips.
##
## Animation LOD is manual: near characters advance every physics frame, mid
## characters every 100 ms, far characters freeze. Nothing is processed by the
## AnimationPlayer itself.

const MODELS := {
	"player": "res://assets/characters/kaykit/Knight.glb",
	"villager_a": "res://assets/characters/kaykit/Barbarian.glb",
	"villager_b": "res://assets/characters/kaykit/Mage.glb",
	"villager_c": "res://assets/characters/kaykit/Rogue.glb",
	"villager_d": "res://assets/characters/kaykit/Rogue_Hooded.glb",
	"shambler": "res://assets/characters/kaykit/Skeleton_Minion.glb",
	"runner": "res://assets/characters/kaykit/Skeleton_Rogue.glb",
	"brute": "res://assets/characters/kaykit/Skeleton_Warrior.glb",
}

const SCALES := {
	"player": 0.82,
	"villager_a": 0.80,
	"villager_b": 0.80,
	"villager_c": 0.80,
	"villager_d": 0.80,
	"shambler": 0.82,
	"runner": 0.82,
	"brute": 1.0,
}

const HIDDEN_TOKENS := [
	"Sword",
	"Shield",
	"Staff",
	"Wand",
	"Bow",
	"Crossbow",
	"Dagger",
	"Axe",
	"Arrow",
	"Quiver",
	"Spellbook",
	"Smoke",
	"Mug",
]

const LOOPING := [
	"Idle",
	"Idle_B",
	"Idle_Combat",
	"Unarmed_Idle",
	"2H_Melee_Idle",
	"Walking_A",
	"Walking_B",
	"Walking_C",
	"Walking_D_Skeletons",
	"Walking_Backwards",
	"Running_A",
	"Running_B",
	"Running_C",
	"1H_Ranged_Aiming",
	"1H_Ranged_Shoot",
	"1H_Ranged_Shooting",
	"2H_Ranged_Aiming",
	"2H_Ranged_Shoot",
	"2H_Ranged_Shooting",
	"Interact",
	"Use_Item",
	"Blocking",
]

const CLIPS := {
	"player":
	{
		"idle": "Idle",
		"walk": "Walking_A",
		"run": "Running_A",
		"aim": "1H_Ranged_Aiming",
		"fire": "1H_Ranged_Shoot",
		"interact": "Interact",
		"hit": "Hit_A",
		"death": "Death_A",
	},
	"villager":
	{
		"idle": "Idle",
		"walk": "Walking_A",
		"run": "Running_A",
		"work": "Interact",
		"hit": "Hit_A",
		"death": "Death_A",
	},
	"shambler":
	{
		"idle": "Idle",
		"walk": "Walking_D_Skeletons",
		"run": "Walking_C",
		"attack": "Unarmed_Melee_Attack_Punch_A",
		"lunge": "Unarmed_Melee_Attack_Punch_B",
		"hit": "Hit_A",
		"death": "Death_C_Skeletons",
	},
	"runner":
	{
		"idle": "Idle_B",
		"walk": "Walking_C",
		"run": "Running_A",
		"attack": "1H_Melee_Attack_Slice_Diagonal",
		"lunge": "1H_Melee_Attack_Jump_Chop",
		"hit": "Hit_A",
		"death": "Death_C_Skeletons",
	},
	"brute":
	{
		"idle": "Idle_B",
		"walk": "Walking_B",
		"run": "Walking_B",
		"attack": "2H_Melee_Attack_Chop",
		"lunge": "2H_Melee_Attack_Chop",
		"hit": "Hit_A",
		"death": "Death_C_Skeletons",
	},
}

static var _scene_cache: Dictionary = {}
static var _material_cache: Dictionary = {}
static var _loops_configured: Dictionary = {}

var kind := ""
var anim_set := ""
var built := false

var _model: Node3D
var _skeleton: Skeleton3D
var _player: AnimationPlayer
var _hand: BoneAttachment3D
var _meshes: Array[MeshInstance3D] = []
var _surface_bases: Array = []
var _tint := Color.WHITE
var _burning := false
var _clip := ""
var _speed := 1.0
var _advance_accum := 0.0


func setup(kind_name: String, set_name := "", tint := Color.WHITE) -> void:
	var next_set := set_name if not set_name.is_empty() else kind_name
	if built and kind == kind_name and anim_set == next_set:
		set_tint(tint)
		return
	_clear()
	kind = kind_name
	anim_set = next_set
	_tint = tint
	_build()
	built = true


func play_state(state: String, blend := 0.18, speed := 1.0, restart := false) -> void:
	var clip := clip_for(state)
	if clip.is_empty() or _player == null:
		return
	_speed = speed
	if clip == _clip and not restart:
		return
	_clip = clip
	_advance_accum = 0.0
	if restart:
		_player.stop()
	_player.play(clip, blend)


func play_clip(clip: String, blend := 0.18, speed := 1.0, restart := false) -> void:
	if _player == null or not _player.has_animation(clip):
		return
	_speed = speed
	if clip == _clip and not restart:
		return
	_clip = clip
	_advance_accum = 0.0
	if restart:
		_player.stop()
	_player.play(clip, blend)


func tick(delta: float, lod: int) -> void:
	if _player == null or not _player.is_playing():
		return
	if lod >= 2:
		return
	var step := delta
	if lod == 1:
		_advance_accum += delta
		if _advance_accum < 0.1:
			return
		step = _advance_accum
		_advance_accum = 0.0
	_player.advance(step * _speed)


func set_burning(on: bool) -> void:
	if _burning == on:
		return
	_burning = on
	_apply_materials()


func set_tint(color: Color) -> void:
	if _tint == color:
		return
	_tint = color
	_apply_materials()


func clip_for(state: String) -> String:
	var table: Dictionary = CLIPS.get(anim_set, {})
	if anim_set.begins_with("villager"):
		table = CLIPS["villager"]
	return str(table.get(state, ""))


func current_clip() -> String:
	return _clip


func hand_position() -> Vector3:
	if _hand != null:
		return _hand.global_position
	return global_position + Vector3(0.0, 1.2, 0.0)


func has_hand() -> bool:
	return _hand != null


func triangle_count() -> int:
	var total := 0
	for mesh_instance: MeshInstance3D in _meshes:
		if mesh_instance.mesh == null:
			continue
		total += mesh_instance.mesh.get_faces().size() / 3
	return total


func surface_count() -> int:
	var total := 0
	for mesh_instance: MeshInstance3D in _meshes:
		if mesh_instance.mesh != null:
			total += mesh_instance.mesh.get_surface_count()
	return total


func animation_count() -> int:
	return _player.get_animation_list().size() if _player != null else 0


func animation_position() -> float:
	return _player.current_animation_position if _player != null else 0.0


func model_height() -> float:
	if _model == null:
		return 0.0
	return _model.scale.y * 2.2


func _build() -> void:
	var path := str(MODELS.get(kind, ""))
	if path.is_empty():
		push_error("CharacterVisual: unknown kind %s" % kind)
		return
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	var packed: PackedScene = _scene_cache[path]
	_model = packed.instantiate() as Node3D
	if _model == null:
		push_error("CharacterVisual: %s is not a Node3D scene" % path)
		return
	_model.name = "Model"
	_model.scale = Vector3.ONE * float(SCALES.get(kind, 0.82))
	add_child(_model)
	_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player == null:
		push_error("CharacterVisual: %s has no AnimationPlayer" % path)
		return
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if not _loops_configured.has(path):
		_configure_loops()
		_loops_configured[path] = true
	_collect_meshes(_model)
	_attach_hand()
	_apply_materials()


func _clear() -> void:
	if _model != null:
		_model.queue_free()
	_model = null
	_skeleton = null
	_player = null
	_hand = null
	_meshes.clear()
	_surface_bases.clear()
	_clip = ""
	_advance_accum = 0.0
	built = false


func _configure_loops() -> void:
	for clip_name: String in _player.get_animation_list():
		var animation := _player.get_animation(clip_name)
		animation.loop_mode = (
			Animation.LOOP_LINEAR if LOOPING.has(clip_name) else Animation.LOOP_NONE
		)


func _collect_meshes(root: Node) -> void:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if _is_accessory(mesh_instance.name):
			mesh_instance.visible = false
			continue
		if mesh_instance.mesh == null:
			continue
		_meshes.append(mesh_instance)
		var bases: Array[Material] = []
		for surface in range(mesh_instance.mesh.get_surface_count()):
			bases.append(mesh_instance.get_active_material(surface))
		_surface_bases.append(bases)


func _is_accessory(node_name: String) -> bool:
	for token: String in HIDDEN_TOKENS:
		if node_name.to_lower().contains(token.to_lower()):
			return true
	return false


func _attach_hand() -> void:
	if _skeleton == null or _skeleton.find_bone("hand.r") < 0:
		return
	_hand = BoneAttachment3D.new()
	_hand.name = "HandAttachment"
	_hand.bone_name = "hand.r"
	_skeleton.add_child(_hand)


func _apply_materials() -> void:
	for index in range(_meshes.size()):
		var mesh_instance := _meshes[index]
		var bases: Array = _surface_bases[index]
		for surface in range(bases.size()):
			var base: Material = bases[surface]
			if _burning:
				mesh_instance.set_surface_override_material(surface, _burn_material(base))
			elif _tint != Color.WHITE:
				mesh_instance.set_surface_override_material(surface, _tinted_material(base, _tint))
			else:
				mesh_instance.set_surface_override_material(surface, null)


func _tinted_material(base: Material, tint: Color) -> Material:
	if base == null:
		return null
	var key := "%d:%s" % [base.get_instance_id(), tint.to_html()]
	if _material_cache.has(key):
		return _material_cache[key]
	var copy := base.duplicate() as StandardMaterial3D
	if copy != null:
		copy.albedo_color = copy.albedo_color * tint
	_material_cache[key] = copy
	return copy


func _burn_material(base: Material) -> Material:
	if base == null:
		return null
	var key := "%d:burn" % base.get_instance_id()
	if _material_cache.has(key):
		return _material_cache[key]
	var copy := base.duplicate() as StandardMaterial3D
	if copy != null:
		copy.albedo_color = copy.albedo_color * Color(1.0, 0.55, 0.3)
		copy.emission_enabled = true
		copy.emission = Color(1.0, 0.25, 0.05)
		copy.emission_energy_multiplier = 2.2
	_material_cache[key] = copy
	return copy
