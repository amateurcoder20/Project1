extends Node
## Autoload: match setup and Crown War score survive the menu → game scene change.

enum MiniGame { CLASSIC, COURTS }
enum SeriesKind { CASUAL, BO3, BO5 }
enum AiRank { SQUIRE, MARSHAL, REGENT }

var vs_ai: bool = false
var board_size: int = 3
var mini_game: int = MiniGame.CLASSIC
var series_kind: int = SeriesKind.CASUAL
var ai_rank: int = AiRank.MARSHAL
var knight_wins: int = 0
var queen_wins: int = 0
## Local 2P can dismiss the pass-the-phone card for the rest of the session.
var skip_handoff: bool = false


func is_courts() -> bool:
	return mini_game == MiniGame.COURTS


func win_length() -> int:
	return BoardPreset.win_length(board_size)


func preset_label() -> String:
	return BoardPreset.label(board_size)


func series_target() -> int:
	match series_kind:
		SeriesKind.BO3:
			return 2
		SeriesKind.BO5:
			return 3
		_:
			return 0


func series_label() -> String:
	match series_kind:
		SeriesKind.BO3:
			return "Bo3"
		SeriesKind.BO5:
			return "Bo5"
		_:
			return "Casual"


func rank_label() -> String:
	match ai_rank:
		AiRank.SQUIRE:
			return "Squire"
		AiRank.REGENT:
			return "Regent"
		_:
			return "Marshal"


func mini_game_label() -> String:
	return "Courts" if is_courts() else "Classic"


func score_line() -> String:
	var core := "Knights %d – %d Queens" % [knight_wins, queen_wins]
	var target := series_target()
	if target > 0:
		return "%s  ·  %s, first to %d" % [core, series_label(), target]
	return "%s  ·  %s" % [core, series_label()]


func series_over() -> bool:
	var target := series_target()
	if target <= 0:
		return false
	return knight_wins >= target or queen_wins >= target


func note_winner(player: int) -> void:
	if player == GameLogic.KNIGHT:
		knight_wins += 1
	elif player == GameLogic.QUEEN:
		queen_wins += 1


func reset_series() -> void:
	knight_wins = 0
	queen_wins = 0


func set_mini_game(which: int) -> void:
	if mini_game != which:
		reset_series()
	mini_game = which
	if is_courts() and board_size == 3:
		board_size = 5


func set_board_size(size: int) -> void:
	var clamped := BoardPreset.clamp_size(size)
	if is_courts() and clamped == 3:
		clamped = 5
	if clamped != board_size:
		reset_series()
	board_size = clamped


func set_series_kind(kind: int) -> void:
	if series_kind != kind:
		reset_series()
	series_kind = kind
