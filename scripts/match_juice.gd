class_name MatchJuice
extends Node
## Short place / power / win tones plus a phone vibrate. No external assets.

var _place: AudioStreamPlayer
var _power: AudioStreamPlayer
var _win: AudioStreamPlayer


func _ready() -> void:
	_place = _player(_thud(150.0, 0.09, 0.5))
	_power = _player(_thud(420.0, 0.11, 0.42))
	_win = _player(_fanfare())


func play_place(powered: bool) -> void:
	_buzz(28 if powered else 16)
	var player := _power if powered else _place
	player.play()


func play_win() -> void:
	_buzz(46)
	_win.play()


func _player(stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -8.0
	add_child(p)
	return p


func _buzz(ms: int) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func _thud(freq: float, seconds: float, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(float(rate) * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq * 13.0) + 7
	for i in n:
		var t := float(i) / float(n)
		var env := pow(1.0 - t, 2.2)
		var tone := sin(TAU * freq * float(i) / float(rate))
		var noise := rng.randf_range(-1.0, 1.0)
		var amp := (tone * 0.72 + noise * 0.28) * env * vol
		data.encode_s16(i * 2, int(clampf(amp, -1.0, 1.0) * 32000.0))
	return _stream(data, rate)


func _fanfare() -> AudioStreamWAV:
	var rate := 22050
	var notes: Array[float] = [523.25, 659.25, 783.99]
	var step := int(float(rate) * 0.12)
	var n := step * notes.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var note_i := int(i / float(step))
		var local := i - note_i * step
		var env := pow(1.0 - float(local) / float(step), 1.4)
		var amp := sin(TAU * notes[note_i] * float(i) / float(rate)) * env * 0.4
		data.encode_s16(i * 2, int(clampf(amp, -1.0, 1.0) * 32000.0))
	return _stream(data, rate)


func _stream(data: PackedByteArray, rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
