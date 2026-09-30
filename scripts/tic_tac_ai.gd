class_name TicTacAI
extends RefCounted
## Faction-aware AI. Full search on 3×3; depth-limited + threats on 5×5 / 8×8.
## Ladder: Squire (easy, depth 1, no block, never spends a pair),
## Marshal (win, block, and a pair that forks), Regent (one ply deeper).
## `choose_action` assumes it is `ai_player`'s turn. A pair is spent to win,
## to cover threats one stone cannot, or to create two winning threats.
## It is never a quiet extra move on top of a normal place.

const INF := 1_000_000
const WIN_SCORE := 50_000
const RANK_SQUIRE := 0
const RANK_MARSHAL := 1
const RANK_REGENT := 2


func choose_move(logic: GameLogic, rank: int = RANK_MARSHAL, ai_player: int = GameLogic.QUEEN) -> int:
	var action := choose_action(logic, rank, ai_player, false, false)
	var cells: Array = action.get("cells", [])
	if cells.is_empty():
		return -1
	return int(cells[0])


## Returns {cells: Array, power: bool}. `cells` is the placement order.
## allow_power: this side may still spend its pair.
## opponent_power: the other side may still spend its pair on the reply.
func choose_action(logic: GameLogic, rank: int = RANK_MARSHAL, ai_player: int = GameLogic.QUEEN, allow_power: bool = false, opponent_power: bool = false) -> Dictionary:
	var board: PackedInt32Array = logic.snapshot()
	var opp := _other(ai_player)
	var use_power := allow_power and rank >= RANK_MARSHAL and CourtsRules.powers_allowed(logic.size, logic.win_length)
	var opp_power := opponent_power and CourtsRules.powers_allowed(logic.size, logic.win_length)

	var win := _first_winning_place(logic, board, ai_player)
	if win >= 0:
		return _single(win)

	if use_power:
		var pair_win := _first_winning_pair(logic, board, ai_player)
		if not pair_win.is_empty():
			return {"cells": pair_win, "power": true}

	if rank > RANK_SQUIRE:
		var shapes := _threat_shapes(logic, board, opp, opp_power)
		if not shapes.is_empty():
			var cover := _cover_shapes(logic, board, shapes, ai_player, use_power)
			if not cover.is_empty():
				return cover
			var partial := _best_partial_cover(logic, board, shapes, ai_player)
			if partial >= 0:
				return _single(partial)

	if use_power and not _has_single_double_threat(logic, board, ai_player):
		var fork := _best_fork_pair(logic, board, ai_player, opp, opp_power)
		if not fork.is_empty():
			return {"cells": fork, "power": true}

	var moves: Array[int] = _candidate_moves(logic, board)
	if moves.is_empty():
		moves = logic.legal_moves_of(board)
	if moves.is_empty():
		return {"cells": [], "power": false}

	var remaining: int = logic.empty_count(board)
	var depth: int = _search_depth(logic, remaining, rank)
	if logic.size >= 8 and moves.size() > 14:
		moves = _top_heuristic_moves(logic, board, moves, 14, ai_player, ai_player)

	var best_score := -INF
	var best_moves: Array[int] = []
	for m in moves:
		board[m] = ai_player
		var score: int
		if logic.winner_from_move(board, m) == ai_player:
			score = WIN_SCORE + depth
		elif depth <= 1:
			score = _heuristic(logic, board, ai_player)
		else:
			score = _minimax(logic, board, depth - 1, -INF, INF, opp, ai_player)
		board[m] = GameLogic.EMPTY
		if score > best_score:
			best_score = score
			best_moves = [m]
		elif score == best_score:
			best_moves.append(m)

	if best_moves.is_empty():
		return _single(moves[0])
	return _single(best_moves[randi() % best_moves.size()])


func _single(index: int) -> Dictionary:
	return {"cells": [index], "power": false}


func _other(player: int) -> int:
	return GameLogic.QUEEN if player == GameLogic.KNIGHT else GameLogic.KNIGHT


func _first_winning_place(logic: GameLogic, board: PackedInt32Array, player: int) -> int:
	var best := -1
	for i in logic.cell_count:
		if board[i] != GameLogic.EMPTY:
			continue
		board[i] = player
		var wins := logic.winner_from_move(board, i) == player
		board[i] = GameLogic.EMPTY
		if wins and (best < 0 or _closer(logic, i, best)):
			best = i
	return best


func _closer(logic: GameLogic, a: int, b: int) -> bool:
	var mid := (logic.size - 1) * 0.5
	var ar := int(a / float(logic.size))
	var ac := a % logic.size
	var br := int(b / float(logic.size))
	var bc := b % logic.size
	var da := absf(ar - mid) + absf(ac - mid)
	var db := absf(br - mid) + absf(bc - mid)
	if da == db:
		return a < b
	return da < db


func _first_winning_pair(logic: GameLogic, board: PackedInt32Array, player: int) -> Array:
	var best: Array = []
	for pair in CourtsRules.unordered_pairs(logic, board, player):
		var order: Array = _winning_order(logic, board, player, pair.x, pair.y)
		if order.is_empty():
			continue
		if best.is_empty() or _pair_less(order, best):
			best = order
	return best


