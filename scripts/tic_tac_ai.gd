class_name TicTacAI
extends RefCounted
## Queens AI. Full search on 3×3; depth-limited + threats on 5×5 / 8×8.

const INF := 1_000_000
const WIN_SCORE := 50_000


func choose_move(logic: GameLogic) -> int:
	var board: PackedInt32Array = logic.snapshot()
	var moves: Array[int] = _candidate_moves(logic, board)
	if moves.is_empty():
		moves = logic.legal_moves_of(board)
	if moves.is_empty():
		return -1

	# 1. Take a winning Queen move.
	for m in moves:
		board[m] = GameLogic.QUEEN
		if logic.winner_from_move(board, m) == GameLogic.QUEEN:
			board[m] = GameLogic.EMPTY
			return m
		board[m] = GameLogic.EMPTY

	# 2. Block a Knight win.
	for m in moves:
		board[m] = GameLogic.KNIGHT
		var knight_wins := logic.winner_from_move(board, m) == GameLogic.KNIGHT
		board[m] = GameLogic.EMPTY
		if knight_wins:
			return m

	# 3. On larger boards, grab / deny (win_length - 1) open threats before search.
	if logic.size >= 5:
		var threat: int = _open_threat_move(logic, board, moves, GameLogic.QUEEN)
		if threat >= 0:
			return threat
		threat = _open_threat_move(logic, board, moves, GameLogic.KNIGHT)
		if threat >= 0:
			return threat

	var remaining: int = logic.empty_count(board)
	var depth: int = _search_depth(logic, remaining)
	if logic.size >= 8 and moves.size() > 14:
		moves = _top_heuristic_moves(logic, board, moves, 14)

	var best_score := -INF
	var best_moves: Array[int] = []
	for m in moves:
		board[m] = GameLogic.QUEEN
		var score: int
		if depth <= 1:
			score = _heuristic(logic, board)
		else:
			score = _minimax(logic, board, depth - 1, -INF, INF, false)
		board[m] = GameLogic.EMPTY
		if score > best_score:
			best_score = score
			best_moves = [m]
		elif score == best_score:
			best_moves.append(m)

	if best_moves.is_empty():
		return moves[0]
	return best_moves[randi() % best_moves.size()]


func _search_depth(logic: GameLogic, remaining: int) -> int:
	if logic.size <= 3:
		return remaining
	if logic.size <= 5:
		if remaining <= 8:
			return remaining
		if remaining <= 14:
			return 4
		return 3
	# 8×8
	if remaining <= 10:
		return 3
	return 2


func _minimax(logic: GameLogic, board: PackedInt32Array, depth: int, alpha: int, beta: int, maximizing: bool) -> int:
	if logic.is_full_board(board):
		return 0
	if depth <= 0:
		return _heuristic(logic, board)

	var moves: Array[int] = _candidate_moves(logic, board)
	if moves.is_empty():
		return _heuristic(logic, board)
	if logic.size >= 8 and moves.size() > 12:
		moves = _top_heuristic_moves(logic, board, moves, 12)

	if maximizing:
		var best := -INF
		for m in moves:
			board[m] = GameLogic.QUEEN
			if logic.winner_from_move(board, m) == GameLogic.QUEEN:
				board[m] = GameLogic.EMPTY
				return WIN_SCORE + depth
			best = maxi(best, _minimax(logic, board, depth - 1, alpha, beta, false))
			board[m] = GameLogic.EMPTY
			alpha = maxi(alpha, best)
			if beta <= alpha:
				break
		return best

	var best_min := INF
	for m in moves:
		board[m] = GameLogic.KNIGHT
		if logic.winner_from_move(board, m) == GameLogic.KNIGHT:
			board[m] = GameLogic.EMPTY
			return -WIN_SCORE - depth
		best_min = mini(best_min, _minimax(logic, board, depth - 1, alpha, beta, true))
		board[m] = GameLogic.EMPTY
		beta = mini(beta, best_min)
		if beta <= alpha:
			break
	return best_min


