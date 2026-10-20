class_name SignalLab
extends Node3D
## Room 1, the Signal Laboratory, in both timelines.
##
## One layout (rooms/signal_lab_layout.tscn) serves the Past and the Future; this node switches
## every TimelineProp, the per-timeline lighting rigs, the LabUI accent and the ambience, and tunes
## the host scene's environment and key light. Puzzle 01 is the frequency puzzle: its coordinator
## registers puzzle_01_frequency on every peer, the console carries its calibration computer
## (Past) and recovered research log (Future), and its radio pickups sit in the room. This node
## only wires those parts together and turns confirmed changes into room feedback: toasts, the
## completion banner, the door (which listens to the link) and the exit.

signal puzzle_solved
signal player_exited(body: Node3D)

const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const RadioAudio := preload("res://scripts/gameplay/radio/radio_audio.gd")

## Timeline shown. The host scene sets it from the player's role.
@export var future: bool = false:
	set(value):
		future = value
		if is_node_ready():
			_apply()
## Optional: the scene's WorldEnvironment, retuned per timeline.
@export var world_environment: WorldEnvironment
## Optional: the scene's key light, retuned per timeline.
@export var key_light: DirectionalLight3D

@onready var ui: LabUI = $LabUI
@onready var audio: AudioDirector = $AudioSystem
@onready var coordinator: Node = $FrequencyCoordinator
@onready var terminal: Control = $FrequencyScreens/Terminal
@onready var reader: Control = $FrequencyScreens/LogReader
@onready var door: Node3D = $Layout/Interactive/SecurityDoor

var exited: bool = false
var radio_audio: Node
var _radio: TemporalRadio
var _state: Dictionary = {}


func _ready() -> void:
	audio.add_to_group("lab_audio")
	$Layout/Interactive/ConsoleTerminal.bind_screens(terminal, reader)
	PuzzleManager.puzzle_state_changed.connect(_on_puzzle_state_changed)
	coordinator.temporal_radio_link_established.connect(_on_link_established)
	_state = PuzzleManager.get_state(Rules.ID)
	door.player_exited.connect(_on_player_exited)
	_apply()


## Give the room the local player's TemporalRadio: radio, terminal and pickup cues then play
## through the frequency puzzle's RadioAudio bridge on this room's AudioDirector.
func attach_radio(radio: TemporalRadio) -> void:
	_radio = radio
	if radio_audio == null:
		radio_audio = RadioAudio.new()
		radio_audio.name = "RadioAudio"
		radio_audio.audio_director = audio
		radio_audio.radio = radio
		add_child(radio_audio)
		terminal.audio_cue_requested.connect(radio_audio.play_cue)
		for pickup in [$Layout/Interactive/PastRadio/Pickup, $Layout/Interactive/FutureRadio/Pickup]:
			pickup.radio_acquired.connect(_on_radio_acquired)


## Every TimelineProp in the room, in tree order (outer props before the props nested in them).
func timeline_props() -> Array[TimelineProp]:
	var props: Array[TimelineProp] = []
	for node in find_children("*", "Node3D", true, false):
		if node is TimelineProp:
			props.append(node)
	return props


func _apply() -> void:
	for prop in timeline_props():
		prop.future = future
	$Lighting/Past.visible = not future
	$Lighting/Future.visible = future
	ui.set_timeline(future)
	terminal.close()
	reader.close()
	# Ambience loops forever; without an output device (headless runs) nothing would mix it.
	if AudioServer.get_driver_name() != "Dummy":
		audio.ambient_controller.switch_timeline(&"Future" if future else &"Past")
	if world_environment != null and world_environment.environment != null:
		var environment := world_environment.environment
		environment.ambient_light_color = Color("4a6d7c") if future else Color("f3e3c4")
		environment.ambient_light_energy = 0.6 if future else 0.62
		environment.background_color = Color("0a1418") if future else Color("1a1712")
	if key_light != null:
		key_light.light_color = Color("9fb8d0") if future else Color("ffe7c2")
		key_light.light_energy = 0.55 if future else 0.95


func _on_puzzle_state_changed(puzzle_id: String, state: Dictionary, _revision: int) -> void:
	if puzzle_id != Rules.ID:
		return
	var previous := _state
	_state = state
	if previous.is_empty() or Rules.link_established(state):
		return
	# What the other timeline just did, as the room hears it.
	if state.get("professor_radio", false) and not previous.get("professor_radio", false) and not future:
		ui.toast("Your radio crackles: someone thirty-one years away has switched on a handheld.")
	if state.get("student_radio", false) and not previous.get("student_radio", false) and future:
		ui.toast("Your radio crackles: a young voice, very far away, is on the same band.")
	if state.get("frequency_calibrated", false) and not previous.get("frequency_calibrated", false) and future:
		ui.toast("The console flickers: SIGNAL LOCKED. The array has been calibrated in the Past.")


func _on_radio_acquired(role: String) -> void:
	if _radio != null and role == _radio.player_role:
		radio_audio.play_cue(&"pickup")
		ui.toast("Handheld radio acquired. Both timelines need theirs on before the array can hold a link.")


func _on_link_established() -> void:
	ui.banner("TEMPORAL RADIO LINK ESTABLISHED", "The array holds the carrier across thirty-one years. The security door is open.")
	puzzle_solved.emit()


func _on_player_exited(body: Node3D) -> void:
	if exited:
		return
	exited = true
	ui.banner("SIGNAL LABORATORY CLEARED", "Both timelines found the way out.", 6.0)
	audio.play_world_sfx(&"interaction_success", body.global_position)
	player_exited.emit(body)
