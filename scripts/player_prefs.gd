class_name PlayerPrefs
extends RefCounted
## First-run flags. Offline, stored under user://.

const _PATH := "user://kvq_prefs.cfg"


static func has_seen_coach() -> bool:
	return bool(_load().get_value("run", "coach", false))


static func mark_coach_seen() -> void:
	var cfg := _load()
	cfg.set_value("run", "coach", true)
	cfg.save(_PATH)


static func has_seen_courts_hint() -> bool:
	return bool(_load().get_value("run", "courts_hint", false))


static func mark_courts_hint_seen() -> void:
	var cfg := _load()
	cfg.set_value("run", "courts_hint", true)
	cfg.save(_PATH)


static func _load() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(_PATH)
	return cfg
