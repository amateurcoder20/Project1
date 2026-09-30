class_name HowToPlay
extends Control
## Three-step diagram: a normal place, the Knight pair, the Queen pair.
## Reopened from the main menu and from the match "?" control.

signal closed

const _TITLES: Array[String] = [
	"A normal place",
	"Knight pair",
	"Queen pair",
]

const _BODIES: Array[String] = [
	"Tap one empty square and place one piece. Connect the line on the board chip. Classic is only this.",
	"In Courts, once a game, Knights may place two pieces a knight move apart instead of one. Both squares must be empty. It uses the turn.",
	"Queens, once a game, place two pieces on diagonally touching squares. A gap between them does not count. If the first piece already wins, the second is not placed.",
]

## Cell indices on a 5×5 diagram. Knight: (2,2) and (1,0). Queen: (2,2) and (3,3).
const _MARKS: Array = [
	[12],
	[12, 5],
	[12, 18],
]

## Far diagonal from the Queen pair's first square — two steps, with a gap.
const _GAPS: Array[int] = [-1, -1, 0]

var _page := 0
var _panel: PanelContainer
var _title: Label
var _body: Label
var _step: Label
var _note: Label
var _next: Button
var _back: Button
var _cells: Array[Panel] = []
var _cell_labels: Array[Label] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_fill_viewport()
	visible = false


func open_at(page: int = 0) -> void:
	_page = clampi(page, 0, _TITLES.size() - 1)
	visible = true
	_fill_viewport()
	_show_page()


func _fill_viewport() -> void:
	var tree := get_viewport()
	if tree == null:
		return
	var vp := tree.get_visible_rect().size
	if vp.x < 1.0 or vp.y < 1.0:
		return
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = vp
	for child in get_children():
		if child == _panel or not (child is Control):
			continue
		(child as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _panel:
		_panel.set_anchors_preset(Control.PRESET_CENTER)
		_panel.offset_left = -310
		_panel.offset_right = 310
		_panel.offset_top = -340
		_panel.offset_bottom = 340


func current_title() -> String:
	return _TITLES[_page]


func marked_indices() -> Array:
	return (_MARKS[_page] as Array).duplicate()


func gap_index() -> int:
	return _GAPS[_page]


func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.0, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	_panel = panel
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -310
	panel.offset_right = 310
	panel.offset_top = -340
	panel.offset_bottom = 340
	panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.16, 0.09, 0.05, 0.98), Color(0.85, 0.65, 0.32)))
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)

	_step = UIKit.make_body("1 / 3", 14)
	col.add_child(_step)
	_title = UIKit.make_title(_TITLES[0], 30)
	col.add_child(_title)
	_body = UIKit.make_body(_BODIES[0], 16)
	_body.custom_minimum_size = Vector2(520, 96)
	col.add_child(_body)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(grid)
	for i in 25:
		var cell := Panel.new()
		cell.custom_minimum_size = Vector2(46, 46)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(cell)
		var lab := Label.new()
		lab.set_anchors_preset(Control.PRESET_FULL_RECT)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 18)
		lab.add_theme_color_override("font_color", Color(0.16, 0.08, 0.03))
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(lab)
		_cells.append(cell)
		_cell_labels.append(lab)

	_note = UIKit.make_body("", 14)
	_note.custom_minimum_size = Vector2(520, 40)
	col.add_child(_note)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	_back = UIKit.make_button("Back", Vector2(160, 56))
	_back.pressed.connect(_on_back)
	row.add_child(_back)
	_next = UIKit.make_button("Next", Vector2(200, 56))
	_next.pressed.connect(_on_next)
	row.add_child(_next)

	var close_btn := UIKit.make_button("Close", Vector2(372, 52))
	close_btn.pressed.connect(_on_close)
	col.add_child(close_btn)
	_show_page()


func _show_page() -> void:
	if _title == null:
		return
	_title.text = _TITLES[_page]
	_body.text = _BODIES[_page]
	_step.text = "%d / %d" % [_page + 1, _TITLES.size()]
	var marks: Array = _MARKS[_page]
	var gap := _GAPS[_page]
	for i in _cells.size():
		var row := int(i / 5.0)
		var col := i % 5
		var light := (row + col) % 2 == 0
		var lab := _cell_labels[i]
		if marks.has(i):
			_paint(_cells[i], Color(0.93, 0.74, 0.28))
			lab.text = "●"
		elif i == gap:
			_paint(_cells[i], Color(0.55, 0.22, 0.16))
			lab.text = "×"
			lab.add_theme_color_override("font_color", Color(0.98, 0.9, 0.82))
		else:
			_paint(_cells[i], Color(0.90, 0.82, 0.66) if light else Color(0.46, 0.28, 0.15))
			lab.text = ""
			lab.add_theme_color_override("font_color", Color(0.16, 0.08, 0.03))
	if _page == 1:
		_note.text = "The two gold squares are one knight move: two steps and one across."
	elif _page == 2:
		_note.text = "Gold squares touch on the diagonal. The × is two steps away, with a gap, so it is not the pair."
	else:
		_note.text = "Pairs are Courts only, on 5×5 and 8×8. Open this again from ? during a match."
	_back.disabled = _page == 0
	_next.text = "Done" if _page == _TITLES.size() - 1 else "Next"


func _paint(panel: Panel, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)


func _on_back() -> void:
	if _page > 0:
		_page -= 1
		_show_page()


func _on_next() -> void:
	if _page >= _TITLES.size() - 1:
		_on_close()
		return
	_page += 1
	_show_page()


func _on_close() -> void:
	visible = false
	closed.emit()
