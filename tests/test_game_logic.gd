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
	_check("powers stay off 3x3", _test_powers_allowed())
	_check("knight pair is a 2x1 of two empty cells", _test_knight_pair_shape())
	_check("queen pair is adjacent diagonal only", _test_queen_pair_shape())
	_check("occupied cells are not a pair", _test_pair_filters())
	_check("first winning piece skips the second", _test_pair_stops_when_first_wins())
	_check("queen pair places both when the second wins", _test_queen_pair_places_both())
	_check("marshal queen pair wins a diagonal", _test_ai_queen_pair_win())
	_check("single win is preferred over spending the pair", _test_ai_prefers_single_win())
	_check("squire does not spend the pair", _test_ai_squire_saves_pair())
	_check("knight AI blocks two threats with a pair", _test_ai_knight_pair_block())
	_check("knight AI blocks a queen pair with one stone", _test_ai_knight_blocks_queen_pair())
	_check("marshal spends a pair to fork", _test_ai_knight_fork())
	_check("knight AI takes its own winning move", _test_ai_knight_wins())
	_check("3x3 never spends a pair", _test_ai_no_power_on_3x3())
	_check("tutorial shows a place, a knight pair, and a queen pair", _test_tutorial_pages())
	_check("human side chooses the AI's faction", _test_human_side())
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


func _blank(n: int) -> Array:
	var cells := []
	cells.resize(n * n)
	cells.fill(0)
	return cells


func _test_powers_allowed() -> bool:
	return not CourtsScript.powers_allowed(3, 3) \
		and CourtsScript.powers_allowed(5, 4) \
		and CourtsScript.powers_allowed(8, 5) \
		and not CourtsScript.powers_allowed(5, 3)


func _test_knight_pair_shape() -> bool:
	var logic = _play(_blank(5), GameLogicScript.KNIGHT, 5, 4)
	var got: Array = CourtsScript.partners(logic, logic.cells, 12, GameLogicScript.KNIGHT)
	# Empty center (2,2). Landings are the eight knight moves, not diagonals.
	if not _same_cells(got, [1, 3, 5, 9, 15, 19, 21, 23]):
		return false
	return CourtsScript.is_partner(logic, logic.cells, 12, 19, GameLogicScript.KNIGHT) \
		and not CourtsScript.is_partner(logic, logic.cells, 12, 18, GameLogicScript.KNIGHT) \
		and not CourtsScript.is_partner(logic, logic.cells, 12, 14, GameLogicScript.KNIGHT)


func _test_queen_pair_shape() -> bool:
	var logic = _play(_blank(5), GameLogicScript.QUEEN, 5, 4)
	var got: Array = CourtsScript.partners(logic, logic.cells, 12, GameLogicScript.QUEEN)
	# Touching diagonals only. Not orthogonal, and not (0,0)/(4,4) which leave a gap.
	if not _same_cells(got, [6, 8, 16, 18]):
		return false
	return not CourtsScript.is_partner(logic, logic.cells, 12, 0, GameLogicScript.QUEEN) \
		and not CourtsScript.is_partner(logic, logic.cells, 12, 24, GameLogicScript.QUEEN) \
		and not CourtsScript.is_partner(logic, logic.cells, 0, 12, GameLogicScript.QUEEN)


func _test_pair_filters() -> bool:
	var cells := _blank(5)
	cells[12] = GameLogicScript.KNIGHT
	cells[19] = GameLogicScript.QUEEN
	var logic = _play(cells, GameLogicScript.KNIGHT, 5, 4)
	if not CourtsScript.partners(logic, logic.cells, 12, GameLogicScript.KNIGHT).is_empty():
		return false
	var from_corner: Array = CourtsScript.partners(logic, logic.cells, 0, GameLogicScript.KNIGHT)
	# (0,0) knight landings are 7=(1,2) and 11=(2,1). 19 is irrelevant.
	return _same_cells(from_corner, [7, 11]) and not from_corner.has(19)


func _test_pair_stops_when_first_wins() -> bool:
	var cells := _blank(5)
	cells[0] = GameLogicScript.KNIGHT
	cells[1] = GameLogicScript.KNIGHT
	cells[2] = GameLogicScript.KNIGHT
	var logic = _play(cells, GameLogicScript.KNIGHT, 5, 4)
	# 3=(0,3) finishes the row. 6=(1,1) is a knight move from 3.
	var placed: Array = CourtsScript.commit_on_logic(logic, 3, 6)
	if not _same_cells(placed, [3]):
		push_error("expected only the winning cell, got %s" % placed)
		return false
	return logic.cells[6] == GameLogicScript.EMPTY \
		and logic.winner() == GameLogicScript.KNIGHT \
		and logic.current_player == GameLogicScript.KNIGHT


