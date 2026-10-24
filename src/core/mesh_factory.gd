class_name MeshFactory
extends RefCounted
## Shared primitive meshes. One merged surface per actor keeps zombies at one
## draw call each and costs no skinning we do not have assets for yet.

static var _cache: Dictionary = {}


static func humanoid(kind: String) -> ArrayMesh:
	var key := "humanoid_" + kind
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"brute":
			_add_body(st, 0.52, 2.1, 0.42)
			_add_head(st, 0.26, 1.95)
			_add_arms(st, 0.16, 0.9, 0.55, 1.35, 22.0)
		"runner":
			_add_body(st, 0.28, 1.75, 0.42)
			_add_head(st, 0.16, 1.6)
			_add_arms(st, 0.09, 0.62, 0.2, 1.25, -55.0)
		"villager":
			_add_body(st, 0.3, 1.7, 0.42)
			_add_head(st, 0.17, 1.55)
			_add_arms(st, 0.09, 0.6, 0.55, 1.15, 12.0)
		"player":
			_add_body(st, 0.32, 1.8, 0.44)
			_add_head(st, 0.17, 1.62)
			_add_arms(st, 0.1, 0.65, 0.62, 1.28, 35.0)
		_:
			_add_body(st, 0.32, 1.8, 0.42)
			_add_head(st, 0.17, 1.62)
			_add_arms(st, 0.1, 0.66, 0.5, 1.32, 30.0)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


static func box(size: Vector3) -> BoxMesh:
	var key := "box_%.2f_%.2f_%.2f" % [size.x, size.y, size.z]
	if _cache.has(key):
		return _cache[key]
	var mesh := BoxMesh.new()
	mesh.size = size
	_cache[key] = mesh
	return mesh


static func cylinder(radius: float, height: float) -> CylinderMesh:
	var key := "cyl_%.2f_%.2f" % [radius, height]
	if _cache.has(key):
		return _cache[key]
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.9
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	_cache[key] = mesh
	return mesh


static func sphere(radius: float) -> SphereMesh:
	var key := "sphere_%.2f" % radius
	if _cache.has(key):
		return _cache[key]
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	_cache[key] = mesh
	return mesh


static func plane(size: Vector2, subdivide := 8) -> PlaneMesh:
	var key := "plane_%.1f_%.1f_%d" % [size.x, size.y, subdivide]
	if _cache.has(key):
		return _cache[key]
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.subdivide_width = subdivide
	mesh.subdivide_depth = subdivide
	_cache[key] = mesh
	return mesh


static func prop_mesh(kind: String) -> ArrayMesh:
	var key := "prop_" + kind
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"crate":
			_append_box(st, Vector3(0.9, 0.9, 0.9), Vector3(0, 0.45, 0))
			_append_box(st, Vector3(0.95, 0.12, 0.12), Vector3(0, 0.75, 0.47))
		"barrel":
			st.append_from(cylinder(0.38, 1.0), 0, Transform3D(Basis(), Vector3(0, 0.5, 0)))
		"cart":
			_append_box(st, Vector3(2.0, 0.5, 1.1), Vector3(0, 0.65, 0))
			_append_box(st, Vector3(0.12, 0.9, 0.12), Vector3(-0.8, 0.45, 0.5))
			_append_box(st, Vector3(0.12, 0.9, 0.12), Vector3(0.8, 0.45, 0.5))
			st.append_from(
				cylinder(0.42, 0.12),
				0,
				Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0), Vector3(-0.7, 0.42, 0))
			)
			st.append_from(
				cylinder(0.42, 0.12),
				0,
				Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0), Vector3(0.7, 0.42, 0))
			)
		"hay":
			st.append_from(
				cylinder(0.85, 1.1),
				0,
				Transform3D(Basis(Vector3(1, 0, 0), PI / 2.0), Vector3(0, 0.85, 0))
			)
		"post":
			_append_box(st, Vector3(0.16, 2.4, 0.16), Vector3(0, 1.2, 0))
			_append_box(st, Vector3(0.9, 0.1, 0.1), Vector3(0.35, 2.2, 0))
		"well":
			st.append_from(cylinder(1.2, 0.9), 0, Transform3D(Basis(), Vector3(0, 0.45, 0)))
			_append_box(st, Vector3(0.16, 1.6, 0.16), Vector3(-0.9, 1.4, 0))
			_append_box(st, Vector3(0.16, 1.6, 0.16), Vector3(0.9, 1.4, 0))
			_append_box(st, Vector3(2.0, 0.12, 0.12), Vector3(0, 2.2, 0))
		"fence":
			_append_box(st, Vector3(2.4, 0.12, 0.12), Vector3(0, 1.0, 0))
			_append_box(st, Vector3(2.4, 0.12, 0.12), Vector3(0, 0.55, 0))
			_append_box(st, Vector3(0.14, 1.2, 0.14), Vector3(-1.1, 0.6, 0))
			_append_box(st, Vector3(0.14, 1.2, 0.14), Vector3(1.1, 0.6, 0))
		"bench":
			_append_box(st, Vector3(1.8, 0.12, 0.5), Vector3(0, 0.45, 0))
			_append_box(st, Vector3(0.14, 0.45, 0.45), Vector3(-0.7, 0.22, 0))
			_append_box(st, Vector3(0.14, 0.45, 0.45), Vector3(0.7, 0.22, 0))
		_:
			_append_box(st, Vector3(0.8, 0.8, 0.8), Vector3(0, 0.4, 0))
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


static func quad(size: Vector2) -> QuadMesh:
	var key := "quad_%.2f_%.2f" % [size.x, size.y]
	if _cache.has(key):
		return _cache[key]
	var mesh := QuadMesh.new()
	mesh.size = size
	_cache[key] = mesh
	return mesh


static func _add_body(st: SurfaceTool, radius: float, height: float, center_ratio: float) -> void:
	var body := CapsuleMesh.new()
	body.radius = radius
	body.height = height * 0.7
	body.radial_segments = 10
	var pos := Vector3(0, height * center_ratio, 0)
	st.append_from(body, 0, Transform3D(Basis(), pos))


static func _add_head(st: SurfaceTool, radius: float, y: float) -> void:
	var head := SphereMesh.new()
	head.radius = radius
	head.height = radius * 1.9
	head.radial_segments = 10
	head.rings = 6
	st.append_from(head, 0, Transform3D(Basis(), Vector3(0, y, 0)))


static func _add_arms(
	st: SurfaceTool, radius: float, length: float, spread: float, y: float, angle_deg: float
) -> void:
	var arm := CapsuleMesh.new()
	arm.radius = radius
	arm.height = length
	arm.radial_segments = 8
	var left := Basis(Vector3.BACK, deg_to_rad(angle_deg))
	var right := Basis(Vector3.BACK, deg_to_rad(-angle_deg))
	st.append_from(arm, 0, Transform3D(left, Vector3(-spread, y, 0)))
	st.append_from(arm, 0, Transform3D(right, Vector3(spread, y, 0)))


static func _append_box(st: SurfaceTool, size: Vector3, offset: Vector3) -> void:
	st.append_from(box(size), 0, Transform3D(Basis(), offset))
