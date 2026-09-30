class_name CourtsRules
extends RefCounted
## Courts double-place. Classic never calls this.
## Once per side, instead of a normal drop, on a board larger than 3×3:
## Knights place two of their pieces a chess knight move apart (2×1).
## Queens place two of their pieces on diagonally adjacent squares.
## Adjacent only — a diagonal with a gap is not a Queen pair.
## If the first piece already completes the line, the second is not placed.


const KNIGHT_DELTAS: Array[Vector2i] = [
	Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2),
	Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1),
]

const QUEEN_DELTAS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]


static func powers_allowed(size: int, win_length: int) -> bool:
	## 3×3 / win-by-3 never gets a pair. 5×5 win-4 and 8×8 win-5 do.
	return size >= 5 and win_length >= 4


static func deltas_for(player: int) -> Array[Vector2i]:
	if player == GameLogic.KNIGHT:
		return KNIGHT_DELTAS
	if player == GameLogic.QUEEN:
		return QUEEN_DELTAS
	return []


static func is_offset(player: int, dr: int, dc: int) -> bool:
	var adr := absi(dr)
	var adc := absi(dc)
	if player == GameLogic.KNIGHT:
		return (adr == 2 and adc == 1) or (adr == 1 and adc == 2)
	if player == GameLogic.QUEEN:
		return adr == 1 and adc == 1
	return false


static func is_partner(logic: GameLogic, board: PackedInt32Array, a: int, b: int, player: int) -> bool:
	if a == b or a < 0 or b < 0 or a >= logic.cell_count or b >= logic.cell_count:
		return false
	if board[a] != GameLogic.EMPTY or board[b] != GameLogic.EMPTY:
		return false
	var n := logic.size
	var ra := int(a / float(n))
	var ca := a % n
	var rb := int(b / float(n))
	var cb := b % n
	return is_offset(player, rb - ra, cb - ca)


static func partners(logic: GameLogic, board: PackedInt32Array, origin: int, player: int) -> Array[int]:
	var out: Array[int] = []
	if origin < 0 or origin >= logic.cell_count or board[origin] != GameLogic.EMPTY:
		return out
	var n := logic.size
	var row := int(origin / float(n))
	var col := origin % n
	for d in deltas_for(player):
		var rr := row + d.y
		var cc := col + d.x
		if rr < 0 or cc < 0 or rr >= n or cc >= n:
			continue
		var j := logic.idx(rr, cc)
		if board[j] == GameLogic.EMPTY:
			out.append(j)
	return out


static func unordered_pairs(logic: GameLogic, board: PackedInt32Array, player: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for a in logic.cell_count:
		if board[a] != GameLogic.EMPTY:
			continue
		for b in partners(logic, board, a, player):
			if b > a:
				out.append(Vector2i(a, b))
	return out


## Writes the pair onto `board` for `player`. Stops after the first piece if that
## piece already wins, leaving the second cell empty. Does not switch turns.
static func apply_ordered(logic: GameLogic, board: PackedInt32Array, player: int, first: int, second: int) -> Array[int]:
	var placed: Array[int] = []
	if first < 0 or second < 0 or first == second:
		return placed
	if first >= logic.cell_count or second >= logic.cell_count:
		return placed
	if board[first] != GameLogic.EMPTY or board[second] != GameLogic.EMPTY:
		return placed
	board[first] = player
	placed.append(first)
	if logic.winner_from_move(board, first) == player:
		return placed
	board[second] = player
	placed.append(second)
	return placed


static func undo(board: PackedInt32Array, placed: Array) -> void:
	for c in placed:
		board[int(c)] = GameLogic.EMPTY


## Places the pair on the live logic board with the current player. Same
## first-wins rule. Does not switch the current player.
static func commit_on_logic(logic: GameLogic, first: int, second: int) -> Array[int]:
	var player := logic.current_player
	if not is_partner(logic, logic.cells, first, second, player):
		return []
	return apply_ordered(logic, logic.cells, player, first, second)


static func chip_label(player: int) -> String:
	if player == GameLogic.KNIGHT:
		return "Knight pair"
	if player == GameLogic.QUEEN:
		return "Queen pair"
	return "Pair"
