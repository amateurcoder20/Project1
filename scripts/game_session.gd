extends Node
## Autoload: mode + board preset survive the menu → game scene change.

var vs_ai: bool = false
var board_size: int = 3


func win_length() -> int:
	return BoardPreset.win_length(board_size)


func preset_label() -> String:
	return BoardPreset.label(board_size)
