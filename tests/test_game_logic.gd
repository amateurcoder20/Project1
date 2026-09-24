extends SceneTree
## Headless rules + AI checks. Run:
##   godot --headless --path . -s tests/test_game_logic.gd

const GameLogicScript = preload("res://scripts/game_logic.gd")
const AIScript = preload("res://scripts/tic_tac_ai.gd")
const PresetScript = preload("res://scripts/board_preset.gd")
const CourtsScript = preload("res://scripts/courts_rules.gd")
const SessionScript = preload("res://scripts/game_session.gd")

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
	_check("leap is a 2x1 from your piece", _test_leap_shape())
	_check("leap ignores enemies and occupied landings", _test_leap_filters())
	_check("command reaches 1 and 2 on a clear line", _test_command_clear())
	_check("command stops at a blocker and ignores diagonals", _test_command_blocked())
	_check("marshal spends command to win", _test_ai_command_win())
	_check("marshal spends command to block", _test_ai_command_block())
	_check("squire does not spend command", _test_ai_squire_saves_power())
	_check("bo3 crown ends at two wins", _test_series_bo3())
	_check("courts leaves 3x3 for 5x5", _test_courts_board_default())
	_check("rank ladder matches the AI constants", _test_rank_ids())
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


func _same_cells(got: Array, expected: Array) -> bool:
	if got.size() != expected.size():
		push_error("size %s vs %s (%s vs %s)" % [got.size(), expected.size(), got, expected])
		return false
	var marked := {}
	for c in got:
		marked[int(c)] = true
	for c in expected:
		if not marked.has(int(c)):
			push_error("missing %s in %s" % [c, got])
			return false
	return true


func _test_leap_shape() -> bool:
	var cells := []
	cells.resize(25)
	cells.fill(0)
	cells[12] = GameLogicScript.KNIGHT # center (2, 2)
	var logic = _play(cells, GameLogicScript.KNIGHT, 5, 4)
	var got: Array = CourtsScript.leap_cells(logic, GameLogicScript.KNIGHT)
	return _same_cells(got, [1, 3, 5, 9, 15, 19, 21, 23])


func _test_leap_filters() -> bool:
	var cells := []
	cells.resize(25)
	cells.fill(0)
	cells[0] = GameLogicScript.KNIGHT
	cells[7] = GameLogicScript.QUEEN # one knight-landing occupied
	cells[24] = GameLogicScript.QUEEN # enemy must not generate leaps
	var logic = _play(cells, GameLogicScript.KNIGHT, 5, 4)
	var got: Array = CourtsScript.leap_cells(logic, GameLogicScript.KNIGHT)
	# From (0,0): (1,2)=7 occupied, (2,1)=11 empty. Nothing else on the board.
	if not _same_cells(got, [11]):
		return false
	var enemy: Array = CourtsScript.leap_cells(logic, GameLogicScript.QUEEN)
	return enemy.size() > 0 and not enemy.has(11)


func _test_command_clear() -> bool:
	var cells := []
	cells.resize(25)
	cells.fill(0)
	cells[12] = GameLogicScript.QUEEN
	var logic = _play(cells, GameLogicScript.QUEEN, 5, 4)
	var got: Array = CourtsScript.command_cells(logic, GameLogicScript.QUEEN)
	# Orthogonal distance 1 and 2 from (2,2). No diagonals.
	return _same_cells(got, [10, 11, 13, 14, 2, 7, 17, 22])


func _test_command_blocked() -> bool:
	var cells := []
	cells.resize(25)
	cells.fill(0)
	cells[0] = GameLogicScript.QUEEN # (0,0)
	cells[1] = GameLogicScript.KNIGHT # blocks the row
	var logic = _play(cells, GameLogicScript.QUEEN, 5, 4)
	var got: Array = CourtsScript.command_cells(logic, GameLogicScript.QUEEN)
	# Row is blocked, so only down the file: (1,0)=5 and (2,0)=10.
	if not _same_cells(got, [5, 10]):
		return false
	# Distance 3 is off the command, even on a clear file of an 8×8.
	var wide := []
	wide.resize(64)
	wide.fill(0)
	wide[0] = GameLogicScript.QUEEN
	var big = _play(wide, GameLogicScript.QUEEN, 8, 5)
	var far: Array = CourtsScript.command_cells(big, GameLogicScript.QUEEN)
	return far.has(1) and far.has(2) and far.has(8) and far.has(16) and not far.has(3) and not far.has(24)


