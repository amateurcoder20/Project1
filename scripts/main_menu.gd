extends Node3D
## Main menu: 3D board backdrop + Local 2P / Vs AI / Quit.

var _board: BoardView
var _world: Node3D


func _ready() -> void:
	randomize()
	WorldLook.add_environment(self)
	WorldLook.add_lights(self)
	WorldLook.add_camera(self, Vector3(0.4, 6.4, 7.2), Vector3(0, 0.2, 0))

	_world = Node3D.new()
	_world.name = "Spin"
	add_child(_world)
	_board = BoardView.new()
	_board.configure(false)
	_world.add_child(_board)
	_board.build()
	_place_preview_pieces()
	_build_ui()


func _process(delta: float) -> void:
	if _world:
		_world.rotate_y(delta * 0.18)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


func _place_preview_pieces() -> void:
	var layout := {
		0: GameLogic.KNIGHT,
		2: GameLogic.QUEEN,
		5: GameLogic.QUEEN,
		10: GameLogic.KNIGHT,
		15: GameLogic.QUEEN,
		12: GameLogic.KNIGHT,
	}
	for index in layout:
		var piece := _board.spawn_piece(index, layout[index])
		piece.position = _board.cell_position(index)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.02, 0.01, 0.38)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 48
	box.offset_right = -48
	box.offset_top = 64
	box.offset_bottom = -48
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)

	box.add_child(UIKit.make_title("Knights vs Queens", 48))
	var subtitle := UIKit.make_body("4×4 tic-tac-toe  ·  four in a row", 22)
	box.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 28)
	box.add_child(spacer)

	var local_btn := UIKit.make_button("Local 2-Player")
	local_btn.pressed.connect(_start_game.bind(false))
	box.add_child(local_btn)

	var ai_btn := UIKit.make_button("Vs AI")
	ai_btn.pressed.connect(_start_game.bind(true))
	box.add_child(ai_btn)

	var quit_btn := UIKit.make_button("Quit")
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit_btn)

	var hint := UIKit.make_body("Knights move first. Queens are player 2 / the AI.", 18)
	box.add_child(hint)


func _start_game(vs_ai: bool) -> void:
	GameSession.vs_ai = vs_ai
	get_tree().change_scene_to_file("res://scenes/game.tscn")
