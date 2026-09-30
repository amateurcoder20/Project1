extends Node3D
## Match scene: Classic drops, Courts pairs, Crown War score.
## 3D board lives in a SubViewport inset for HUD / safe-area so edges never clip.

signal handoff_closed

const _PICK_IDLE := 0
const _PICK_FIRST := 1
const _PICK_SECOND := 2
const _PICK_CONFIRM := 3

var _logic: GameLogic
var _ai: TicTacAI
var _board: BoardView
var _world: Node3D
var _cam: Camera3D
var _sv: SubViewport
var _sv_container: SubViewportContainer
var _sv_margins: MarginContainer
var _turn_label: Label
var _score_label: Label
var _power_btn: Button
var _confirm_btn: Button
var _pair_note: Label
var _help_btn: Button
var _result_sheet: PanelContainer
var _result_title: Label
var _result_body: Label
var _handoff: Control
var _hud_root: Control
var _tutorial: HowToPlay
var _top_bar: MarginContainer
var _bottom_bar: HBoxContainer
var _juice: MatchJuice
var _busy := false
var _scored := false
var _started := false
var _hover_index := -1
var _pick := _PICK_IDLE
var _pair_a := -1
var _pair_b := -1
var _ghost_key := ""
var _pair_used: Array[bool] = [false, false, false]
var _sheet_open := false
var _ai_thinking := false
var _think_phase := 0.0
var _insets := Vector4(28, 188, 28, 176)


func _ready() -> void:
	randomize()
	var size: int = BoardPreset.clamp_size(GameSession.board_size)
	if GameSession.is_courts() and size == 3:
		size = 5
	GameSession.board_size = size
	_logic = GameLogic.new(size, BoardPreset.win_length(size))
	_ai = TicTacAI.new()
	_juice = MatchJuice.new()
	add_child(_juice)

	_insets = _hud_insets()
	_build_3d_host()
	_build_hud()
	call_deferred("_sync_sv_size")
	get_tree().root.size_changed.connect(_sync_sv_size)
	_update_turn_label()
	_refresh_power_chip()
	if _powers_in_match() and not PlayerPrefs.has_seen_courts_hint():
		_open_tutorial()
	else:
		_begin_opening_turn()


func _process(delta: float) -> void:
	if _ai_thinking and _turn_label != null:
		_think_phase += delta
		var dots := ".".repeat(1 + int(_think_phase * 2.2) % 3)
		_turn_label.text = "%s is thinking%s" % [GameSession.rank_label(), dots]
		return
	if _board == null:
		return
	if _busy or _logic.is_game_over() or _card_open():
		_board.set_hover(-1)
		return
	_update_hover()


func _input(event: InputEvent) -> void:
	if _busy or _logic.is_game_over() or _card_open():
		return
	if not _is_human_turn():
		return
	var tap := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			tap = true
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			tap = true
	if not tap:
		return
	var index := _cell_at_pointer()
	if index < 0:
		return
	if _pick == _PICK_IDLE:
		if not _logic.is_legal(index):
			return
		_busy = true
		get_viewport().set_input_as_handled()
		_play_human_cells([index], false)
		return
	if not _logic.is_legal(index):
		return
	get_viewport().set_input_as_handled()
	_on_pair_tap(index)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_menu()


func _powers_in_match() -> bool:
	return GameSession.is_courts() and CourtsRules.powers_allowed(_logic.size, _logic.win_length)


func _is_human_turn() -> bool:
	if _logic == null or _logic.is_game_over():
		return false
	if not GameSession.vs_ai:
		return true
	return _logic.current_player == GameSession.human_player


func _card_open() -> bool:
	return (_handoff != null and _handoff.visible) or (_tutorial != null and _tutorial.visible)


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
	_layout_hud_edges()
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
	var top := 340.0 if _powers_in_match() else 176.0
	var bottom := 420.0 if _sheet_open else 168.0
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


func _layout_hud_edges() -> void:
	if _top_bar:
		_top_bar.offset_bottom = _insets.y
		_top_bar.add_theme_constant_override("margin_left", int(_insets.x) + 8)
		_top_bar.add_theme_constant_override("margin_right", int(_insets.z) + 8)
	if _bottom_bar:
		_bottom_bar.offset_top = -_insets.w
		_bottom_bar.offset_left = _insets.x
		_bottom_bar.offset_right = -_insets.z
	if _result_sheet:
		_result_sheet.offset_left = _insets.x
		_result_sheet.offset_right = -_insets.z