func _heuristic(logic: GameLogic, board: PackedInt32Array) -> int:
	var score := 0
	var k: int = logic.win_length
	for line in logic.win_lines:
		var queens := 0
		var knights := 0
		for i in k:
			var v: int = board[line[i]]
			if v == GameLogic.QUEEN:
				queens += 1
			elif v == GameLogic.KNIGHT:
				knights += 1
		if queens > 0 and knights > 0:
			continue
		if queens > 0:
			score += _line_weight(queens, k)
		elif knights > 0:
			score -= _line_weight(knights, k)
	# Center gravity
	var mid := (logic.size - 1) * 0.5
	for i in logic.cell_count:
		if board[i] == GameLogic.EMPTY:
			continue
		var r: int = int(i / float(logic.size))
		var c: int = i % logic.size
		var dist := absf(r - mid) + absf(c - mid)
		var bonus := int(maxf(0.0, (logic.size - dist)) * 1.5)
		if board[i] == GameLogic.QUEEN:
			score += bonus
		else:
			score -= bonus
	return score


func _line_weight(count: int, win_len: int) -> int:
	if count >= win_len:
		return WIN_SCORE
	if count == win_len - 1:
		return 4000
	if count == win_len - 2:
		return 220
	if count == 1:
		return 8
	return 40


func _open_threat_move(logic: GameLogic, board: PackedInt32Array, moves: Array[int], player: int) -> int:
	## A cell that completes (win_length - 1) of `player` on an otherwise empty line.
	var need: int = logic.win_length - 1
	if need < 2:
		return -1
	for m in moves:
		for line in logic.lines_through[m]:
			var ours := 0
			var enemy := 0
			var empty := 0
			for i in logic.win_length:
				var v: int = board[line[i]]
				if v == player:
					ours += 1
				elif v == GameLogic.EMPTY:
					empty += 1
				else:
					enemy += 1
			if enemy == 0 and ours == need and empty == 1:
				return m
	return -1


func _candidate_moves(logic: GameLogic, board: PackedInt32Array) -> Array[int]:
	if logic.size <= 3:
		return _ordered_all(logic, board)
	var n: int = logic.size
	var radius := 2 if logic.size <= 5 else 1
	var occupied := 0
	for i in logic.cell_count:
		if board[i] != GameLogic.EMPTY:
			occupied += 1
	if occupied <= 1:
		return _ordered_all(logic, board)
	if occupied < 6 and logic.size >= 8:
		radius = 2

	var marked := PackedByteArray()
	marked.resize(logic.cell_count)
	for i in logic.cell_count:
		if board[i] == GameLogic.EMPTY:
			continue
		var r: int = int(i / float(n))
		var c: int = i % n
		for dr in range(-radius, radius + 1):
			for dc in range(-radius, radius + 1):
				var rr: int = r + dr
				var cc: int = c + dc
				if rr < 0 or cc < 0 or rr >= n or cc >= n:
					continue
				var j: int = rr * n + cc
				if board[j] == GameLogic.EMPTY:
					marked[j] = 1

	var moves: Array[int] = []
	# Center-first among marked.
	var order: Array[int] = _center_order(logic)
	for i in order:
		if marked[i] == 1:
			moves.append(i)
	if moves.is_empty():
		return _ordered_all(logic, board)
	return moves


func _ordered_all(logic: GameLogic, board: PackedInt32Array) -> Array[int]:
	var moves: Array[int] = []
	for i in _center_order(logic):
		if board[i] == GameLogic.EMPTY:
			moves.append(i)
	return moves


func _center_order(logic: GameLogic) -> Array[int]:
	var n: int = logic.size
	var mid := (n - 1) * 0.5
	var scored: Array = []
	for i in logic.cell_count:
		var r: int = int(i / float(n))
		var c: int = i % n
		var d := absf(r - mid) + absf(c - mid)
		scored.append([d, i])
	scored.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array[int] = []
	for pair in scored:
		out.append(int(pair[1]))
	return out


func _top_heuristic_moves(logic: GameLogic, board: PackedInt32Array, moves: Array[int], keep: int) -> Array[int]:
	var scored: Array = []
	for m in moves:
		board[m] = GameLogic.QUEEN
		var s: int = _heuristic(logic, board)
		board[m] = GameLogic.EMPTY
		scored.append([-s, m]) # sort ascending by -score => best first
	scored.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array[int] = []
	for i in mini(keep, scored.size()):
		out.append(int(scored[i][1]))
	return out
