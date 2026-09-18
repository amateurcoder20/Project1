extends Node3D
## Match scene: tap cells, alternate turns, AI as Queens, win/draw overlay.
## 3D board lives in a SubViewport inset for HUD / safe-area so edges never clip.

var _logic: GameLogic
var _ai: TicTacAI
var _board: BoardView
var _world: Node3D
var _cam: Camera3D
var _sv: SubViewport
var _sv_container: SubViewportContainer
var _sv_margins: MarginContainer
var _turn_label: Label
var _overlay: Control
var _overlay_title: Label
var _overlay_body: Label
var _busy := false
var _hover_index := -1
var _insets := Vector4(28, 148, 28, 176)


func _ready() -> void:
	randomize()
	var size: int = BoardPreset.clamp_size(GameSession.board_size)
	GameSession.board_size = size
	_logic = GameLogic.new(size, BoardPreset.win_length(size))
	_ai = TicTacAI.new()

	_insets = _hud_insets()
	_build_3d_host()
	_build_hud()
	call_deferred("_sync_sv_size")
	get_tree().root.size_changed.connect(_sync_sv_size)
	_update_turn_label()


func _process(_delta: float) -> void:
	if _board == null:
		return
	if _busy or _logic.is_game_over():
		_board.set_hover(-1)
		return
	_update_hover()


func _unhandled_input(event: InputEvent) -> void:
	if _busy or _logic.is_game_over():
		return
	if GameSession.vs_ai and _logic.current_player == GameLogic.QUEEN:
		return
	var tap := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			tap = true
			pos = mb.position
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			tap = true
			pos = st.position
	if not tap:
		return
	var index := _cell_at(pos)
	if index >= 0 and _logic.is_legal(index):
		_busy = true
		get_viewport().set_input_as_handled()
		await _play_human_move(index)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_menu()


func _cell_pitch() -> float:
	return 6.2 / float(_logic.size)


func _build_3d_host() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)

	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(host)

	# MarginContainer (not Control offsets) so the 3D view sits in the HUD-safe hole.
	_sv_margins = MarginContainer.new()
	_sv_margins.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sv_margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(_sv_margins)
	_apply_sv_insets()

	_sv_container = SubViewportContainer.new()
	_sv_container.stretch = true
	_sv_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sv_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sv_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sv_margins.add_child(_sv_container)

	_sv = SubViewport.new()
	_sv.own_world_3d = true
	_sv.transparent_bg = false
	_sv.handle_input_locally = false
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.msaa_3d = Viewport.MSAA_2X
	_sv.size = Vector2i(512, 512)
	_sv_container.add_child(_sv)

	_world = Node3D.new()
	_sv.add_child(_world)

	var pitch := _cell_pitch()
	_board = BoardView.new()
	_board.configure(true, _logic.size, pitch)
	_world.add_child(_board)
	_board.build()

	WorldLook.add_environment(_world)
	WorldLook.add_lights(_world, _board.board_half())
	_cam = WorldLook.add_camera(_world)
	_reframe()


func _apply_sv_insets() -> void:
	if _sv_margins == null:
		return
	_sv_margins.add_theme_constant_override("margin_left", int(round(_insets.x)))
	_sv_margins.add_theme_constant_override("margin_top", int(round(_insets.y)))
	_sv_margins.add_theme_constant_override("margin_right", int(round(_insets.z)))
	_sv_margins.add_theme_constant_override("margin_bottom", int(round(_insets.w)))


func _sync_sv_size() -> void:
	_insets = _hud_insets()
	_apply_sv_insets()
	if _sv_container == null or _sv == null:
		return
	var r := _sv_container.get_global_rect().size
	var sz := Vector2i(maxi(64, int(r.x)), maxi(64, int(r.y)))
	if _sv.size != sz:
		_sv.size = sz
	_reframe()


func _reframe() -> void:
	if _cam == null or _board == null:
		return
	var aspect := 0.56
	if _sv != null and _sv.size.y > 0:
		aspect = float(_sv.size.x) / float(_sv.size.y)
	WorldLook.frame_board(_cam, _board.board_half(), _cell_pitch() * 1.4, aspect)


func _hud_insets() -> Vector4:
	var vp := get_viewport().get_visible_rect().size
	var top := 148.0
	var bottom := 176.0
	var side := 28.0
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.x > 0 and win.y > 0 and safe.size != Vector2i.ZERO:
		var sx := vp.x / float(win.x)
		var sy := vp.y / float(win.y)
		top = maxf(top, float(safe.position.y) * sy + 24.0)
		bottom = maxf(bottom, float(win.y - safe.end.y) * sy + 28.0)
		side = maxf(side, float(safe.position.x) * sx + 16.0)
	return Vector4(side, top, side, bottom)


