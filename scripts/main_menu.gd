extends Node3D
## Main menu: Classic or Courts, board, Crown War length, AI rank, then play.

var _board: BoardView
var _world: Node3D
var _cam: Camera3D
var _subtitle: Label
var _preset_row: HBoxContainer
var _preset_buttons: Array[Button] = []
var _mode_buttons: Array[Button] = []
var _series_buttons: Array[Button] = []
var _rank_buttons: Array[Button] = []
var _coach: Control
var _coach_body: Label
var _coach_next: Button
var _coach_page := 0

const _COACH_PAGES: Array[String] = [
	"Knights move first. Tap an empty square and connect the line on the board chip to win.",
	"Classic stays plain. Courts adds one Leap or Command each side. Casual, Bo3, or Bo5 tracks the crown.",
]


func _ready() -> void:
	randomize()
	GameSession.board_size = BoardPreset.clamp_size(GameSession.board_size)
	if GameSession.is_courts() and GameSession.board_size == 3:
		GameSession.board_size = 5
	WorldLook.add_environment(self)
	_world = Node3D.new()
	_world.name = "Spin"
	add_child(_world)
	_cam = WorldLook.add_camera(self)
	_rebuild_preview()
	_build_ui()
	if not PlayerPrefs.has_seen_coach():
		_show_coach()


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
	# Extra pull-back so the preview sits between the chip stack and the play buttons.
	WorldLook.frame_board(_cam, _board.board_half() * 1.62, pitch * 1.5, aspect)


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
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 28
	top.offset_bottom = 470
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)

	top.add_child(UIKit.make_title("Knights vs Queens", 36))
	_subtitle = UIKit.make_body("", 16)
	top.add_child(_subtitle)

	var mode_row := _labeled_row("Mode")
	top.add_child(mode_row)
	_mode_buttons.clear()
	_add_choice(mode_row, _mode_buttons, "Classic", _on_mode.bind(GameSession.MiniGame.CLASSIC))
	_add_choice(mode_row, _mode_buttons, "Courts", _on_mode.bind(GameSession.MiniGame.COURTS))

	_preset_row = _labeled_row("Board")
	top.add_child(_preset_row)
	_rebuild_preset_buttons()

	var series_row := _labeled_row("Series")
	top.add_child(series_row)
	_series_buttons.clear()
	_add_choice(series_row, _series_buttons, "Casual", _on_series.bind(GameSession.SeriesKind.CASUAL))
	_add_choice(series_row, _series_buttons, "Bo3", _on_series.bind(GameSession.SeriesKind.BO3))
	_add_choice(series_row, _series_buttons, "Bo5", _on_series.bind(GameSession.SeriesKind.BO5))

	var rank_row := _labeled_row("AI")
	top.add_child(rank_row)
	_rank_buttons.clear()
	_add_choice(rank_row, _rank_buttons, "Squire", _on_rank.bind(GameSession.AiRank.SQUIRE))
	_add_choice(rank_row, _rank_buttons, "Marshal", _on_rank.bind(GameSession.AiRank.MARSHAL))
	_add_choice(rank_row, _rank_buttons, "Regent", _on_rank.bind(GameSession.AiRank.REGENT))

	_refresh_chips()

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 40
	bottom.offset_right = -40
	bottom.offset_top = -300
	bottom.offset_bottom = -28
	bottom.add_theme_constant_override("separation", 12)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom)

	var local_btn := UIKit.make_button("Local 2-Player", Vector2(420, 64))
	local_btn.pressed.connect(_start_game.bind(false))
	bottom.add_child(local_btn)

	var ai_btn := UIKit.make_button("Vs AI", Vector2(420, 64))
	ai_btn.pressed.connect(_start_game.bind(true))
	bottom.add_child(ai_btn)

	var quit_btn := UIKit.make_button("Quit", Vector2(420, 64))
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	bottom.add_child(quit_btn)

	var hint := UIKit.make_body("Knights move first. AI rank is Squire, Marshal, or Regent. Courts hides 3×3.", 15)
	bottom.add_child(hint)

	_build_coach(root)


func _labeled_row(caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lab := UIKit.make_body(caption, 15)
	lab.custom_minimum_size = Vector2(72, 0)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lab)
	return row


