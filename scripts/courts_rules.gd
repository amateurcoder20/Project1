class_name CourtsRules
extends RefCounted
## Courts placement powers. Classic never calls this.
## Each side may spend its power once per game, instead of a normal drop.
## Leap (Knights): empty cell a knight move (2×1) from one of your pieces.
## Command Tight (Queens): empty cell on the same row or column, orthogonal
## distance ≤ 2, with no piece between. The chip label is "Command".


const _KNIGHT_DELTAS: Array[Vector2i] = [
	Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2),
	Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1),
]

const _ORTHO: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]


static func cells_for(logic: GameLogic, player: int) -> Array[int]:
	if player == GameLogic.KNIGHT:
		return leap_cells(logic, player)
	if player == GameLogic.QUEEN:
		return command_cells(logic, player)
	return []


static func leap_cells(logic: GameLogic, player: int) -> Array[int]:
	var marked := PackedByteArray()
	marked.resize(logic.cell_count)
	var out: Array[int] = []
	var n: int = logic.size
	for i in logic.cell_count:
		if logic.cells[i] != player:
			continue
		var row: int = int(i / float(n))
		var col: int = i % n
		for d in _KNIGHT_DELTAS:
			var rr: int = row + d.y
			var cc: int = col + d.x
			if rr < 0 or cc < 0 or rr >= n or cc >= n:
				continue
			var j: int = logic.idx(rr, cc)
			if logic.cells[j] != GameLogic.EMPTY or marked[j] == 1:
				continue
			marked[j] = 1
			out.append(j)
	return out


static func command_cells(logic: GameLogic, player: int) -> Array[int]:
	var marked := PackedByteArray()
	marked.resize(logic.cell_count)
	var out: Array[int] = []
	var n: int = logic.size
	for i in logic.cell_count:
		if logic.cells[i] != player:
			continue
		var row: int = int(i / float(n))
		var col: int = i % n
		for d in _ORTHO:
			for dist in range(1, 3):
				var rr: int = row + d.y * dist
				var cc: int = col + d.x * dist
				if rr < 0 or cc < 0 or rr >= n or cc >= n:
					break
				var j: int = logic.idx(rr, cc)
				if logic.cells[j] != GameLogic.EMPTY:
					break
				if marked[j] == 0:
					marked[j] = 1
					out.append(j)
	return out


static func chip_label(player: int) -> String:
	if player == GameLogic.KNIGHT:
		return "Leap"
	if player == GameLogic.QUEEN:
		return "Command"
	return "Power"