func _cell_at_pointer() -> int:
	if _sv == null or _cam == null or _sv_container == null or _board == null:
		return -1
	var local_mouse := _sv_container.get_local_mouse_position()
	var csize := _sv_container.size
	if csize.x < 1.0 or csize.y < 1.0:
		return -1
	if local_mouse.x < 0.0 or local_mouse.y < 0.0 or local_mouse.x > csize.x or local_mouse.y > csize.y:
		return -1
	var sv_pos := Vector2(
		local_mouse.x / csize.x * float(_sv.size.x),
		local_mouse.y / csize.y * float(_sv.size.y)
	)
	var origin := _cam.project_ray_origin(sv_pos)
	var dir := _cam.project_ray_normal(sv_pos)
	if absf(dir.y) < 0.0001:
		return -1
	var t := (BoardView.BOARD_Y - origin.y) / dir.y
	if t < 0.0:
		return -1
	var hit := origin + dir * t
	var n: int = _logic.size
	var mid := (float(n) - 1.0) * 0.5
	var pitch := _cell_pitch()
	var col := int(round(hit.x / pitch + mid))
	var row := int(round(hit.z / pitch + mid))
	if row < 0 or col < 0 or row >= n or col >= n:
		return -1
	var cx := (float(col) - mid) * pitch
	var cz := (float(row) - mid) * pitch
	if absf(hit.x - cx) > pitch * 0.5 or absf(hit.z - cz) > pitch * 0.5:
		return -1
	return row * n + col


func _begin_opening_turn() -> void:
	if _started:
		return
	_started = true
	if GameSession.vs_ai and _logic.current_player == GameSession.ai_player() and not _logic.is_game_over():
		_busy = true
		_opening_ai()


func _opening_ai() -> void:
	await _play_ai_turn()
	if _logic.is_game_over():
		_show_result()
	_update_turn_label()
	_refresh_power_chip()
	_busy = false


func _play_human_cells(indices: Array, powered: bool) -> void:
	_board.set_hover(-1)
	await _commit_cells(indices, powered)
	if _logic.is_game_over():
		_show_result()
		_busy = false
		return
	if not GameSession.vs_ai and not GameSession.skip_handoff:
		_show_handoff()
		await handoff_closed
	if GameSession.vs_ai and _logic.current_player == GameSession.ai_player():
		await _play_ai_turn()
		if _logic.is_game_over():
			_show_result()
			_busy = false
			return
	_update_turn_label()
	_refresh_power_chip()
	_busy = false


func _play_ai_turn() -> void:
	_ai_thinking = true
	_think_phase = 0.0
	_clear_pair_preview()
	_score_label.text = _thinking_blurb()
	var think := 0.42
	match GameSession.ai_rank:
		GameSession.AiRank.SQUIRE:
			think = 0.26
		GameSession.AiRank.REGENT:
			think = 0.58
	if _logic.size >= 8:
		think += 0.12
	await get_tree().create_timer(think).timeout
	var ai_side := GameSession.ai_player()
	var allow := _powers_in_match() and not _pair_used[ai_side]
	var opp_power := _powers_in_match() and not _pair_used[GameSession.human_player]
	var action: Dictionary = _ai.choose_action(_logic, GameSession.ai_rank, ai_side, allow, opp_power)
	_ai_thinking = false
	var cells: Array = action.get("cells", [])
	var powered := bool(action.get("power", false))
	if cells.is_empty():
		_score_label.text = GameSession.score_line()
		return
	if powered:
		if cells.size() < 2 or not CourtsRules.is_partner(_logic, _logic.cells, int(cells[0]), int(cells[1]), ai_side):
			powered = false
			cells = [int(cells[0])]
	await _commit_cells(cells, powered)
	_score_label.text = GameSession.score_line()


func _thinking_blurb() -> String:
	var side := GameLogic.player_name(GameSession.ai_player())
	match GameSession.ai_rank:
		GameSession.AiRank.SQUIRE:
			return "The Squire's %s glance across the board" % side
		GameSession.AiRank.REGENT:
			return "The Regent reads every %s line" % side
		_:
			return "The Marshal weighs the %s threats" % side