func _low_high(a: int, b: int) -> Array:
	var order: Array = []
	if a < b:
		order.append(a)
		order.append(b)
	else:
		order.append(b)
		order.append(a)
	return order


func _winning_order(logic: GameLogic, board: PackedInt32Array, player: int, a: int, b: int) -> Array:
	var first: Array = _low_high(a, b)
	if _order_wins(logic, board, player, first):
		return first
	var swap: Array = [first[1], first[0]]
	if _order_wins(logic, board, player, swap):
		return swap
	return []


func _order_wins(logic: GameLogic, board: PackedInt32Array, player: int, order: Array) -> bool:
	var placed := CourtsRules.apply_ordered(logic, board, player, int(order[0]), int(order[1]))
	var won := logic.winner_of(board) == player
	CourtsRules.undo(board, placed)
	return won and not placed.is_empty()


func _pair_less(a: Array, b: Array) -> bool:
	if int(a[0]) == int(b[0]):
		return int(a[1]) < int(b[1])
	return int(a[0]) < int(b[0])


func _threat_shapes(logic: GameLogic, board: PackedInt32Array, player: int, allow_power: bool) -> Array:
	var shapes: Array = []
	for i in logic.cell_count:
		if board[i] != GameLogic.EMPTY:
			continue
		board[i] = player
		if logic.winner_from_move(board, i) == player:
			shapes.append([i])
		board[i] = GameLogic.EMPTY
	if not allow_power:
		return shapes
	for pair in CourtsRules.unordered_pairs(logic, board, player):
		var order := _winning_order(logic, board, player, pair.x, pair.y)
		if order.is_empty():
			continue
		var placed := CourtsRules.apply_ordered(logic, board, player, int(order[0]), int(order[1]))
		if logic.winner_of(board) == player and placed.size() >= 2:
			shapes.append(placed.duplicate())
		CourtsRules.undo(board, placed)
	return shapes


func _cover_shapes(logic: GameLogic, board: PackedInt32Array, shapes: Array, player: int, allow_power: bool) -> Dictionary:
	for m in _center_order(logic):
		if board[m] != GameLogic.EMPTY:
			continue
		if _hits_all(shapes, [m]):
			return _single(m)
	if not allow_power:
		return {}
	var best: Array = []
	for pair in CourtsRules.unordered_pairs(logic, board, player):
		var order: Array = _low_high(pair.x, pair.y)
		var placed := CourtsRules.apply_ordered(logic, board, player, int(order[0]), int(order[1]))
		var hits := placed.size() >= 2 and _hits_all(shapes, placed)
		CourtsRules.undo(board, placed)
		if hits and (best.is_empty() or _pair_less(order, best)):
			best = order
	if best.is_empty():
		return {}
	return {"cells": best, "power": true}


func _best_partial_cover(logic: GameLogic, board: PackedInt32Array, shapes: Array, player: int) -> int:
	var best := -1
	var best_hits := 0
	for m in _center_order(logic):
		if board[m] != GameLogic.EMPTY:
			continue
		var hits := 0
		for shape in shapes:
			if _intersects([m], shape):
				hits += 1
		if hits > best_hits:
			best_hits = hits
			best = m
	if best_hits <= 0:
		return -1
	return best


func _hits_all(shapes: Array, placed: Array) -> bool:
	for shape in shapes:
		if not _intersects(placed, shape):
			return false
	return true


func _intersects(a: Array, b: Array) -> bool:
	for x in a:
		for y in b:
			if int(x) == int(y):
				return true
	return false


func _has_single_double_threat(logic: GameLogic, board: PackedInt32Array, player: int) -> bool:
	for i in logic.cell_count:
		if board[i] != GameLogic.EMPTY:
			continue
		board[i] = player
		var n := 0
		if logic.winner_from_move(board, i) != player:
			n = _winning_cells(logic, board, player).size()
		board[i] = GameLogic.EMPTY
		if n >= 2:
			return true
	return false


func _best_fork_pair(logic: GameLogic, board: PackedInt32Array, player: int, opp: int, opp_power: bool) -> Array:
	var best: Array = []
	var best_threats := 1
	var seen := 0
	for pair in CourtsRules.unordered_pairs(logic, board, player):
		if not _near_stone(logic, board, pair.x) and not _near_stone(logic, board, pair.y):
			continue
		if seen >= 80:
			break
		seen += 1
		var order: Array = _low_high(pair.x, pair.y)
		var placed := CourtsRules.apply_ordered(logic, board, player, int(order[0]), int(order[1]))
		var threats := 0
		if placed.size() >= 2 and logic.winner_of(board) != player:
			threats = _winning_cells(logic, board, player).size()
			if threats >= 2 and _can_win_now(logic, board, opp, opp_power):
				threats = 0
		CourtsRules.undo(board, placed)
		if threats > best_threats or (threats == best_threats and threats >= 2 and (best.is_empty() or _pair_less(order, best))):
			best_threats = threats
			best = order
	if best_threats < 2:
		return []
	return best