func _test_queen_pair_places_both() -> bool:
	var cells := _blank(5)
	cells[6] = GameLogicScript.QUEEN
	cells[12] = GameLogicScript.QUEEN
	var logic = _play(cells, GameLogicScript.QUEEN, 5, 4)
	if CourtsScript.commit_on_logic(logic, 12, 24).size() != 0:
		return false
	var fresh = _play(cells, GameLogicScript.QUEEN, 5, 4)
	var placed: Array = CourtsScript.commit_on_logic(fresh, 18, 24)
	if not _same_cells(placed, [18, 24]):
		push_error("expected both queen squares, got %s" % placed)
		return false
	return fresh.winner() == GameLogicScript.QUEEN and fresh.cells[18] == GameLogicScript.QUEEN


func _action_cells(action: Dictionary) -> Array:
	return action.get("cells", [])


func _test_ai_queen_pair_win() -> bool:
	var cells := _blank(5)
	cells[6] = GameLogicScript.QUEEN
	cells[12] = GameLogicScript.QUEEN
	var logic = _play(cells, GameLogicScript.QUEEN, 5, 4)
	var ai = AIScript.new()
	var action: Dictionary = ai.choose_action(logic, AIScript.RANK_MARSHAL, GameLogicScript.QUEEN, true, false)
	var got: Array = _action_cells(action)
	if not bool(action.get("power", false)) or not _same_cells(got, [18, 24]):
		push_error("expected queen pair 18+24, got %s" % action)
		return false
	return true


func _test_ai_prefers_single_win() -> bool:
	var cells := _blank(5)
	cells[0] = GameLogicScript.QUEEN
	cells[1] = GameLogicScript.QUEEN
	cells[2] = GameLogicScript.QUEEN
	cells[6] = GameLogicScript.QUEEN
	cells[12] = GameLogicScript.QUEEN
	var logic = _play(cells, GameLogicScript.QUEEN, 5, 4)
	var ai = AIScript.new()
	var action: Dictionary = ai.choose_action(logic, AIScript.RANK_REGENT, GameLogicScript.QUEEN, true, false)
	var got: Array = _action_cells(action)
	if bool(action.get("power", false)) or got.size() != 1:
		push_error("expected a single winning drop, got %s" % action)
		return false
	var board: PackedInt32Array = logic.snapshot()
	board[int(got[0])] = GameLogicScript.QUEEN
	return logic.winner_from_move(board, int(got[0])) == GameLogicScript.QUEEN


func _test_ai_squire_saves_pair() -> bool:
	var cells := _blank(5)
	cells[6] = GameLogicScript.QUEEN
	cells[12] = GameLogicScript.QUEEN
	var logic = _play(cells, GameLogicScript.QUEEN, 5, 4)
	var ai = AIScript.new()
	var action: Dictionary = ai.choose_action(logic, AIScript.RANK_SQUIRE, GameLogicScript.QUEEN, true, true)
	var got: Array = _action_cells(action)
	if bool(action.get("power", false)) or got.size() != 1:
		push_error("squire spent a pair: %s" % action)
		return false
	return true


func _test_ai_knight_pair_block() -> bool:
	var cells := _blank(5)
	# Queens threaten 13 (row) and 22 (row). Those squares are a knight move apart.
	cells[10] = GameLogicScript.QUEEN
	cells[11] = GameLogicScript.QUEEN
	cells[12] = GameLogicScript.QUEEN
	cells[20] = GameLogicScript.QUEEN
	cells[21] = GameLogicScript.QUEEN
	cells[23] = GameLogicScript.QUEEN
	var logic = _play(cells, GameLogicScript.KNIGHT, 5, 4)
	var ai = AIScript.new()
	var action: Dictionary = ai.choose_action(logic, AIScript.RANK_MARSHAL, GameLogicScript.KNIGHT, true, false)
	var got: Array = _action_cells(action)
	if not bool(action.get("power", false)) or not _same_cells(got, [13, 22]):
		push_error("expected knight pair block 13+22, got %s" % action)
		return false
	return true


func _test_ai_knight_blocks_queen_pair() -> bool:
	var cells := _blank(5)
	cells[6] = GameLogicScript.QUEEN
	cells[12] = GameLogicScript.QUEEN
	var logic = _play(cells, GameLogicScript.KNIGHT, 5, 4)
	var ai = AIScript.new()
	var action: Dictionary = ai.choose_action(logic, AIScript.RANK_MARSHAL, GameLogicScript.KNIGHT, true, true)
	var got: Array = _action_cells(action)
	if bool(action.get("power", false)) or got.size() != 1:
		push_error("expected a single block, got %s" % action)
		return false
	var cell := int(got[0])
	return cell == 18 or cell == 24


