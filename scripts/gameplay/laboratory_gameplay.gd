extends Node3D
## Composition for the real Signal Laboratory. Reuses scene-authored furniture,
## managers, interaction, audio and dialogue; owns only integration and local input locks.

const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const Relay := preload("res://scripts/puzzles/implementations/laboratory_relay_puzzle.gd")

var room: Node3D
var configured: bool = false
var _shutting_down: bool = false
var _feedback: String = ""
var _feedback_left: float = 0.0
var _positions: Dictionary = {}
var _current_role: String = ""

@onready var radio: TemporalRadio = $TemporalRadio
@onready var director: DialogueDirector = $DialogueDirector
@onready var adapter: Node = $RadioDialogueAdapter
@onready var binding: Node = $RadioDirectorBinding
@onready var audio: AudioDirector = $"../SignalLab/AudioSystem"
@onready var radio_audio: Node = $RadioAudio
@onready var terminal: Control = $"../SignalLab/FrequencyScreens/Terminal"
@onready var reader: Control = $"../SignalLab/FrequencyScreens/LogReader"
@onready var student_pickup: Interactable3D = $"../SignalLab/Layout/Interactive/PastRadio/Pickup"
@onready var professor_pickup: Interactable3D = $"../SignalLab/Layout/Interactive/FutureRadio/Pickup"
@onready var computer: Interactable3D = $"../SignalLab/Layout/Interactive/ConsoleTerminal/Computer"
@onready var clue: Interactable3D = $"../SignalLab/Layout/Interactive/ConsoleTerminal/RecoveredLog"
@onready var objective: Label = $GameplayHUD/Objective
@onready var prompt: CanvasLayer = null
var controller: Node
var physical_devices: Node


func initialize(laboratory: Node3D) -> void:
	if configured:
		return
	room = laboratory
	room.lab.ui.guide_top = 186.0  # The radio status panel owns the row above the message rail.
	configured = true
	if not PuzzleManager.is_registered(Relay.ID):
		PuzzleManager.register_puzzle(Relay.ID, Relay.new())
	prompt = load("res://scenes/ui/interaction_prompt.tscn").instantiate()
	prompt.name = "InteractionPrompt"
	add_child(prompt)
	# Use the environment's authored devices and screens; this composition owns
	# the local character and narrative presentation, not a second copy of Puzzle 01.
	for pickup in [student_pickup, professor_pickup]:
		pickup.play_interaction_animation = true
		pickup.animation_action_name = "pick_up"
		pickup.timing = Interactable3D.Timing.AFTER_ANIMATION
	for target in [computer, clue]:
		target.play_interaction_animation = true
		target.animation_action_name = "inspect" if target == clue else "interact"
		target.timing = Interactable3D.Timing.AFTER_ANIMATION
	room.lab.attach_radio(radio, radio_audio)
	room.lab.ui.modal_changed.connect(_on_modal_changed)
	terminal.modal_changed.connect(_on_modal_changed)
	reader.modal_changed.connect(_on_modal_changed)
	director.gameplay_input_block_changed.connect(_on_dialogue_block_changed)
	director.dialogue_finished.connect(_on_dialogue_finished)
	director.dialogue_cancelled.connect(_on_dialogue_finished)
	radio.status_changed.connect(_on_radio_status_changed)
	$Props/RadioCheck.interacted.connect(_on_radio_check)
	PuzzleManager.puzzle_state_changed.connect(_on_puzzle_state_changed)
	PuzzleManager.action_rejected.connect(_on_action_rejected)
	PuzzleManager.session_started.connect(_on_session_started)
	PuzzleManager.session_ended.connect(_on_session_ended)
	director.dialogue_line_finished.connect(_on_audio_dialogue_advance)
	PuzzleManager.puzzle_completed.connect(_on_audio_puzzle_completed)
	for button_path in ["%PauseButton", "%ResumeButton"]:
		room.get_node(button_path).set_meta("audio_event", &"")
	audio.bind_ui(room)
	bind_player()
	physical_devices = preload("res://scripts/gameplay/devices/laboratory_devices.gd").new()
	physical_devices.name = "PhysicalDevices"
	add_child(physical_devices)
	physical_devices.configure(self)
	apply_timeline()
	_refresh_state()


func detach_player() -> void:
	if not configured:
		return
	if not _current_role.is_empty():
		_positions[_current_role] = room.player.global_position
	if radio.get_parent() != self:
		radio.reparent(self)


