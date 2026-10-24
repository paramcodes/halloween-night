class_name Palette
extends RefCounted
## Three-hue palette: cold slate, warm amber, dark wood. Materials are shared,
## so draw-call batching stays possible and zombies cost no extra materials.

const SLATE := Color("4a5e70")
const SLATE_DARK := Color("2c3a47")
const SLATE_LIGHT := Color("607890")
const AMBER := Color("e8a34a")
const AMBER_HOT := Color("ffd27a")
const WOOD := Color("5e4834")
const WOOD_LIGHT := Color("8a6c4a")
const BONE := Color("b8a07a")
const BLOOD := Color("6b2f2a")
const ZOMBIE_FLESH := Color("6d7a56")
const RUNNER_FLESH := Color("7d5334")
const BRUTE_FLESH := Color("4b4038")
const MOON := Color("6e8bc4")

static var _cache: Dictionary = {}


static func material(key: String) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	match key:
		"ground":
			mat.albedo_color = Color("363b32")
			mat.roughness = 1.0
		"street":
			mat.albedo_color = Color("44443a")
			mat.roughness = 0.95
		"wall":
			mat.albedo_color = SLATE
			mat.roughness = 0.9
		"wall_alt":
			mat.albedo_color = SLATE_DARK
			mat.roughness = 0.9
		"roof":
			mat.albedo_color = Color("2e3642")
			mat.roughness = 0.85
		"wood":
			mat.albedo_color = WOOD
			mat.roughness = 0.95
		"plank":
			mat.albedo_color = WOOD_LIGHT
			mat.roughness = 0.9
		"door":
			mat.albedo_color = Color("5a3d26")
			mat.roughness = 0.9
		"stone":
			mat.albedo_color = Color("3a3d3a")
			mat.roughness = 1.0
		"window":
			mat.albedo_color = AMBER
			mat.emission_enabled = true
			mat.emission = AMBER
			mat.emission_energy_multiplier = 3.0
			mat.roughness = 0.6
		"zombie":
			mat.albedo_color = ZOMBIE_FLESH
			mat.roughness = 1.0
		"runner":
			mat.albedo_color = RUNNER_FLESH
			mat.roughness = 1.0
		"brute":
			mat.albedo_color = BRUTE_FLESH
			mat.roughness = 1.0
		"zombie_burning":
			mat.albedo_color = Color("8a3a1c")
			mat.emission_enabled = true
			mat.emission = Color("ff7a2a")
			mat.emission_energy_multiplier = 2.4
			mat.roughness = 1.0
		"villager":
			mat.albedo_color = BONE
			mat.roughness = 1.0
		"villager_alt":
			mat.albedo_color = Color("9c8a6a")
			mat.roughness = 1.0
		"player":
			mat.albedo_color = Color("3d5060")
			mat.roughness = 0.8
		"flame_core":
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.vertex_color_use_as_albedo = true
			mat.albedo_color = AMBER_HOT
			mat.emission_enabled = true
			mat.emission = AMBER_HOT
			mat.emission_energy_multiplier = 4.0
		"smoke":
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.vertex_color_use_as_albedo = true
			mat.albedo_color = Color(0.15, 0.14, 0.13, 0.5)
		_:
			mat.albedo_color = Color.MAGENTA
	_cache[key] = mat
	return mat


static func emissive_window_material() -> StandardMaterial3D:
	return material("window")
