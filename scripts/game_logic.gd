class_name GameLogic
extends RefCounted
## Pure 4×4 tic-tac-toe rules. No nodes, safe to unit-test headless.

const SIZE := 4
const CELLS := 16
const EMPTY := 0
const KNIGHT := 1
const QUEEN := 2

const WIN_LINES := [
	[0, 1, 2, 3],
	[4, 5, 6, 7],
	[8, 9, 10, 11],
	[12, 13, 14, 15],
	[0, 4, 8, 12],
	[1, 5, 9, 13],
	[2, 6, 10, 14],
	[3, 7, 11, 15],
	[0, 5, 10, 15],
	[3, 6, 9, 12],
]

var cells: PackedInt32Array
var current_player: int = KNIGHT


func _init() -> void:
	reset()


func reset() -> void:
	cells = PackedInt32Array()
	cells.resize(CELLS)
	cells.fill(EMPTY)
	current_player = KNIGHT


func is_legal(index: int) -> bool:
	return index >= 0 and index < CELLS and cells[index] == EMPTY


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


static func winner_of(board: PackedInt32Array) -> int:
	for line in WIN_LINES:
		var a: int = board[line[0]]
		if a != EMPTY and a == board[line[1]] and a == board[line[2]] and a == board[line[3]]:
			return a
	return EMPTY


static func winning_line_of(board: PackedInt32Array) -> Array:
	for line in WIN_LINES:
		var a: int = board[line[0]]
		if a != EMPTY and a == board[line[1]] and a == board[line[2]] and a == board[line[3]]:
			return line
	return []


static func is_full_board(board: PackedInt32Array) -> bool:
	for i in CELLS:
		if board[i] == EMPTY:
			return false
	return true


static func legal_moves_of(board: PackedInt32Array) -> Array[int]:
	var moves: Array[int] = []
	for i in CELLS:
		if board[i] == EMPTY:
			moves.append(i)
	return moves


static func empty_count(board: PackedInt32Array) -> int:
	var n := 0
	for i in CELLS:
		if board[i] == EMPTY:
			n += 1
	return n


static func player_name(player: int) -> String:
	match player:
		KNIGHT:
			return "Knights"
		QUEEN:
			return "Queens"
		_:
			return "None"