func _commit_cells(indices: Array, powered: bool) -> void:
	var player: int = _logic.current_player
	_clear_pair_preview()
	var placed := 0
	for raw in indices:
		var index := int(raw)
		if not _logic.is_legal(index):
			break
		await _drop_piece(index, player, powered and placed == 0)
		_logic.place(index)
		placed += 1
		if _logic.winner_from_move(_logic.cells, index) == player:
			break
	if powered and placed > 0:
		_pair_used[player] = true
	_pick = _PICK_IDLE
	_pair_a = -1
	_pair_b = -1
	if not _logic.is_game_over():
		_logic.switch_player()
	_update_turn_label()
	_refresh_power_chip()


func _drop_piece(index: int, player: int, powered: bool) -> void:
	var piece := _board.spawn_piece(index, player)
	var dest := _board.cell_position(index)
	var base_scale := piece.scale
	piece.position = dest + Vector3(0, _cell_pitch() * 1.35, 0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(piece, "position", dest, 0.22)
	await tween.finished
	piece.scale = Vector3(base_scale.x * 1.22, base_scale.y * 0.66, base_scale.z * 1.22)
	var squash := create_tween()
	squash.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	squash.tween_property(piece, "scale", base_scale, 0.14)
	if _juice:
		_juice.play_place(powered)
	await squash.finished


func _show_result() -> void:
	var w: int = _logic.winner()
	if not _scored:
		_scored = true
		GameSession.note_winner(w)
	var n: int = _logic.win_length
	var score := GameSession.score_line()
	if w != GameLogic.EMPTY:
		_board.highlight_win(_logic.winning_line())
		_bob_win_line(_logic.winning_line())
		if _juice:
			_juice.play_win()
		if GameSession.series_over():
			_result_title.text = "%s take the crown" % GameLogic.player_name(w)
		else:
			_result_title.text = "%s win!" % GameLogic.player_name(w)
		if GameSession.vs_ai and w == GameSession.ai_player():
			_result_body.text = "The %s connected %d.\n%s" % [GameSession.rank_label(), n, score]
		else:
			_result_body.text = "%d in a row.\n%s" % [n, score]
		_turn_label.text = _result_title.text
	else:
		_result_title.text = "Draw"
		_result_body.text = "No line of %d.\n%s" % [n, score]
		_turn_label.text = "Draw"
	_score_label.text = score
	_refresh_power_chip()
	_sheet_open = true
	_result_sheet.visible = true
	_bottom_bar.visible = false
	call_deferred("_sync_sv_size")


func _hide_result_sheet() -> void:
	_sheet_open = false
	if _result_sheet:
		_result_sheet.visible = false
	if _bottom_bar:
		_bottom_bar.visible = true
	call_deferred("_sync_sv_size")


func _bob_win_line(line: Array) -> void:
	var hop := _cell_pitch() * 0.22
	for cell in line:
		var piece: Node3D = _board.pieces[int(cell)]
		if piece == null:
			continue
		var base_y := piece.position.y
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(piece, "position:y", base_y + hop, 0.14)
		tw.tween_property(piece, "position:y", base_y, 0.16)
		tw.tween_property(piece, "position:y", base_y + hop * 0.45, 0.1)
		tw.tween_property(piece, "position:y", base_y, 0.14)


func _update_turn_label() -> void:
	if _logic.is_game_over():
		return
	var preset := "%s · %s" % [GameSession.mini_game_label(), BoardPreset.short_label(_logic.size)]
	var side := GameLogic.player_name(_logic.current_player)
	if GameSession.vs_ai:
		var who := "You" if _logic.current_player == GameSession.human_player else GameSession.rank_label()
		_turn_label.text = "%s · %s  ·  %s" % [who, side, preset]
	elif _logic.current_player == GameLogic.KNIGHT:
		_turn_label.text = "Knights to move  ·  %s" % preset
	else:
		_turn_label.text = "Queens to move  ·  %s" % preset
	if _score_label:
		_score_label.text = GameSession.score_line()


func _any_pair(player: int) -> bool:
	for i in _logic.cell_count:
		if not _logic.is_legal(i):
			continue
		if not CourtsRules.partners(_logic, _logic.cells, i, player).is_empty():
			return true
	return false


func _is_partner_cell(origin: int, index: int) -> bool:
	return CourtsRules.is_partner(_logic, _logic.cells, origin, index, _logic.current_player)


func _first_would_win() -> bool:
	if _pair_a < 0:
		return false
	var board := _logic.snapshot()
	board[_pair_a] = _logic.current_player
	return _logic.winner_from_move(board, _pair_a) == _logic.current_player


func _refresh_power_chip() -> void:
	if _power_btn == null:
		return
	if not _powers_in_match():
		_power_btn.visible = false
		_confirm_btn.visible = false
		_pair_note.visible = false
		_clear_pair_preview()
		return
	_power_btn.visible = true
	var player: int = _logic.current_player
	var label := CourtsRules.chip_label(player)
	var spent := _pair_used[player]
	var human := _is_human_turn()
	if _logic.is_game_over() or not human or spent or not _any_pair(player):
		if _pick != _PICK_IDLE:
			_pick = _PICK_IDLE
			_pair_a = -1
			_pair_b = -1
			_clear_pair_preview()
		_power_btn.text = ("%s used" % label) if spent else label
		_power_btn.disabled = true
		_confirm_btn.visible = false
		_pair_note.visible = false
		UIKit.apply_choice_selected(_power_btn, false)
		_board.set_pulse_cells([])
		return
	_power_btn.disabled = false
	if _pick == _PICK_IDLE:
		_power_btn.text = label
		_confirm_btn.visible = false
		_pair_note.visible = false
		_board.set_pulse_cells([])
	elif _pick == _PICK_FIRST:
		_power_btn.text = "Cancel · tap a square"
		_confirm_btn.visible = false
		_pair_note.text = "First square of the pair. The landing squares will glow."
		_pair_note.visible = true
		_board.set_pulse_cells([])
	elif _pick == _PICK_SECOND:
		_power_btn.text = "Cancel · tap the pair"
		_confirm_btn.visible = false
		_pair_note.text = "Tap a glowing square. Both pieces show before you place them."
		_pair_note.visible = true
		_board.set_pulse_cells(CourtsRules.partners(_logic, _logic.cells, _pair_a, player))
	else:
		_power_btn.text = "Cancel"
		_confirm_btn.visible = true
		if _first_would_win():
			_confirm_btn.text = "Place winner"
			_pair_note.text = "That first square already wins, so the second piece is not placed."
		else:
			_confirm_btn.text = "Place both"
			_pair_note.text = "Both squares are previewed. Place both uses this turn."
		_pair_note.visible = true
		_board.set_pulse_cells(CourtsRules.partners(_logic, _logic.cells, _pair_a, player))
	UIKit.apply_choice_selected(_power_btn, _pick != _PICK_IDLE)
	_ghost_key = ""
	_refresh_ghosts(_hover_index)


func _on_power_pressed() -> void:
	if _busy or _logic.is_game_over() or _card_open() or not _is_human_turn():
		return
	if _power_btn.disabled:
		return
	if _pick == _PICK_IDLE:
		_pick = _PICK_FIRST
		_pair_a = -1
		_pair_b = -1
	else:
		_pick = _PICK_IDLE
		_pair_a = -1
		_pair_b = -1
		_clear_pair_preview()
	_refresh_power_chip()
	_sync_sv_size()


func _on_pair_tap(index: int) -> void:
	var player: int = _logic.current_player
	if _pick == _PICK_FIRST:
		if CourtsRules.partners(_logic, _logic.cells, index, player).is_empty():
			_pair_note.text = "No landing from that square. Tap another empty one."
			_pair_note.visible = true
			return
		_pair_a = index
		_pair_b = -1
		_pick = _PICK_SECOND
		_refresh_power_chip()
		return
	if index == _pair_a:
		return
	if not _is_partner_cell(_pair_a, index):
		if _pick == _PICK_SECOND and not CourtsRules.partners(_logic, _logic.cells, index, player).is_empty():
			_pair_a = index
			_pair_b = -1
			_refresh_power_chip()
		return
	_pair_b = index
	_pick = _PICK_CONFIRM
	_refresh_power_chip()


func _on_confirm_pair() -> void:
	if _busy or _pick != _PICK_CONFIRM or _pair_a < 0 or _pair_b < 0:
		return
	if not _is_partner_cell(_pair_a, _pair_b):
		return
	_busy = true
	var cells: Array[int] = [_pair_a, _pair_b]
	_pick = _PICK_IDLE
	_play_human_cells(cells, true)


func _clear_pair_preview() -> void:
	_ghost_key = ""
	if _board == null:
		return
	_board.set_ghosts([], GameLogic.EMPTY)
	_board.set_preview_cells([])
	_board.set_pulse_cells([])
	_board.set_hover(-1)


func _preview_cells(hover: int) -> Array[int]:
	var cells: Array[int] = []
	if _pair_a < 0 or _pick == _PICK_IDLE or _pick == _PICK_FIRST:
		return cells
	cells.append(_pair_a)
	var second := -1
	if hover >= 0 and hover != _pair_a and _is_partner_cell(_pair_a, hover):
		second = hover
	elif _pick == _PICK_CONFIRM:
		second = _pair_b
	if second >= 0:
		cells.append(second)
	return cells


func _refresh_ghosts(hover: int) -> void:
	if _board == null or not _powers_in_match():
		return
	var cells := _preview_cells(hover)
	var key := "%d:" % _pick
	for c in cells:
		key += "%d," % c
	if key == _ghost_key:
		return
	_ghost_key = key
	_board.set_ghosts(cells, _logic.current_player)
	_board.set_preview_cells(cells)


func _show_handoff() -> void:
	var who := GameLogic.player_name(_logic.current_player)
	_handoff_body.text = "Hand the phone to the %s, then tap Ready." % who
	_handoff.visible = true


func _dismiss_handoff(skip_rest: bool) -> void:
	if skip_rest:
		GameSession.skip_handoff = true
	_handoff.visible = false
	handoff_closed.emit()


func _open_tutorial() -> void:
	if _tutorial == null:
		_tutorial = HowToPlay.new()
		_tutorial.closed.connect(_on_tutorial_closed)
		_hud_root.add_child(_tutorial)
	_tutorial.open_at(0)


func _on_tutorial_closed() -> void:
	PlayerPrefs.mark_courts_hint_seen()
	if _tutorial:
		_tutorial.visible = false
	if not _started and not _logic.is_game_over():
		_begin_opening_turn()


func _restart_board() -> void:
	_hide_result_sheet()
	_handoff.visible = false
	if _tutorial:
		_tutorial.visible = false
	_logic.reset()
	_board.clear_pieces()
	_busy = false
	_scored = false
	_started = false
	_pick = _PICK_IDLE
	_pair_a = -1
	_pair_b = -1
	_pair_used = [false, false, false]
	_ai_thinking = false
	_clear_pair_preview()
	_update_turn_label()
	_refresh_power_chip()
	_begin_opening_turn()


func _on_rematch() -> void:
	if GameSession.series_over():
		GameSession.reset_series()
	_restart_board()


func _on_menu() -> void:
	GameSession.skip_handoff = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _update_hover() -> void:
	_hover_index = _cell_at_pointer()
	var show := -1
	if _hover_index >= 0 and _logic.is_legal(_hover_index):
		if _pick == _PICK_IDLE or _pick == _PICK_FIRST:
			show = _hover_index
		elif _hover_index != _pair_a and _is_partner_cell(_pair_a, _hover_index):
			show = _hover_index
	if show >= 0:
		_board.set_hover(show)
	else:
		_board.set_hover(-1)
	_refresh_ghosts(show)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)

	_hud_root = Control.new()
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud_root)

	_top_bar = MarginContainer.new()
	_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_bar.offset_bottom = _insets.y
	_top_bar.add_theme_constant_override("margin_left", int(_insets.x) + 8)
	_top_bar.add_theme_constant_override("margin_right", int(_insets.z) + 8)
	_top_bar.add_theme_constant_override("margin_top", 8)
	_top_bar.add_theme_constant_override("margin_bottom", 4)
	_hud_root.add_child(_top_bar)

	var turn_panel := PanelContainer.new()
	turn_panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.12, 0.07, 0.04, 0.78), Color(0.62, 0.42, 0.22)))
	_top_bar.add_child(turn_panel)

	var turn_col := VBoxContainer.new()
	turn_col.add_theme_constant_override("separation", 6)
	turn_panel.add_child(turn_col)

	_turn_label = UIKit.make_title("Knights to move", 22)
	_turn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	turn_col.add_child(_turn_label)

	var meta := HBoxContainer.new()
	meta.alignment = BoxContainer.ALIGNMENT_CENTER
	meta.add_theme_constant_override("separation", 10)
	turn_col.add_child(meta)
	meta.add_child(_mode_pill(GameSession.mini_game_label()))
	_score_label = UIKit.make_body(GameSession.score_line(), 16)
	_score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(_score_label)
	_help_btn = UIKit.make_button("?", Vector2(52, 48))
	_help_btn.add_theme_font_size_override("font_size", 24)
	_help_btn.pressed.connect(_open_tutorial)
	meta.add_child(_help_btn)

	_power_btn = UIKit.make_choice_button("Knight pair")
	_power_btn.custom_minimum_size = Vector2(0, 48)
	_power_btn.visible = _powers_in_match()
	_power_btn.pressed.connect(_on_power_pressed)
	turn_col.add_child(_power_btn)

	_pair_note = UIKit.make_body("", 14)
	_pair_note.visible = false
	turn_col.add_child(_pair_note)

	_confirm_btn = UIKit.make_button("Place both", Vector2(0, 56))
	_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_btn.visible = false
	_confirm_btn.pressed.connect(_on_confirm_pair)
	turn_col.add_child(_confirm_btn)

	_bottom_bar = HBoxContainer.new()
	_bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_bar.offset_top = -_insets.w
	_bottom_bar.offset_left = _insets.x
	_bottom_bar.offset_right = -_insets.z
	_bottom_bar.offset_bottom = -10.0
	_bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_bottom_bar.add_theme_constant_override("separation", 16)
	_hud_root.add_child(_bottom_bar)

	var restart_btn := UIKit.make_button("Restart", Vector2(240, 60))
	restart_btn.pressed.connect(_restart_board)
	_bottom_bar.add_child(restart_btn)
	var menu_btn := UIKit.make_button("Menu", Vector2(240, 60))
	menu_btn.pressed.connect(_on_menu)
	_bottom_bar.add_child(menu_btn)

	_build_result_sheet()

	_handoff = _make_dim_card(_hud_root)
	var hand_col := _card_column(_handoff)
	hand_col.add_child(UIKit.make_title("Pass the phone", 34))
	_handoff_body = UIKit.make_body("Hand the phone to the Queens, then tap Ready.", 18)
	hand_col.add_child(_handoff_body)
	var ready := UIKit.make_button("Ready", Vector2(360, 68))
	ready.pressed.connect(_dismiss_handoff.bind(false))
	hand_col.add_child(ready)
	var skip := UIKit.make_button("Skip handoffs", Vector2(360, 52))
	skip.pressed.connect(_dismiss_handoff.bind(true))
	hand_col.add_child(skip)


