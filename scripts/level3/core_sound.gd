extends Node
## Deterministic, audible PCM synthesis; no downloaded or silent placeholder assets.

var ambience: AudioStreamPlayer
var cue: AudioStreamPlayer
var rattle: AudioStreamPlayer
var future: bool = false
var _rattle_left: float = 5.0
var _audible: bool = true


func _ready() -> void:
	# Dedicated/headless runs have no listener or sound device. Do not start looping
	# WAV playback on Godot's dummy driver (it retains playback until process exit).
	_audible = DisplayServer.get_name() != "headless"
	# Existing AudioDirector creates buses and applies the user's saved levels/mutes.
	var director: Node = load("res://scenes/audio/audio_system.tscn").instantiate()
	director.name = "AudioSystem"
	add_child(director)
	ambience = AudioStreamPlayer.new()
	ambience.bus = &"Ambience"
	ambience.volume_db = -26
	add_child(ambience)
	cue = AudioStreamPlayer.new()
	cue.bus = &"SFX"
	cue.volume_db = -15
	add_child(cue)
	rattle = AudioStreamPlayer.new()
	rattle.bus = &"Ambience"
	rattle.volume_db = -28
	add_child(rattle)


func set_role(role: String) -> void:
	future = role == "future"
	var stream := tone([48.0, 72.0, 145.0] if future else [60.0, 120.0, 180.0], 2.0, true)
	ambience.stream = stream
	if _audible: ambience.play()


func play(id: String) -> void:
	var notes := {"activate": [110.0, 220.0], "phase": [330.0, 440.0, 660.0],
		"warning": [220.0, 185.0], "overload": [93.0, 87.0, 65.0],
		"trust": [261.63, 329.63, 392.0, 523.25], "student_override": [261.63, 311.13, 369.99],
		"professor_override": [146.83, 174.61, 220.0], "paradox": [220.0, 233.08, 116.54, 110.0],
		"signal": [659.25, 698.46, 493.88]}
	cue.stream = tone(notes.get(id, [440.0]), 1.8 if id in ["trust", "student_override", "professor_override", "paradox"] else 0.7)
	if _audible: cue.play()


func _process(delta: float) -> void:
	if not future or not _audible: return
	_rattle_left -= delta
	if _rattle_left <= 0:
		_rattle_left = 7.0
		rattle.stream = tone([91.0, 137.0, 379.0], 0.32)
		rattle.play()


func _exit_tree() -> void:
	for player: AudioStreamPlayer in [ambience, cue, rattle]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null


static func tone(notes: Array, duration: float, loop: bool = false) -> AudioStreamWAV:
	const RATE := 22050
	var pcm := PackedByteArray()
	var count := int(duration * RATE)
	pcm.resize(count * 2)
	for i in range(count):
		var t := float(i) / RATE
		var value := 0.0
		if loop:
			for n: float in notes: value += sin(TAU * n * t) / notes.size()
		else:
			var section := mini(int(t / duration * notes.size()), notes.size() - 1)
			var envelope := sin(PI * fmod(t / duration * notes.size(), 1.0))
			value = sin(TAU * float(notes[section]) * t) * envelope * exp(-t * 0.7)
		pcm.encode_s16(i * 2, int(value * 16000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = pcm
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream
