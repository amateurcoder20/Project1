extends SceneTree
## Headless rules + AI checks. Run:
##   godot --headless --path . -s tests/test_game_logic.gd

const GameLogicScript = preload("res://scripts/game_logic.gd")
const AIScript = preload("res://scripts/tic_tac_ai.gd")

var _failed := 0


func _init() -> void:
	print("Knights vs Queens — logic tests")
	_check("row win", _test_row_win())
	_check("column win", _test_column_win())
	_check("diagonal win", _test_diag_win())
	_check("anti-diagonal win", _test_anti_diag_win())
	_check("no false win", _test_no_false_win())
	_check("draw on checkerboard", _test_draw())
	_check("illegal occupied cell", _test_illegal())
	_check("AI takes winning move", _test_ai_wins())
	_check("AI blocks knight win", _test_ai_blocks())
	_check("AI prefers win over block", _test_ai_win_over_block())
	_check("AI returns a legal move on empty-ish board", _test_ai_opening())
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


func _play(cells: Array, current: int = GameLogicScript.KNIGHT) -> RefCounted:
	var logic: RefCounted = GameLogicScript.new()
	for i in cells.size():
		logic.cells[i] = int(cells[i])
	logic.current_player = current
	return logic


func _test_row_win() -> bool:
	var logic = _play([
		1, 1, 1, 1,
		0, 2, 0, 2,
		0, 0, 0, 0,
		0, 0, 0, 0,
	])
	return logic.winner() == GameLogicScript.KNIGHT


func _test_column_win() -> bool:
	var logic = _play([
		2, 1, 0, 0,
		2, 1, 0, 0,
		2, 0, 1, 0,
		2, 0, 0, 1,
	])
	return logic.winner() == GameLogicScript.QUEEN


func _test_diag_win() -> bool:
	var logic = _play([
		1, 2, 0, 0,
		0, 1, 2, 0,
		0, 0, 1, 2,
		0, 0, 0, 1,
	])
	return logic.winner() == GameLogicScript.KNIGHT


func _test_anti_diag_win() -> bool:
	var logic = _play([
		0, 0, 2, 1,
		0, 2, 1, 0,
		2, 1, 0, 0,
		1, 0, 0, 0,
	])
	return logic.winner() == GameLogicScript.KNIGHT


func _test_no_false_win() -> bool:
	var logic = _play([
		1, 1, 1, 2,
		2, 2, 1, 1,
		1, 2, 2, 1,
		2, 1, 2, 0,
	])
	return logic.winner() == GameLogicScript.EMPTY and not logic.is_draw()


func _test_draw() -> bool:
	var logic = _play([
		1, 1, 2, 2,
		2, 2, 1, 1,
		1, 1, 2, 2,
		2, 2, 1, 1,
	])
	return logic.is_draw() and logic.winner() == GameLogicScript.EMPTY


func _test_illegal() -> bool:
	var logic = GameLogicScript.new()
	if not logic.place(0):
		return false
	if logic.place(0):
		return false
	if logic.place(-1) or logic.place(16):
		return false
	return logic.cells[0] == GameLogicScript.KNIGHT


func _test_ai_wins() -> bool:
	# Queens threaten the main diagonal; 15 completes it.
	var logic = _play([
		2, 1, 0, 0,
		1, 2, 0, 0,
		0, 1, 2, 0,
		0, 0, 1, 0,
	], GameLogicScript.QUEEN)
	var ai = AIScript.new()
	return ai.choose_move(logic) == 15


func _test_ai_blocks() -> bool:
	var logic = _play([
		1, 1, 1, 0,
		2, 0, 0, 0,
		0, 2, 0, 0,
		0, 0, 0, 0,
	], GameLogicScript.QUEEN)
	var ai = AIScript.new()
	return ai.choose_move(logic) == 3


func _test_ai_win_over_block() -> bool:
	# Queens can win on row 1 (indices 4-7) and knights threaten row 0.
	var logic = _play([
		1, 1, 1, 0,
		2, 2, 2, 0,
		0, 0, 0, 0,
		0, 0, 1, 0,
	], GameLogicScript.QUEEN)
	var ai = AIScript.new()
	return ai.choose_move(logic) == 7


func _test_ai_opening() -> bool:
	var logic = GameLogicScript.new()
	logic.place(0) # knight in a corner
	logic.switch_player()
	var ai = AIScript.new()
	var move: int = ai.choose_move(logic)
	return move >= 0 and move < 16 and move != 0