func bind_player() -> void:
	var player: CharacterBody3D = room.player
	player.demonstration_items_enabled = false
	player.view_camera = room.camera
	if not player.has_node("InteractionRig"):
		var rig: Node3D = load("res://scenes/interaction/interaction_rig.tscn").instantiate()
		player.add_child(rig)
	controller = player.get_node("InteractionRig/InteractionController")
	controller.prompt_ui = prompt
	if radio.get_parent() != player:
		radio.reparent(player)
	if not player.has_node("FootstepEmitter3D"):
		player.add_child(load("res://scenes/audio/footstep_emitter_3d.tscn").instantiate())
	var emitter := player.get_node("FootstepEmitter3D") as FootstepEmitter3D
	emitter.set_timeline(StringName(room.timeline))
	# Listen at the local character, independent of the high-angle camera.
	var listener := AudioListener3D.new()
	listener.name = "LocalAudioListener"
	listener.position.y = 1.4
	player.add_child(listener)
	listener.make_current()
	var socket := BoneAttachment3D.new()
	socket.name = "HeldRadioSocket"
	socket.bone_name = "handslot.r"
	player.skeleton.add_child(socket)
	var model: Node3D = load("res://scenes/gameplay/radio/placeholder_radio.tscn").instantiate()
	model.position = Vector3(0, 0.08, 0)
	socket.add_child(model)
	var presenter: Node3D = load("res://scripts/gameplay/radio/radio_model_presenter.gd").new()
	presenter.radio = radio
	presenter.model = model
	socket.add_child(presenter)
	_sync_controls()


func apply_timeline() -> void:
	if not configured:
		return
	var role: String = "future" if room.timeline == "Future" else "past"
	_current_role = role
	(room.player.get_node("FootstepEmitter3D") as FootstepEmitter3D).set_timeline(StringName(role))
	radio.set_player_role(role)
	controller.detector.set_current_role(role)
	if physical_devices != null: physical_devices.apply_timeline()
	director.set_local_timeline(role)
	# Keeping each solo role's position makes switching a useful co-op test flow.
	if _positions.has(role):
		room.player.global_position = _positions[role]
	room.player.carrying = radio.owns_radio
	_refresh_state()
	_sync_controls()


func has_modal() -> bool:
	return terminal.visible or reader.visible or room.lab.ui.is_modal_open() or JournalManager.is_open() or _tutorial_open()


func _tutorial_open() -> bool:
	var tutorial: Variant = room.get("tutorial")
	return tutorial != null and tutorial.is_open()


func can_switch_role() -> bool:
	return configured and not _shutting_down and not has_modal() and not director.is_dialogue_active() and not room.player.is_action_active() and not room.is_gameplay_paused()


func sync_controls() -> void:
	_sync_controls()


func close_overlays() -> void:
	terminal.close()
	reader.close()
	room.lab.ui.close_modal()
	var tutorial: Variant = room.get("tutorial")
	if tutorial != null:
		tutorial.close_silently()
	director.stop_dialogue()
	adapter.end_conversation()


func shutdown(fade_time: float = 0.0) -> void:
	if _shutting_down:
		return
	_shutting_down = true
	close_overlays()
	stop_audio(fade_time)
	if configured and is_instance_valid(room.player):
		room.player.controls_enabled = false


func stop_audio(fade_time: float = 0.0) -> void:
	if is_instance_valid(audio):
		audio.stop_all_sfx()
		audio.stop_ambience(fade_time)
		audio.stop_music(fade_time)
	if is_instance_valid(radio_audio):
		radio_audio.stop_static()
	if configured and is_instance_valid(room.player):
		var footsteps: Node = room.player.get_node_or_null("FootstepEmitter3D")
		if footsteps != null and is_instance_valid(footsteps.player):
			footsteps.player.stop()


