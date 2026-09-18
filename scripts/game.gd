extends Node3D
## Match scene: tap cells, alternate turns, AI as Queens, win/draw overlay.

var _logic: GameLogic
var _ai: TicTacAI
var _board: BoardView
var _turn_label: Label
var _overlay: Control
var _overlay_title: Label
var _overlay_body: Label
var _busy := false
var _hover_index := -1


func _ready() -> void:
	randomize()
	_logic = GameLogic.new()
	_ai = TicTacAI.new()

	WorldLook.add_environment(self)
	WorldLook.add_lights(self)
	WorldLook.add_camera(self)

	_board = BoardView.new()
	_board.configure(true)
	add_child(_board)
	_board.build()
	_board.cell_pressed.connect(_on_cell_pressed)

	_build_hud()
	_update_turn_label()


func _process(_delta: float) -> void:
	if _busy or _logic.is_game_over():
		_board.set_hover(-1)
		return
	_update_hover()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_menu()


func _on_cell_pressed(index: int) -> void:
	if _busy or _logic.is_game_over():
		return
	if GameSession.vs_ai and _logic.current_player == GameLogic.QUEEN:
		return
	if not _logic.is_legal(index):
		return
	_busy = true
	await _play_human_move(index)


func _play_human_move(index: int) -> void:
	_board.set_hover(-1)
	await _place_and_commit(index)
	if _logic.is_game_over():
		_show_overlay_for_result()
		_busy = false
		return
	if GameSession.vs_ai:
		_turn_label.text = "Queens thinking…"
		await get_tree().create_timer(0.42).timeout
		var ai_move: int = _ai.choose_move(_logic)
		if ai_move >= 0 and _logic.is_legal(ai_move):
			await _place_and_commit(ai_move)
		if _logic.is_game_over():
			_show_overlay_for_result()
			_busy = false
			return
	_update_turn_label()
	_busy = false


func _place_and_commit(index: int) -> void:
	var player: int = _logic.current_player
	var piece := _board.spawn_piece(index, player)
	var dest := _board.cell_position(index)
	piece.position = dest + Vector3(0, 1.4, 0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(piece, "position", dest, 0.32)
	await tween.finished
	_logic.place(index)
	if not _logic.is_game_over():
		_logic.switch_player()
		_update_turn_label()


func _show_overlay_for_result() -> void:
	var w: int = _logic.winner()
	if w != GameLogic.EMPTY:
		_board.highlight_win(_logic.winning_line())
		_overlay_title.text = "%s win!" % GameLogic.player_name(w)
		if GameSession.vs_ai:
			_overlay_body.text = "Four in a row." if w == GameLogic.KNIGHT else "The AI connected four Queens."
		else:
			_overlay_body.text = "Four in a row — horizontal, vertical, or diagonal."
		_turn_label.text = _overlay_title.text
	else:
		_overlay_title.text = "Draw"
		_overlay_body.text = "The 4×4 board is full with no line of four."
		_turn_label.text = "Draw"
	_overlay.visible = true


func _update_turn_label() -> void:
	if _logic.is_game_over():
		return
	if GameSession.vs_ai and _logic.current_player == GameLogic.QUEEN:
		_turn_label.text = "Queens thinking…"
		return
	if _logic.current_player == GameLogic.KNIGHT:
		_turn_label.text = "Knights to move"
	else:
		_turn_label.text = "Queens to move"


func _restart() -> void:
	_overlay.visible = false
	_logic.reset()
	_board.clear_pieces()
	_busy = false
	_update_turn_label()


func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _update_hover() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var to := from + cam.project_ray_normal(mouse) * 80.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not hit.collider.has_meta("cell_index"):
		_hover_index = -1
		_board.set_hover(-1)
		return
	var index: int = hit.collider.get_meta("cell_index")
	if _logic.is_legal(index):
		_hover_index = index
		_board.set_hover(index)
	else:
		_hover_index = -1
		_board.set_hover(-1)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var top := MarginContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 140
	top.add_theme_constant_override("margin_left", 28)
	top.add_theme_constant_override("margin_right", 28)
	top.add_theme_constant_override("margin_top", 36)
	root.add_child(top)

	var turn_panel := PanelContainer.new()
	turn_panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.12, 0.07, 0.04, 0.78), Color(0.62, 0.42, 0.22)))
	top.add_child(turn_panel)
	_turn_label = UIKit.make_title("Knights to move", 28)
	_turn_label.add_theme_font_size_override("font_size", 28)
	turn_panel.add_child(_turn_label)

	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -140
	bottom.offset_left = 28
	bottom.offset_right = -28
	bottom.offset_bottom = -36
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 16)
	root.add_child(bottom)

	var restart_btn := UIKit.make_button("Restart", Vector2(240, 64))
	restart_btn.pressed.connect(_restart)
	bottom.add_child(restart_btn)
	var menu_btn := UIKit.make_button("Menu", Vector2(240, 64))
	menu_btn.pressed.connect(_on_menu)
	bottom.add_child(menu_btn)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.0, 0.55)
	_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -260
	panel.offset_right = 260
	panel.offset_top = -180
	panel.offset_bottom = 180
	panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.16, 0.09, 0.05, 0.96), Color(0.85, 0.65, 0.32)))
	_overlay.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)

	_overlay_title = UIKit.make_title("Knights win!", 40)
	col.add_child(_overlay_title)
	_overlay_body = UIKit.make_body("Four in a row.", 20)
	col.add_child(_overlay_body)

	var again := UIKit.make_button("Play Again", Vector2(360, 64))
	again.pressed.connect(_restart)
	col.add_child(again)
	var to_menu := UIKit.make_button("Main Menu", Vector2(360, 64))
	to_menu.pressed.connect(_on_menu)
	col.add_child(to_menu)
