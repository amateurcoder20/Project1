class_name TicTacAI
extends RefCounted
## Depth-limited minimax with alpha-beta pruning for 4×4 / 4-in-a-row.
## AI always plays Queens (player 2). Immediate win/block is checked first.

const INF := 1_000_000
const WIN_SCORE := 50_000

## Prefer center squares, then corners, then edges when scores tie-break.
const MOVE_ORDER: Array[int] = [5, 6, 9, 10, 0, 3, 12, 15, 1, 2, 4, 7, 8, 11, 13, 14]


func choose_move(logic: GameLogic) -> int:
	var board: PackedInt32Array = logic.snapshot()
	var moves: Array[int] = _ordered_moves(board)
	if moves.is_empty():
		return -1

	# 1. Take a winning Queen move immediately.
	for m in moves:
		board[m] = GameLogic.QUEEN
		if GameLogic.winner_of(board) == GameLogic.QUEEN:
			board[m] = GameLogic.EMPTY
			return m
		board[m] = GameLogic.EMPTY

	# 2. Block a Knight win on the next ply.
	for m in moves:
		board[m] = GameLogic.KNIGHT
		var knight_wins := GameLogic.winner_of(board) == GameLogic.KNIGHT
		board[m] = GameLogic.EMPTY
		if knight_wins:
			return m

	var remaining: int = GameLogic.empty_count(board)
	var depth: int
	if remaining <= 7:
		depth = remaining # solve the endgame
	elif remaining <= 10:
		depth = 6
	else:
		depth = 5

	var best_score := -INF
	var best_moves: Array[int] = []
	for m in moves:
		board[m] = GameLogic.QUEEN
		var score := _minimax(board, depth - 1, -INF, INF, false)
		board[m] = GameLogic.EMPTY
		if score > best_score:
			best_score = score
			best_moves = [m]
		elif score == best_score:
			best_moves.append(m)

	if best_moves.is_empty():
		return moves[0]
	return best_moves[randi() % best_moves.size()]


func _minimax(board: PackedInt32Array, depth: int, alpha: int, beta: int, maximizing: bool) -> int:
	var w: int = GameLogic.winner_of(board)
	if w == GameLogic.QUEEN:
		return WIN_SCORE + depth
	if w == GameLogic.KNIGHT:
		return -WIN_SCORE - depth
	if depth <= 0 or GameLogic.is_full_board(board):
		return _heuristic(board)

	var moves: Array[int] = _ordered_moves(board)
	if maximizing:
		var best := -INF
		for m in moves:
			board[m] = GameLogic.QUEEN
			best = maxi(best, _minimax(board, depth - 1, alpha, beta, false))
			board[m] = GameLogic.EMPTY
			alpha = maxi(alpha, best)
			if beta <= alpha:
				break
		return best
	var best_min := INF
	for m in moves:
		board[m] = GameLogic.KNIGHT
		best_min = mini(best_min, _minimax(board, depth - 1, alpha, beta, true))
		board[m] = GameLogic.EMPTY
		beta = mini(beta, best_min)
		if beta <= alpha:
			break
	return best_min


func _heuristic(board: PackedInt32Array) -> int:
	var score := 0
	for line in GameLogic.WIN_LINES:
		var queens := 0
		var knights := 0
		for i in 4:
			var v: int = board[line[i]]
			if v == GameLogic.QUEEN:
				queens += 1
			elif v == GameLogic.KNIGHT:
				knights += 1
		if queens > 0 and knights > 0:
			continue
		if queens > 0:
			score += _line_weight(queens)
		elif knights > 0:
			score -= _line_weight(knights)
	# Slight center preference so opening play isn't random edges.
	for i in [5, 6, 9, 10]:
		if board[i] == GameLogic.QUEEN:
			score += 4
		elif board[i] == GameLogic.KNIGHT:
			score -= 4
	return score


func _line_weight(count: int) -> int:
	match count:
		1:
			return 8
		2:
			return 70
		3:
			return 800
		4:
			return WIN_SCORE
		_:
			return 0


func _ordered_moves(board: PackedInt32Array) -> Array[int]:
	var moves: Array[int] = []
	for i in MOVE_ORDER:
		if board[i] == GameLogic.EMPTY:
			moves.append(i)
	return moves