func _sync_controls() -> void:
	if not configured or _shutting_down:
		return
	var overlay: bool = has_modal() or room.is_gameplay_paused()
	room.lab.ui.set_overlay_blocked(room.is_gameplay_paused())
	if physical_devices != null and physical_devices.inspector != null:
		physical_devices.inspector.suspended = room.is_gameplay_paused()
	var blocked: bool = overlay or director.is_gameplay_input_blocked()
	var inspecting: bool = physical_devices != null and physical_devices.inspector != null and physical_devices.inspector.active
	$GameplayHUD.visible = not room.is_character_studio_open() and not inspecting
	room.get_node("HUD").visible = not inspecting
	room.lab.ui.visible = not room.is_character_studio_open()
	if room.player.controls_enabled == blocked:
		room.player.controls_enabled = not blocked
	if blocked:
		room.player.velocity = Vector3.ZERO
	prompt.set_interaction_blocked(blocked)
	controller.set_interaction_blocked(blocked)
	binding.set_suspended(overlay)
	radio_audio.set_suspended(overlay)
	room.get_node("%TimelineButton").disabled = not can_switch_role()
	room.get_node("%CharacterButton").disabled = not can_switch_role()
	room.get_node("%InterferenceButton").disabled = not radio.has_established_link()
	$Props/RadioCheck.set_interaction_enabled(radio.can_receive() and not director.is_dialogue_active())


func _refresh_state() -> void:
	if not configured:
		return
	var state := PuzzleManager.get_state(Rules.ID)
	var linked := Rules.link_established(state)
	var relay_online := PuzzleManager.is_solved(Relay.ID)
	$Props/ReceiverRelay.set_interaction_enabled(not relay_online)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("86c9d1") if relay_online else Color("e4bf7f")
	material.emission_enabled = relay_online
	material.emission = material.albedo_color * 0.5
	$Props/ReceiverRelay/Lamp.material_override = material
	if not _feedback.is_empty():
		objective.text = _feedback
	elif linked:
		objective.text = "TEMPORAL RADIO LINK ESTABLISHED\nLeave through the north security door. The receiver relay is optional."
	elif not radio.owns_radio:
		objective.text = "THE LOST FREQUENCY\nFind the handheld radio in the reading corner." if radio.player_role == "future" else "THE LOST FREQUENCY\nFind the handheld radio."
	elif not Rules.radios_ready(state):
		objective.text = "THE LOST FREQUENCY\nWaiting for the other player to collect their handheld radio."
	elif radio.player_role == "future":
		objective.text = "THE LOST FREQUENCY\nWatch the live receiver. Guide the Student to match the green wave to the grey target."
	else:
		objective.text = "THE LOST FREQUENCY\nTurn the console's frequency and amplitude dials. The Professor sees the results."
	objective.hide()
	room.lab.ui.set_guidance(objective.text)
	_sync_controls()


func _on_radio_status_changed(_status: int, owned: bool, _active: bool) -> void:
	if configured and not room.player.is_action_active():
		room.player.carrying = owned
	_refresh_state()


func _on_modal_changed(_open: bool) -> void:
	_sync_controls()


func _on_dialogue_block_changed(_blocked: bool) -> void:
	_sync_controls()


func _on_dialogue_finished(_sequence_id: String) -> void:
	_sync_controls()


func _on_radio_check(_actor: Node, _role: String) -> void:
	adapter.request_conversation(&"laboratory.radio_check")


func _on_puzzle_state_changed(puzzle_id: String, _state: Dictionary, _revision: int) -> void:
	if puzzle_id in [Rules.ID, Relay.ID]:
		_feedback = ""
		_refresh_state()


func _on_action_rejected(puzzle_id: String, _action: String, reason: String, role: String) -> void:
	if puzzle_id == Relay.ID and role == radio.player_role and reason == "prerequisite_not_met":
		_feedback = "The receiver relay needs an established temporal radio link."
		_feedback_left = 3.0
		radio_audio.play_cue(&"failed")
		_refresh_state()


func _on_session_started() -> void:
	if not configured:
		return
	close_overlays()
	director.reset_session()
	_feedback = ""
	_positions.clear()
	_refresh_state()


func _on_session_ended() -> void:
	if configured:
		close_overlays()
		_refresh_state()


func _process(delta: float) -> void:
	if not configured or _shutting_down:
		return
	if _feedback_left > 0.0:
		_feedback_left -= delta
		if _feedback_left <= 0.0:
			_feedback = ""
			_refresh_state()
	# Re-enable role/studio buttons after one-shot interaction animations end.
	room.get_node("%TimelineButton").disabled = not can_switch_role()
	room.get_node("%CharacterButton").disabled = not can_switch_role()


func _exit_tree() -> void:
	stop_audio()

func _on_audio_dialogue_advance(_sequence_id: String, _line_index: int) -> void:
	audio.play_ui(&"dialogue_advance")

func _on_audio_puzzle_completed(puzzle_id: String) -> void:
	if puzzle_id == Relay.ID:
		audio.play_sfx(&"mechanism_activated")
