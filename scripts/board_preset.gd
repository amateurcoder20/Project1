class_name BoardPreset
extends RefCounted
## The three supported boards. Win length is fixed per size.

const SIZES: Array[int] = [3, 5, 8]


static func win_length(size: int) -> int:
	match size:
		3:
			return 3
		5:
			return 4
		8:
			return 5
		_:
			return 3


static func is_valid(size: int) -> bool:
	return size == 3 or size == 5 or size == 8


static func clamp_size(size: int) -> int:
	return size if is_valid(size) else 3


static func label(size: int) -> String:
	var s: int = clamp_size(size)
	return "%d×%d · win %d" % [s, s, win_length(s)]


static func short_label(size: int) -> String:
	var s: int = clamp_size(size)
	return "%d×%d" % [s, s]