func _cell_at(screen_pos: Vector2) -> int:
	if _sv == null or _cam == null:
		return -1
	var rect := _sv_container.get_global_rect()
	if not rect.has_point(screen_pos) or rect.size.x < 1.0 or rect.size.y < 1.0:
		return -1
	var local: Vector2 = (screen_pos - rect.position) / rect.size * Vector2(_sv.size)
	var from := _cam.project_ray_origin(local)
	var to := from + _cam.project_ray_normal(local) * 200.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	var hit := _world.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not hit.collider.has_meta("cell_index"):
		return -1
	return int(hit.collider.get_meta("cell_index"))


func _play_human_move(index: int) -> void:
	_board.set_hover(-1)
	await _place_and_commit(index)
	if _logic.is_game_over():
		_show_overlay_for_result()
		_busy = false
		return
	if GameSession.vs_ai:
		_turn_label.text = "Queens thinking…"
		var think := 0.22 if _logic.size >= 8 else 0.36
		await get_tree().create_timer(think).timeout
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
	piece.position = dest + Vector3(0, _cell_pitch() * 1.35, 0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(piece, "position", dest, 0.28)
	await tween.finished
	_logic.place(index)
	if not _logic.is_game_over():
		_logic.switch_player()
		_update_turn_label()


func _show_overlay_for_result() -> void:
	var w: int = _logic.winner()
	var n: int = _logic.win_length
	if w != GameLogic.EMPTY:
		_board.highlight_win(_logic.winning_line())
		_overlay_title.text = "%s win!" % GameLogic.player_name(w)
		if GameSession.vs_ai:
			_overlay_body.text = "%d in a row." % n if w == GameLogic.KNIGHT else "The AI connected %d Queens." % n
		else:
			_overlay_body.text = "%d in a row — horizontal, vertical, or diagonal." % n
		_turn_label.text = _overlay_title.text
	else:
		_overlay_title.text = "Draw"
		_overlay_body.text = "The %s board is full with no line of %d." % [BoardPreset.short_label(_logic.size), n]
		_turn_label.text = "Draw"
	_overlay.visible = true


func _update_turn_label() -> void:
	if _logic.is_game_over():
		return
	var preset := BoardPreset.label(_logic.size)
	if GameSession.vs_ai and _logic.current_player == GameLogic.QUEEN:
		_turn_label.text = "Queens thinking…  ·  %s" % preset
		return
	if _logic.current_player == GameLogic.KNIGHT:
		_turn_label.text = "Knights to move  ·  %s" % preset
	else:
		_turn_label.text = "Queens to move  ·  %s" % preset


func _restart() -> void:
	_overlay.visible = false
	_logic.reset()
	_board.clear_pieces()
	_busy = false
	_update_turn_label()


func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _update_hover() -> void:
	var mouse := get_viewport().get_mouse_position()
	_hover_index = _cell_at(mouse)
	if _hover_index >= 0 and _logic.is_legal(_hover_index):
		_board.set_hover(_hover_index)
	else:
		_hover_index = -1
		_board.set_hover(-1)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var top := MarginContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = _insets.y
	top.add_theme_constant_override("margin_left", int(_insets.x) + 8)
	top.add_theme_constant_override("margin_right", int(_insets.z) + 8)
	top.add_theme_constant_override("margin_top", 10)
	top.add_theme_constant_override("margin_bottom", 6)
	root.add_child(top)

	var turn_panel := PanelContainer.new()
	turn_panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.12, 0.07, 0.04, 0.78), Color(0.62, 0.42, 0.22)))
	top.add_child(turn_panel)
	_turn_label = UIKit.make_title("Knights to move", 24)
	_turn_label.add_theme_font_size_override("font_size", 22)
	_turn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	turn_panel.add_child(_turn_label)

	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -_insets.w
	bottom.offset_left = _insets.x
	bottom.offset_right = -_insets.z
	bottom.offset_bottom = -10.0
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 16)
	root.add_child(bottom)

	var restart_btn := UIKit.make_button("Restart", Vector2(240, 60))
	restart_btn.pressed.connect(_restart)
	bottom.add_child(restart_btn)
	var menu_btn := UIKit.make_button("Menu", Vector2(240, 60))
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
	_overlay_body = UIKit.make_body("Three in a row.", 20)
	col.add_child(_overlay_body)

	var again := UIKit.make_button("Play Again", Vector2(360, 64))
	again.pressed.connect(_restart)
	col.add_child(again)
	var to_menu := UIKit.make_button("Main Menu", Vector2(360, 64))
	to_menu.pressed.connect(_on_menu)
	col.add_child(to_menu)
