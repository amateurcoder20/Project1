extends Node3D
## Main menu: pick a board preset, then Local 2P / Vs AI / Quit.

var _board: BoardView
var _world: Node3D
var _cam: Camera3D
var _subtitle: Label
var _preset_buttons: Array[Button] = []


func _ready() -> void:
	randomize()
	GameSession.board_size = BoardPreset.clamp_size(GameSession.board_size)
	WorldLook.add_environment(self)
	_world = Node3D.new()
	_world.name = "Spin"
	add_child(_world)
	_cam = WorldLook.add_camera(self)
	_rebuild_preview()
	_build_ui()


func _process(delta: float) -> void:
	if _world:
		_world.rotate_y(delta * 0.16)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


func _rebuild_preview() -> void:
	if _board:
		_board.queue_free()
		_board = null
	# Drop leftover lights from a previous size.
	for child in get_children():
		if child is Light3D:
			child.queue_free()

	var size: int = GameSession.board_size
	var pitch := 6.2 / float(size)
	_board = BoardView.new()
	_board.configure(false, size, pitch)
	_world.add_child(_board)
	_board.build()
	_place_preview_pieces()
	WorldLook.add_lights(self, _board.board_half())
	var vp := get_viewport().get_visible_rect().size
	var aspect := 0.56 if vp.y < 1.0 else vp.x / vp.y
	# Menu is a closer hero shot; still keep the whole board in frame.
	WorldLook.frame_board(_cam, _board.board_half(), pitch * 1.4, aspect)


func _place_preview_pieces() -> void:
	var n: int = GameSession.board_size
	var spots: Array[int] = []
	if n <= 3:
		spots = [0, 4, 8, 2]
	elif n <= 5:
		spots = [0, 6, 12, 18, 24, 4]
	else:
		spots = [0, 9, 27, 36, 54, 63, 7]
	var players: Array[int] = [GameLogic.KNIGHT, GameLogic.QUEEN]
	var p := 0
	for index in spots:
		if index < n * n:
			var piece := _board.spawn_piece(index, players[p % 2])
			piece.position = _board.cell_position(index)
			p += 1


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.04, 0.02, 0.01, 0.16)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 28
	top.offset_right = -28
	top.offset_top = 36
	top.offset_bottom = 280
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)

	top.add_child(UIKit.make_title("Knights vs Queens", 42))
	_subtitle = UIKit.make_body(BoardPreset.label(GameSession.board_size), 20)
	top.add_child(_subtitle)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	top.add_child(row)
	_preset_buttons.clear()
	for s in BoardPreset.SIZES:
		var b := UIKit.make_choice_button(BoardPreset.label(s))
		var size_captured: int = s
		b.pressed.connect(_on_preset.bind(size_captured))
		row.add_child(b)
		_preset_buttons.append(b)
	_refresh_preset_buttons()

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 40
	bottom.offset_right = -40
	bottom.offset_top = -340
	bottom.offset_bottom = -36
	bottom.add_theme_constant_override("separation", 14)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom)

	var local_btn := UIKit.make_button("Local 2-Player")
	local_btn.pressed.connect(_start_game.bind(false))
	bottom.add_child(local_btn)

	var ai_btn := UIKit.make_button("Vs AI")
	ai_btn.pressed.connect(_start_game.bind(true))
	bottom.add_child(ai_btn)

	var quit_btn := UIKit.make_button("Quit")
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	bottom.add_child(quit_btn)

	var hint := UIKit.make_body("Knights move first. Queens are player 2 / the AI. Both modes work on every board.", 16)
	bottom.add_child(hint)


func _on_preset(size: int) -> void:
	GameSession.board_size = BoardPreset.clamp_size(size)
	_subtitle.text = BoardPreset.label(GameSession.board_size)
	_refresh_preset_buttons()
	_rebuild_preview()


func _refresh_preset_buttons() -> void:
	for i in _preset_buttons.size():
		UIKit.apply_choice_selected(_preset_buttons[i], BoardPreset.SIZES[i] == GameSession.board_size)


func _start_game(vs_ai: bool) -> void:
	GameSession.vs_ai = vs_ai
	get_tree().change_scene_to_file("res://scenes/game.tscn")