func _add_choice(row: HBoxContainer, bucket: Array[Button], text: String, handler: Callable) -> void:
	var b := UIKit.make_choice_button(text)
	b.pressed.connect(handler)
	row.add_child(b)
	bucket.append(b)


func _rebuild_preset_buttons() -> void:
	for b in _preset_buttons:
		if is_instance_valid(b):
			b.queue_free()
	_preset_buttons.clear()
	for s in _board_sizes():
		var captured: int = s
		_add_choice(_preset_row, _preset_buttons, BoardPreset.label(s), _on_preset.bind(captured))


func _board_sizes() -> Array[int]:
	if GameSession.is_courts():
		var courts: Array[int] = [5, 8]
		return courts
	return BoardPreset.SIZES


func _refresh_chips() -> void:
	_subtitle.text = "%s  ·  %s  ·  %s\n%s" % [
		GameSession.mini_game_label(),
		BoardPreset.label(GameSession.board_size),
		GameSession.series_label(),
		GameSession.score_line(),
	]
	if _mode_buttons.size() == 2:
		UIKit.apply_choice_selected(_mode_buttons[0], not GameSession.is_courts())
		UIKit.apply_choice_selected(_mode_buttons[1], GameSession.is_courts())
	var sizes := _board_sizes()
	for i in _preset_buttons.size():
		UIKit.apply_choice_selected(_preset_buttons[i], sizes[i] == GameSession.board_size)
	var series_ids: Array[int] = [GameSession.SeriesKind.CASUAL, GameSession.SeriesKind.BO3, GameSession.SeriesKind.BO5]
	for i in _series_buttons.size():
		UIKit.apply_choice_selected(_series_buttons[i], series_ids[i] == GameSession.series_kind)
	var ranks: Array[int] = [GameSession.AiRank.SQUIRE, GameSession.AiRank.MARSHAL, GameSession.AiRank.REGENT]
	for i in _rank_buttons.size():
		UIKit.apply_choice_selected(_rank_buttons[i], ranks[i] == GameSession.ai_rank)


func _on_mode(which: int) -> void:
	GameSession.set_mini_game(which)
	_rebuild_preset_buttons()
	_refresh_chips()
	_rebuild_preview()


func _on_preset(size: int) -> void:
	GameSession.set_board_size(size)
	_refresh_chips()
	_rebuild_preview()


func _on_series(kind: int) -> void:
	GameSession.set_series_kind(kind)
	_refresh_chips()


func _on_rank(rank: int) -> void:
	GameSession.ai_rank = rank
	_refresh_chips()


func _start_game(vs_ai: bool) -> void:
	GameSession.vs_ai = vs_ai
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _build_coach(root: Control) -> void:
	_coach = Control.new()
	_coach.set_anchors_preset(Control.PRESET_FULL_RECT)
	_coach.visible = false
	_coach.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_coach)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.0, 0.72)
	_coach.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -180
	panel.offset_bottom = 180
	panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.16, 0.09, 0.05, 0.96), Color(0.85, 0.65, 0.32)))
	_coach.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	col.add_child(UIKit.make_title("First match", 32))
	_coach_body = UIKit.make_body(_COACH_PAGES[0], 18)
	col.add_child(_coach_body)
	_coach_next = UIKit.make_button("Next", Vector2(360, 60))
	_coach_next.pressed.connect(_advance_coach)
	col.add_child(_coach_next)
	var skip := UIKit.make_button("Skip", Vector2(360, 52))
	skip.pressed.connect(_finish_coach)
	col.add_child(skip)


func _show_coach() -> void:
	_coach_page = 0
	_coach_body.text = _COACH_PAGES[0]
	_coach_next.text = "Next"
	_coach.visible = true


func _advance_coach() -> void:
	_coach_page += 1
	if _coach_page >= _COACH_PAGES.size():
		_finish_coach()
		return
	_coach_body.text = _COACH_PAGES[_coach_page]
	if _coach_page == _COACH_PAGES.size() - 1:
		_coach_next.text = "Play"


func _finish_coach() -> void:
	PlayerPrefs.mark_coach_seen()
	_coach.visible = false