var _handoff_body: Label


func _build_result_sheet() -> void:
	_result_sheet = PanelContainer.new()
	_result_sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_result_sheet.offset_left = _insets.x
	_result_sheet.offset_right = -_insets.z
	_result_sheet.offset_top = -400
	_result_sheet.offset_bottom = -8
	_result_sheet.visible = false
	_result_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_sheet.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.14, 0.08, 0.04, 0.96), Color(0.85, 0.65, 0.32)))
	_hud_root.add_child(_result_sheet)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_sheet.add_child(col)

	_result_title = UIKit.make_title("Knights win!", 32)
	col.add_child(_result_title)
	_result_body = UIKit.make_body("Four in a row.", 18)
	col.add_child(_result_body)

	var again := UIKit.make_button("Rematch", Vector2(0, 64))
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(_on_rematch)
	col.add_child(again)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var restart := UIKit.make_button("Restart", Vector2(220, 56))
	restart.pressed.connect(_restart_board)
	row.add_child(restart)
	var to_menu := UIKit.make_button("Menu", Vector2(220, 56))
	to_menu.pressed.connect(_on_menu)
	row.add_child(to_menu)


func _mode_pill(text: String) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.55, 0.34, 0.14)
	style.border_color = Color(0.92, 0.74, 0.32)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", style)
	var lab := UIKit.make_title(text, 16)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.add_child(lab)
	return pill


func _make_dim_card(root: Control) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.0, 0.72)
	overlay.add_child(dim)
	return overlay


func _card_column(overlay: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -200
	panel.offset_bottom = 200
	panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.16, 0.09, 0.05, 0.96), Color(0.85, 0.65, 0.32)))
	overlay.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	return col