func _near_stone(logic: GameLogic, board: PackedInt32Array, index: int) -> bool:
	var n := logic.size
	var r := int(index / float(n))
	var c := index % n
	for dr in range(-2, 3):
		for dc in range(-2, 3):
			if dr == 0 and dc == 0:
				continue
			var rr := r + dr
			var cc := c + dc
			if rr < 0 or cc < 0 or rr >= n or cc >= n:
				continue
			if board[rr * n + cc] != GameLogic.EMPTY:
				return true
	return false


func _winning_cells(logic: GameLogic, board: PackedInt32Array, player: int) -> Array[int]:
	var out: Array[int] = []
	for i in logic.cell_count:
		if board[i] != GameLogic.EMPTY:
			continue
		board[i] = player
		if logic.winner_from_move(board, i) == player:
			out.append(i)
		board[i] = GameLogic.EMPTY
	return out


func _can_win_now(logic: GameLogic, board: PackedInt32Array, player: int, allow_power: bool) -> bool:
	if _first_winning_place(logic, board, player) >= 0:
		return true
	if not allow_power:
		return false
	return not _first_winning_pair(logic, board, player).is_empty()


func _search_depth(logic: GameLogic, remaining: int, rank: int = RANK_MARSHAL) -> int:
	var depth := _base_depth(logic, remaining)
	if rank == RANK_SQUIRE:
		return mini(1, remaining)
	if rank == RANK_REGENT:
		if logic.size <= 3:
			return remaining
		if logic.size >= 8:
			return mini(remaining, maxi(depth, 3))
		return mini(remaining, depth + 1)
	return depth


func _base_depth(logic: GameLogic, remaining: int) -> int:
	if logic.size <= 3:
		return remaining
	if logic.size <= 5:
		if remaining <= 8:
			return remaining
		if remaining <= 14:
			return 4
		return 3
	if remaining <= 10:
		return 3
	return 2


func _minimax(logic: GameLogic, board: PackedInt32Array, depth: int, alpha: int, beta: int, side: int, ai_player: int) -> int:
	if logic.is_full_board(board):
		return 0
	if depth <= 0:
		return _heuristic(logic, board, ai_player)

	var moves: Array[int] = _candidate_moves(logic, board)
	if moves.is_empty():
		return _heuristic(logic, board, ai_player)
	if logic.size >= 8 and moves.size() > 12:
		moves = _top_heuristic_moves(logic, board, moves, 12, side, ai_player)

	var next := _other(side)
	if side == ai_player:
		var best := -INF
		for m in moves:
			board[m] = side
			if logic.winner_from_move(board, m) == side:
				board[m] = GameLogic.EMPTY
				return WIN_SCORE + depth
			best = maxi(best, _minimax(logic, board, depth - 1, alpha, beta, next, ai_player))
			board[m] = GameLogic.EMPTY
			alpha = maxi(alpha, best)
			if beta <= alpha:
				break
		return best

	var best_min := INF
	for m in moves:
		board[m] = side
		if logic.winner_from_move(board, m) == side:
			board[m] = GameLogic.EMPTY
			return -WIN_SCORE - depth
		best_min = mini(best_min, _minimax(logic, board, depth - 1, alpha, beta, next, ai_player))
		board[m] = GameLogic.EMPTY
		beta = mini(beta, best_min)
		if beta <= alpha:
			break
	return best_min


func _heuristic(logic: GameLogic, board: PackedInt32Array, ai_player: int) -> int:
	var score := 0
	var k: int = logic.win_length
	var opp := _other(ai_player)
	for line in logic.win_lines:
		var ours := 0
		var theirs := 0
		for i in k:
			var v: int = board[line[i]]
			if v == ai_player:
				ours += 1
			elif v == opp:
				theirs += 1
		if ours > 0 and theirs > 0:
			continue
		if ours > 0:
			score += _line_weight(ours, k)
		elif theirs > 0:
			score -= _line_weight(theirs, k)
	var mid := (logic.size - 1) * 0.5
	for i in logic.cell_count:
		if board[i] == GameLogic.EMPTY:
			continue
		var r: int = int(i / float(logic.size))
		var c: int = i % logic.size
		var dist := absf(r - mid) + absf(c - mid)
		var bonus := int(maxf(0.0, (logic.size - dist)) * 1.5)
		if board[i] == ai_player:
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
	for i in _center_order(logic):
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


func _top_heuristic_moves(logic: GameLogic, board: PackedInt32Array, moves: Array[int], keep: int, side: int, ai_player: int) -> Array[int]:
	var scored: Array = []
	for m in moves:
		board[m] = side
		var s: int = _heuristic(logic, board, ai_player)
		board[m] = GameLogic.EMPTY
		scored.append([-s, m])
	scored.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array[int] = []
	for i in mini(keep, scored.size()):
		out.append(int(scored[i][1]))
	return out