func _test_ai_command_win() -> bool:
	var cells := []
	cells.resize(25)
	cells.fill(0)
	cells[0] = GameLogicScript.QUEEN
	cells[1] = GameLogicScript.QUEEN
	cells[2] = GameLogicScript.QUEEN
	cells[5] = GameLogicScript.KNIGHT
	var logic = _play(cells, GameLogicScript.QUEEN, 5, 4)
	var targets: Array = CourtsScript.command_cells(logic, GameLogicScript.QUEEN)
	var ai = AIScript.new()
	var action: Dictionary = ai.choose_action(logic, AIScript.RANK_MARSHAL, targets)
	return int(action["index"]) == 3 and bool(action["power"])


func _test_ai_command_block() -> bool:
	var cells := []
	cells.resize(25)
	cells.fill(0)
	# Knights threaten index 23 (4,3). Queen at (2,3)=13 can Command there.
	cells[20] = GameLogicScript.KNIGHT
	cells[21] = GameLogicScript.KNIGHT
	cells[22] = GameLogicScript.KNIGHT
	cells[13] = GameLogicScript.QUEEN
	var logic = _play(cells, GameLogicScript.QUEEN, 5, 4)
	var targets: Array = CourtsScript.command_cells(logic, GameLogicScript.QUEEN)
	if not targets.has(23):
		push_error("expected command to reach the block cell, got %s" % targets)
		return false
	var ai = AIScript.new()
	var action: Dictionary = ai.choose_action(logic, AIScript.RANK_REGENT, targets)
	return int(action["index"]) == 23 and bool(action["power"])


func _test_ai_squire_saves_power() -> bool:
	var cells := []
	cells.resize(25)
	cells.fill(0)
	cells[0] = GameLogicScript.QUEEN
	cells[1] = GameLogicScript.QUEEN
	cells[2] = GameLogicScript.QUEEN
	var logic = _play(cells, GameLogicScript.QUEEN, 5, 4)
	var targets: Array = CourtsScript.command_cells(logic, GameLogicScript.QUEEN)
	var ai = AIScript.new()
	var action: Dictionary = ai.choose_action(logic, AIScript.RANK_SQUIRE, targets)
	# Still takes the win with a normal drop, and does not spend the power.
	return int(action["index"]) == 3 and not bool(action["power"])


func _test_series_bo3() -> bool:
	var session = SessionScript.new()
	session.series_kind = SessionScript.SeriesKind.BO3
	session.note_winner(GameLogicScript.KNIGHT)
	if session.series_over() or session.knight_wins != 1:
		return false
	session.note_winner(GameLogicScript.EMPTY)
	if session.knight_wins != 1 or session.queen_wins != 0:
		return false
	session.note_winner(GameLogicScript.KNIGHT)
	if not session.series_over() or session.series_target() != 2:
		return false
	session.reset_series()
	return session.knight_wins == 0 and not session.series_over() and session.score_line().find("0") >= 0


func _test_courts_board_default() -> bool:
	var session = SessionScript.new()
	session.board_size = 3
	session.set_mini_game(SessionScript.MiniGame.COURTS)
	if session.board_size != 5 or not session.is_courts():
		return false
	session.set_board_size(3)
	if session.board_size != 5:
		return false
	session.set_mini_game(SessionScript.MiniGame.CLASSIC)
	session.set_board_size(3)
	return session.board_size == 3 and not session.is_courts()


func _test_rank_ids() -> bool:
	return AIScript.RANK_SQUIRE == SessionScript.AiRank.SQUIRE \
		and AIScript.RANK_MARSHAL == SessionScript.AiRank.MARSHAL \
		and AIScript.RANK_REGENT == SessionScript.AiRank.REGENT
