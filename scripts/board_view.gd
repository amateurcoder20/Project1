class_name BoardView
extends Node3D
## Warm wood/marble N×N board with ray-pickable cells.

signal cell_pressed(index: int)

const BOARD_Y := 0.08

var size: int = 3
var cell: float = 1.08
var square: float = 1.0
var piece_scale: float = 0.92
var squares: Array[MeshInstance3D] = []
var pieces: Array[Node3D] = []
var _hover: MeshInstance3D
var _light_mat: StandardMaterial3D
var _dark_mat: StandardMaterial3D
var _win_mat: StandardMaterial3D
var _hover_mat: StandardMaterial3D
var _interactive := true


func configure(interactive: bool, p_size: int = 3, p_cell: float = 1.08) -> void:
	_interactive = interactive
	size = p_size
	cell = p_cell
	square = p_cell * 0.92
	piece_scale = (p_cell / 1.08) * 0.90


func board_half() -> float:
	## Half-extent of squares + wooden frame, in world units.
	return (float(size) * 0.5) * cell + 0.28


func build() -> void:
	_make_materials()
	_build_table()
	_build_frame()
	_build_squares()
	_build_hover()
	var n: int = size * size
	pieces.resize(n)
	for i in n:
		pieces[i] = null


func cell_position(index: int) -> Vector3:
	var row: int = int(index / float(size))
	var col: int = index % size
	var origin := (float(size) - 1.0) * 0.5
	return Vector3((col - origin) * cell, BOARD_Y + 0.05, (row - origin) * cell)


func clear_pieces() -> void:
	for i in pieces.size():
		if pieces[i] != null:
			pieces[i].queue_free()
			pieces[i] = null
	_restore_square_colors()
	if _hover:
		_hover.visible = false


func spawn_piece(index: int, player: int) -> Node3D:
	var piece: Node3D = PieceFactory.make_knight() if player == GameLogic.KNIGHT else PieceFactory.make_queen()
	if player == GameLogic.KNIGHT:
		piece.rotation_degrees.y = 180
	piece.scale = Vector3.ONE * piece_scale
	add_child(piece)
	var dest := cell_position(index)
	piece.position = dest + Vector3(0, cell * 1.25, 0)
	pieces[index] = piece
	return piece


func highlight_win(line: Array) -> void:
	for i in line:
		if int(i) >= 0 and int(i) < squares.size():
			squares[int(i)].material_override = _win_mat


func set_hover(index: int) -> void:
	if index < 0 or not _interactive or _hover == null:
		if _hover:
			_hover.visible = false
		return
	_hover.visible = true
	var p := cell_position(index)
	_hover.position = Vector3(p.x, BOARD_Y + 0.07, p.z)


func _build_table() -> void:
	var span := board_half() * 2.0 + 1.8
	var table_mat := _wood(Color(0.22, 0.12, 0.07), 0.72)
	var table := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(span, 0.18, span)
	table.mesh = mesh
	table.material_override = table_mat
	table.position = Vector3(0, -0.12, 0)
	table.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(table)

	var felt := MeshInstance3D.new()
	var felt_mesh := BoxMesh.new()
	var felt_span := board_half() * 2.0 + 0.55
	felt_mesh.size = Vector3(felt_span, 0.03, felt_span)
	felt.mesh = felt_mesh
	felt.material_override = _wood(Color(0.16, 0.09, 0.05), 0.85)
	felt.position = Vector3(0, -0.01, 0)
	add_child(felt)


func _build_frame() -> void:
	var frame_mat := _wood(Color(0.28, 0.15, 0.08), 0.5)
	var thickness := clampf(cell * 0.22, 0.12, 0.28)
	var outer := float(size) * cell + thickness * 0.15
	_frame_bar(frame_mat, Vector3(0, BOARD_Y - 0.02, -outer * 0.5), Vector3(outer + thickness, 0.22, thickness))
	_frame_bar(frame_mat, Vector3(0, BOARD_Y - 0.02, outer * 0.5), Vector3(outer + thickness, 0.22, thickness))
	_frame_bar(frame_mat, Vector3(-outer * 0.5, BOARD_Y - 0.02, 0), Vector3(thickness, 0.22, outer))
	_frame_bar(frame_mat, Vector3(outer * 0.5, BOARD_Y - 0.02, 0), Vector3(thickness, 0.22, outer))


func _frame_bar(mat: Material, pos: Vector3, bar_size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = bar_size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func _build_squares() -> void:
	squares.clear()
	for row in size:
		for col in size:
			var index := row * size + col
			var light := (row + col) % 2 == 0
			var mar: StandardMaterial3D = _light_mat if light else _dark_mat
			var mi := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(square, 0.10, square)
			mi.mesh = mesh
			mi.material_override = mar
			mi.position = cell_position(index) + Vector3(0, -0.02, 0)
			add_child(mi)
			squares.append(mi)

			if _interactive:
				var body := StaticBody3D.new()
				body.position = cell_position(index)
				body.set_meta("cell_index", index)
				body.collision_layer = 1
				body.collision_mask = 0
				body.input_ray_pickable = true
				var shape := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(square * 0.98, maxf(0.4, cell * 0.55), square * 0.98)
				shape.shape = box
				body.add_child(shape)
				add_child(body)


func _build_hover() -> void:
	_hover = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(square * 0.92, 0.02, square * 0.92)
	_hover.mesh = mesh
	_hover.material_override = _hover_mat
	_hover.visible = false
	add_child(_hover)


func _restore_square_colors() -> void:
	for i in squares.size():
		var row: int = int(i / float(size))
		var col: int = i % size
		squares[i].material_override = _light_mat if (row + col) % 2 == 0 else _dark_mat


func _make_materials() -> void:
	_light_mat = _wood(Color(0.90, 0.82, 0.66), 0.42)
	_light_mat.metallic = 0.04
	_dark_mat = _wood(Color(0.46, 0.28, 0.15), 0.50)
	_win_mat = _wood(Color(0.78, 0.58, 0.22), 0.35)
	_win_mat.emission_enabled = true
	_win_mat.emission = Color(0.85, 0.6, 0.15)
	_win_mat.emission_energy_multiplier = 0.55
	_hover_mat = StandardMaterial3D.new()
	_hover_mat.albedo_color = Color(1.0, 0.86, 0.45, 0.45)
	_hover_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hover_mat.emission_enabled = true
	_hover_mat.emission = Color(1.0, 0.8, 0.3)
	_hover_mat.emission_energy_multiplier = 0.4


static func _wood(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = 0.02
	return m
