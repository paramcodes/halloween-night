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
static var _puff: Texture2D


## Soft radial alpha for particle quads. A bare quad reads as a square once the
## plume is dense; this keeps each puff round with a feathered edge.
static func soft_puff() -> Texture2D:
	if _puff != null:
		return _puff
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var uv := (Vector2(float(x) + 0.5, float(y) + 0.5) / float(size)) - Vector2(0.5, 0.5)
			var falloff := clampf(1.0 - uv.length() * 2.0, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, falloff * falloff))
	_puff = ImageTexture.create_from_image(image)
	return _puff


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
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mat.vertex_color_use_as_albedo = true
			mat.albedo_texture = soft_puff()
			mat.albedo_color = Color(1.0, 0.55, 0.2)
			mat.emission_enabled = true
			mat.emission = AMBER_HOT
			mat.emission_energy_multiplier = 1.0
		"flame_edge":
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mat.vertex_color_use_as_albedo = true
			mat.albedo_texture = soft_puff()
			mat.albedo_color = Color(0.9, 0.35, 0.12)
			mat.emission_enabled = true
			mat.emission = Color("d05018")
			mat.emission_energy_multiplier = 0.6
		"smoke":
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.vertex_color_use_as_albedo = true
			mat.albedo_texture = soft_puff()
			mat.albedo_color = Color(0.15, 0.14, 0.13, 0.5)
		_:
			mat.albedo_color = Color.MAGENTA
	_cache[key] = mat
	return mat


static func emissive_window_material() -> StandardMaterial3D:
	return material("window")
