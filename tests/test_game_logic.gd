extends SceneTree
## Headless rules + AI checks. Run:
##   godot --headless --path . -s tests/test_game_logic.gd

const GameLogicScript = preload("res://scripts/game_logic.gd")
const AIScript = preload("res://scripts/tic_tac_ai.gd")
const PresetScript = preload("res://scripts/board_preset.gd")

var _failed := 0


func _init() -> void:
	print("Knights vs Queens — logic tests")
	_check("3x3 row win (3)", _test_3x3_row())
	_check("3x3 no win on two", _test_3x3_not_two())
	_check("5x5 four-in-a-row wins", _test_5x5_four())
	_check("5x5 three-in-a-row is not a win", _test_5x5_three_not_win())
	_check("8x8 five-in-a-row wins", _test_8x8_five())
	_check("8x8 four-in-a-row is not a win", _test_8x8_four_not_win())
	_check("illegal occupied cell", _test_illegal())
	_check("3x3 AI takes winning move", _test_ai_wins_3x3())
	_check("3x3 AI blocks", _test_ai_blocks_3x3())
	_check("5x5 AI blocks four-threat", _test_ai_blocks_5x5())
	_check("8x8 AI returns a legal move", _test_ai_opening_8x8())
	_check("preset win lengths", _test_preset_table())
	if _failed == 0:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		push_error("%d TEST(S) FAILED" % _failed)
		quit(1)


func _check(name: String, ok: bool) -> void:
	if ok:
		print("  ok  ", name)
	else:
		_failed += 1
		push_error("  FAIL  " + name)


func _play(cells: Array, current: int = GameLogicScript.KNIGHT, size: int = -1, win_len: int = -1) -> RefCounted:
	if size < 0:
		size = int(round(sqrt(float(cells.size()))))
	if win_len < 0:
		win_len = PresetScript.win_length(size) if PresetScript.is_valid(size) else size
	var logic: RefCounted = GameLogicScript.new(size, win_len)
	if logic.cell_count != cells.size():
		push_error("cell count mismatch")
		return logic
	for i in cells.size():
		logic.cells[i] = int(cells[i])
	logic.current_player = current
	return logic


func _test_3x3_row() -> bool:
	var logic = _play([
		1, 1, 1,
		2, 2, 0,
		0, 0, 0,
	], GameLogicScript.KNIGHT, 3, 3)
	return logic.winner() == GameLogicScript.KNIGHT


func _test_3x3_not_two() -> bool:
	var logic = _play([
		1, 1, 0,
		2, 2, 0,
		0, 0, 0,
	], GameLogicScript.KNIGHT, 3, 3)
	return logic.winner() == GameLogicScript.EMPTY


func _test_5x5_four() -> bool:
	var cells := []
	cells.resize(25)
	cells.fill(0)
	# Knights occupy row 2, cols 0-3
	cells[10] = 1
	cells[11] = 1
	cells[12] = 1
	cells[13] = 1
	cells[0] = 2
	cells[1] = 2
	var logic = _play(cells, GameLogicScript.KNIGHT, 5, 4)
	return logic.winner() == GameLogicScript.KNIGHT


func _test_5x5_three_not_win() -> bool:
	var cells := []
	cells.resize(25)
	cells.fill(0)
	cells[0] = 1
	cells[1] = 1
	cells[2] = 1
	cells[5] = 2
	cells[6] = 2
	var logic = _play(cells, GameLogicScript.KNIGHT, 5, 4)
	return logic.winner() == GameLogicScript.EMPTY


func _test_8x8_five() -> bool:
	var cells := []
	cells.resize(64)
	cells.fill(0)
	# Queens on main-ish diagonal segment
	cells[0] = 2
	cells[9] = 2
	cells[18] = 2
	cells[27] = 2
	cells[36] = 2
	cells[7] = 1
	var logic = _play(cells, GameLogicScript.QUEEN, 8, 5)
	return logic.winner() == GameLogicScript.QUEEN


func _test_8x8_four_not_win() -> bool:
	var cells := []
	cells.resize(64)
	cells.fill(0)
	cells[0] = 1
	cells[1] = 1
	cells[2] = 1
	cells[3] = 1
	cells[8] = 2
	var logic = _play(cells, GameLogicScript.KNIGHT, 8, 5)
	return logic.winner() == GameLogicScript.EMPTY


func _test_illegal() -> bool:
	var logic = GameLogicScript.new(3, 3)
	if not logic.place(0):
		return false
	if logic.place(0):
		return false
	if logic.place(-1) or logic.place(9):
		return false
	return logic.cells[0] == GameLogicScript.KNIGHT


func _test_ai_wins_3x3() -> bool:
	var logic = _play([
		2, 1, 1,
		2, 1, 0,
		0, 0, 0,
	], GameLogicScript.QUEEN, 3, 3)
	var ai = AIScript.new()
	return ai.choose_move(logic) == 6 # complete col 0


func _test_ai_blocks_3x3() -> bool:
	var logic = _play([
		1, 1, 0,
		2, 0, 0,
		0, 0, 0,
	], GameLogicScript.QUEEN, 3, 3)
	var ai = AIScript.new()
	return ai.choose_move(logic) == 2


func _test_ai_blocks_5x5() -> bool:
	var cells := []
	cells.resize(25)
	cells.fill(0)
	cells[0] = 1
	cells[1] = 1
	cells[2] = 1
	# one more would win (need 4)
	cells[5] = 2
	cells[10] = 2
	var logic = _play(cells, GameLogicScript.QUEEN, 5, 4)
	var ai = AIScript.new()
	return ai.choose_move(logic) == 3


func _test_ai_opening_8x8() -> bool:
	var logic = GameLogicScript.new(8, 5)
	logic.place(0)
	logic.switch_player()
	var ai = AIScript.new()
	var move: int = ai.choose_move(logic)
	return move >= 0 and move < 64 and move != 0


func _test_preset_table() -> bool:
	return PresetScript.win_length(3) == 3 and PresetScript.win_length(5) == 4 and PresetScript.win_length(8) == 5
