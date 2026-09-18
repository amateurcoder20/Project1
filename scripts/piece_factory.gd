class_name PieceFactory
extends RefCounted
## Low-poly chess knight / queen built from primitive meshes.

static var _knight_wood: StandardMaterial3D
static var _knight_dark: StandardMaterial3D
static var _queen_marble: StandardMaterial3D
static var _queen_gold: StandardMaterial3D


static func make_knight() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "Knight"

	_cyl(root, _knight_wood, Vector3(0, 0.06, 0), 0.30, 0.34, 0.10)
	_cyl(root, _knight_dark, Vector3(0, 0.14, 0), 0.22, 0.26, 0.08)

	# Chest / body of the horse, sitting on the pedestal.
	_box(root, _knight_wood, Vector3(0.02, 0.38, -0.02), Vector3(0.30, 0.36, 0.38), Vector3(0, 0, 0))

	# Neck leans toward +Z (snout direction).
	var neck := _cyl(root, _knight_wood, Vector3(0.0, 0.62, 0.12), 0.09, 0.11, 0.38)
	neck.rotation_degrees = Vector3(38, 0, 0)

	# Head
	_sphere(root, _knight_wood, Vector3(0.0, 0.86, 0.28), 0.15)
	# Snout
	_box(root, _knight_wood, Vector3(0.0, 0.80, 0.46), Vector3(0.14, 0.12, 0.24), Vector3(12, 0, 0))
	# Jaw
	_box(root, _knight_dark, Vector3(0.0, 0.72, 0.42), Vector3(0.11, 0.07, 0.16), Vector3(8, 0, 0))
	# Ears
	_box(root, _knight_dark, Vector3(-0.07, 1.02, 0.22), Vector3(0.05, 0.16, 0.07), Vector3(12, 0, -18))
	_box(root, _knight_dark, Vector3(0.07, 1.02, 0.22), Vector3(0.05, 0.16, 0.07), Vector3(12, 0, 18))
	# Mane
	_box(root, _knight_dark, Vector3(0.0, 0.70, 0.02), Vector3(0.06, 0.34, 0.10), Vector3(28, 0, 0))
	# Eye sockets
	_sphere(root, _knight_dark, Vector3(-0.09, 0.88, 0.34), 0.035)
	_sphere(root, _knight_dark, Vector3(0.09, 0.88, 0.34), 0.035)

	root.scale = Vector3.ONE * 0.92
	return root


static func make_queen() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "Queen"

	_cyl(root, _queen_marble, Vector3(0, 0.06, 0), 0.30, 0.34, 0.10)
	_cyl(root, _queen_gold, Vector3(0, 0.14, 0), 0.22, 0.24, 0.07)
	# Stem
	_cyl(root, _queen_marble, Vector3(0, 0.46, 0), 0.11, 0.14, 0.55)
	# Waist ring
	_cyl(root, _queen_gold, Vector3(0, 0.62, 0), 0.18, 0.18, 0.06)
	# Collar
	_cyl(root, _queen_marble, Vector3(0, 0.82, 0), 0.16, 0.20, 0.16)
	# Head
	_sphere(root, _queen_marble, Vector3(0, 0.98, 0), 0.16)
	# Crown band
	_cyl(root, _queen_gold, Vector3(0, 1.10, 0), 0.17, 0.17, 0.07)
	# Crown spikes
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var spike := _cone(root, _queen_gold, Vector3(cos(ang) * 0.13, 1.22, sin(ang) * 0.13), 0.035, 0.16)
		spike.rotation_degrees = Vector3(18 * cos(ang + PI * 0.5), 0, -18 * sin(ang + PI * 0.5))
	# Coronation orb
	_sphere(root, _queen_gold, Vector3(0, 1.30, 0), 0.055)

	root.scale = Vector3.ONE * 0.92
	return root


static func _ensure_materials() -> void:
	if _knight_wood != null:
		return
	_knight_wood = _mat(Color(0.42, 0.24, 0.12), 0.55, 0.08)
	_knight_dark = _mat(Color(0.18, 0.09, 0.05), 0.62, 0.04)
	_queen_marble = _mat(Color(0.93, 0.89, 0.82), 0.28, 0.12)
	_queen_gold = _mat(Color(0.86, 0.68, 0.28), 0.32, 0.72)


static func _mat(albedo: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = roughness
	m.metallic = metallic
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return m


static func _mesh_instance(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, mat: Material, pos: Vector3, top_r: float, bot_r: float, height: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bot_r
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	return _mesh_instance(parent, mesh, mat, pos)


static func _cone(parent: Node3D, mat: Material, pos: Vector3, radius: float, height: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.001
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	return _mesh_instance(parent, mesh, mat, pos)


static func _sphere(parent: Node3D, mat: Material, pos: Vector3, radius: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 8
	return _mesh_instance(parent, mesh, mat, pos)


static func _box(parent: Node3D, mat: Material, pos: Vector3, size: Vector3, rot_deg: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := _mesh_instance(parent, mesh, mat, pos)
	mi.rotation_degrees = rot_deg
	return mi