func _count_threats(logic, board: PackedInt32Array, player: int) -> int:
	var n := 0
	for i in logic.cell_count:
		if board[i] != GameLogicScript.EMPTY:
			continue
		board[i] = player
		if logic.winner_from_move(board, i) == player:
			n += 1
		board[i] = GameLogicScript.EMPTY
	return n


func _test_ai_knight_fork() -> bool:
	var cells := _blank(5)
	# Knights at (0,0), (0,1), (1,1). No single stone forks; a knight pair does.
	cells[0] = GameLogicScript.KNIGHT
	cells[1] = GameLogicScript.KNIGHT
	cells[6] = GameLogicScript.KNIGHT
	var logic = _play(cells, GameLogicScript.KNIGHT, 5, 4)
	var ai = AIScript.new()
	var action: Dictionary = ai.choose_action(logic, AIScript.RANK_MARSHAL, GameLogicScript.KNIGHT, true, false)
	if not bool(action.get("power", false)):
		push_error("expected a fork pair, got %s" % action)
		return false
	var got: Array = _action_cells(action)
	if got.size() != 2 or not CourtsScript.is_partner(logic, logic.cells, int(got[0]), int(got[1]), GameLogicScript.KNIGHT):
		push_error("fork was not a knight pair: %s" % action)
		return false
	var board: PackedInt32Array = logic.snapshot()
	var placed: Array = CourtsScript.apply_ordered(logic, board, GameLogicScript.KNIGHT, int(got[0]), int(got[1]))
	if placed.size() < 2:
		return false
	var threats := _count_threats(logic, board, GameLogicScript.KNIGHT)
	if threats < 2:
		push_error("pair %s created %d threats" % [got, threats])
		return false
	return true


func _test_ai_knight_wins() -> bool:
	var logic = _play([
		0, 1, 1,
		2, 2, 0,
		0, 0, 0,
	], GameLogicScript.KNIGHT, 3, 3)
	var ai = AIScript.new()
	var action: Dictionary = ai.choose_action(logic, AIScript.RANK_MARSHAL, GameLogicScript.KNIGHT, true, true)
	var got: Array = _action_cells(action)
	return got.size() == 1 and int(got[0]) == 0 and not bool(action.get("power", false))


func _test_ai_no_power_on_3x3() -> bool:
	var logic = _play([
		2, 1, 1,
		2, 1, 0,
		0, 0, 0,
	], GameLogicScript.QUEEN, 3, 3)
	var ai = AIScript.new()
	var action: Dictionary = ai.choose_action(logic, AIScript.RANK_REGENT, GameLogicScript.QUEEN, true, true)
	var got: Array = _action_cells(action)
	return got.size() == 1 and int(got[0]) == 6 and not bool(action.get("power", false))


func _test_tutorial_pages() -> bool:
	var help = HowToPlay.new()
	root.add_child(help)
	help.open_at(0)
	if help.current_title() != "A normal place" or help.marked_indices().size() != 1:
		return false
	var logic = GameLogicScript.new(5, 4)
	help.open_at(1)
	if help.current_title() != "Knight pair":
		return false
	var knight_marks: Array = help.marked_indices()
	if knight_marks.size() != 2:
		return false
	if not CourtsScript.is_partner(logic, logic.cells, int(knight_marks[0]), int(knight_marks[1]), GameLogicScript.KNIGHT):
		return false
	help.open_at(2)
	if help.current_title() != "Queen pair":
		return false
	var queen_marks: Array = help.marked_indices()
	if queen_marks.size() != 2:
		return false
	if not CourtsScript.is_partner(logic, logic.cells, int(queen_marks[0]), int(queen_marks[1]), GameLogicScript.QUEEN):
		return false
	var gap := help.gap_index()
	if CourtsScript.is_partner(logic, logic.cells, int(queen_marks[0]), gap, GameLogicScript.QUEEN):
		return false
	if CourtsScript.is_partner(logic, logic.cells, int(queen_marks[1]), gap, GameLogicScript.QUEEN):
		return false
	var n := 5
	var dr := absi(int(gap / n) - int(int(queen_marks[0]) / n))
	var dc := absi((gap % n) - (int(queen_marks[0]) % n))
	help.queue_free()
	return dr == 2 and dc == 2


func _test_human_side() -> bool:
	var session = SessionScript.new()
	if session.human_player != GameLogicScript.KNIGHT or session.ai_player() != GameLogicScript.QUEEN:
		return false
	session.set_human_player(GameLogicScript.QUEEN)
	if session.human_player != GameLogicScript.QUEEN or session.ai_player() != GameLogicScript.KNIGHT:
		return false
	session.set_human_player(GameLogicScript.KNIGHT)
	return session.ai_player() == GameLogicScript.QUEEN and not session.powers_in_match()


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
