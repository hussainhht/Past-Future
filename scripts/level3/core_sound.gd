extends Node
## Reactor event adapter; playback, buses, ambience and music belong to AudioDirector.

var director: AudioDirector
var reactor_ambience: AmbientAudioController

func _ready() -> void:
	director = load("res://scenes/audio/audio_system.tscn").instantiate()
	director.name = "AudioSystem"
	add_child(director)
	reactor_ambience = AmbientAudioController.new()
	reactor_ambience.name = "ReactorAmbience"
	add_child(reactor_ambience)

func set_role(role: String) -> void:
	director.start_soundscape(StringName(role))

func play(id: String) -> void:
	if id == "activate" and AudioServer.get_driver_name() != "Dummy": reactor_ambience.start_ambience(&"rift_hum", 1.2)
	elif id in ["overload", "trust", "student_override", "professor_override", "paradox"]: reactor_ambience.stop_ambience(0.5)
	var events := {"activate": &"equipment_activate", "phase": &"rift_stabilize",
		"warning": &"computer_invalid", "overload": &"equipment_deactivate",
		"trust": &"puzzle_success", "student_override": &"rift_activate",
		"professor_override": &"rift_activate", "paradox": &"puzzle_failure",
		"signal": &"radio_incoming"}
	director.play_sfx(events.get(id, &"interaction_success"))
