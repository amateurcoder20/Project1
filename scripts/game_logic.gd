class_name GameLogic
extends RefCounted
## NxN tic-tac-toe with a configurable win length. No nodes.

const EMPTY := 0
const KNIGHT := 1
const QUEEN := 2

var size: int = 3
var win_length: int = 3
var cell_count: int = 9
var win_lines: Array = []
## win_lines that include each cell, for fast post-move checks.
var lines_through: Array = []

var cells: PackedInt32Array
var current_player: int = KNIGHT


func _init(p_size: int = 3, p_win_length: int = 3) -> void:
	size = maxi(p_size, 1)
	win_length = clampi(p_win_length, 1, size)
	cell_count = size * size
	_build_win_lines()
	reset()


func reset() -> void:
	cells = PackedInt32Array()
	cells.resize(cell_count)
	cells.fill(EMPTY)
	current_player = KNIGHT


func is_legal(index: int) -> bool:
	return index >= 0 and index < cell_count and cells[index] == EMPTY


func place(index: int) -> bool:
	if not is_legal(index):
		return false
	cells[index] = current_player
	return true


func switch_player() -> void:
	current_player = QUEEN if current_player == KNIGHT else KNIGHT


func winner() -> int:
	return winner_of(cells)


func is_full() -> bool:
	return is_full_board(cells)


func is_draw() -> bool:
	return winner() == EMPTY and is_full()


func is_game_over() -> bool:
	return winner() != EMPTY or is_full()


func legal_moves() -> Array[int]:
	return legal_moves_of(cells)


func winning_line() -> Array:
	return winning_line_of(cells)


func snapshot() -> PackedInt32Array:
	return cells.duplicate()


func winner_of(board: PackedInt32Array) -> int:
	for line in win_lines:
		var a: int = board[line[0]]
		if a == EMPTY:
			continue
		var ok := true
		for i in range(1, win_length):
			if board[line[i]] != a:
				ok = false
				break
		if ok:
			return a
	return EMPTY


func winner_from_move(board: PackedInt32Array, index: int) -> int:
	var a: int = board[index]
	if a == EMPTY or index < 0 or index >= cell_count:
		return EMPTY
	for line in lines_through[index]:
		var ok := true
		for i in win_length:
			if board[line[i]] != a:
				ok = false
				break
		if ok:
			return a
	return EMPTY


func winning_line_of(board: PackedInt32Array) -> Array:
	for line in win_lines:
		var a: int = board[line[0]]
		if a == EMPTY:
			continue
		var ok := true
		for i in range(1, win_length):
			if board[line[i]] != a:
				ok = false
				break
		if ok:
			return line
	return []


func is_full_board(board: PackedInt32Array) -> bool:
	for i in cell_count:
		if board[i] == EMPTY:
			return false
	return true


func legal_moves_of(board: PackedInt32Array) -> Array[int]:
	var moves: Array[int] = []
	for i in cell_count:
		if board[i] == EMPTY:
			moves.append(i)
	return moves


func empty_count(board: PackedInt32Array) -> int:
	var n := 0
	for i in cell_count:
		if board[i] == EMPTY:
			n += 1
	return n


func idx(row: int, col: int) -> int:
	return row * size + col


static func player_name(player: int) -> String:
	match player:
		KNIGHT:
			return "Knights"
		QUEEN:
			return "Queens"
		_:
			return "None"


func _build_win_lines() -> void:
	win_lines = []
	lines_through.clear()
	lines_through.resize(cell_count)
	for i in cell_count:
		lines_through[i] = []
	var n := size
	var k := win_length
	# Rows
	for r in n:
		for c in range(0, n - k + 1):
			var line: Array = []
			for i in k:
				line.append(idx(r, c + i))
			_register_line(line)
	# Columns
	for c in n:
		for r in range(0, n - k + 1):
			var line: Array = []
			for i in k:
				line.append(idx(r + i, c))
			_register_line(line)
	# Diagonal down-right
	for r in range(0, n - k + 1):
		for c in range(0, n - k + 1):
			var line: Array = []
			for i in k:
				line.append(idx(r + i, c + i))
			_register_line(line)
	# Diagonal down-left
	for r in range(0, n - k + 1):
		for c in range(k - 1, n):
			var line: Array = []
			for i in k:
				line.append(idx(r + i, c - i))
			_register_line(line)


func _register_line(line: Array) -> void:
	win_lines.append(line)
	for cell in line:
		lines_through[int(cell)].append(line)
