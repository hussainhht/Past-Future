extends Node3D
## Sandbox room for the level-flow system. One script serves Test Room A and both Room B scenes:
## it spawns the local timeline's character at the entry marker GameFlowManager names, wires the
## existing interaction and radio systems, and shows a status panel. It owns no canonical state, so
## destroying and re-creating it must restore everything from PuzzleManager.
## Opening a room scene directly (F6) works: it registers the test rooms and attaches itself.

const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const TEST_ROOM_DIRECTORY := "res://resources/levels/test"
const AMBER := Color("e4bf7f")
const CYAN := Color("86c9d1")

@export var room_id: String = ""
@export var room_title: String = "TEST ROOM"
@export var accent: Color = Color("86c9d1")

var player: CharacterBody3D
var radio: TemporalRadio
var camera: Camera3D
var controller: Node
var prompt: CanvasLayer
var role: String = "past"
var status_label: Label
var link_label: Label
var exit_label: Label
var _hud_title: Label


func _ready() -> void:
	role = PuzzleManager.get_local_role()
	if GameFlowManager.get_current_room_id().is_empty():
		GameFlowManager.load_room_directory(TEST_ROOM_DIRECTORY)
		GameFlowManager.attach_room(room_id, self)
	_spawn_player()
	_build_camera()
	_build_hud()
	PuzzleManager.puzzle_state_changed.connect(_on_puzzle_changed)
	GameFlowManager.readiness_changed.connect(_refresh.unbind(3))
	GameFlowManager.transition_completed.connect(_refresh.unbind(1))
	GameFlowManager.transition_failed.connect(_refresh.unbind(1))
	GameFlowManager.request_rejected.connect(_on_request_rejected)
	NetworkManager.state_changed.connect(_refresh)
	_refresh()


func _spawn_player() -> void:
	var path := "res://scenes/characters/%s_3d_player.tscn" % ("professor" if role == "future" else "student")
	player = load(path).instantiate()
	player.name = "Player"
	player.demonstration_items_enabled = false
	player.body_color = CYAN if role == "future" else AMBER
	var marker := GameFlowManager.find_spawn_point(GameFlowManager.get_entry_spawn_id(role), self)
	if marker == null:
		marker = get_node_or_null("Spawns/%s_entry" % role) as Marker3D
	# Characters stand with their root on the ground: Y = 0 on level ground.
	player.position = marker.global_position if marker != null else Vector3.ZERO
	$Actors.add_child(player)
	var rig: Node3D = load("res://scenes/interaction/interaction_rig.tscn").instantiate()
	player.add_child(rig)
	controller = rig.get_node("InteractionController")
	controller.detector.set_current_role(role)
	prompt = load("res://scenes/ui/interaction_prompt.tscn").instantiate()
	add_child(prompt)
	controller.prompt_ui = prompt
	radio = load("res://scenes/gameplay/radio/temporal_radio.tscn").instantiate()
	radio.player_role = role
	player.add_child(radio)


func _build_camera() -> void:
	var rig := Node3D.new()
	rig.name = "CameraRig"
	rig.set_script(load("res://scripts/world/follow_camera.gd"))
	rig.set("target_path", NodePath("../Actors/Player"))
	rig.set("distance", 13.0)
	rig.set("pitch_degrees", 50.0)
	rig.set("look_ahead", 0.0)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	rig.add_child(camera)
	add_child(rig)
	player.view_camera = camera


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "StatusHUD"
	layer.layer = 15
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 18)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.11, 0.85)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	_hud_title = _label(column, room_title, 20, accent)
	status_label = _label(column, "", 15, Color("c0ccd7"))
	link_label = _label(column, "", 16, AMBER)
	exit_label = _label(column, "", 15, Color("c0ccd7"))
	var hud: Control = load("res://scenes/gameplay/radio/radio_hud.tscn").instantiate()
	hud.set("radio", radio)
	layer.add_child(hud)
	var hint := _label(layer, "WASD  Move      F  Use the exit (again to cancel)      F9  DEV: establish the radio link", 15, Color("b7c8d4"))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(20, -34)


func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F9:
		dev_establish_link()
		get_viewport().set_input_as_handled()


## Sandbox shortcut that uses the real puzzle actions: acquire the local radio and, as the Student
## (or offline), tune 67 MHz. Offline it acts for both timelines. Nothing is written directly.
func dev_establish_link() -> void:
	if radio.has_established_link():
		return
	if NetworkManager.state == NetworkManager.State.IDLE:
		for radio_role in ["past", "future"]:
			PuzzleManager.submit_action(Rules.ID, "acquire_radio", {"radio_role": radio_role}, radio_role)
		PuzzleManager.submit_action(Rules.ID, "tune_frequency", {"frequency": Rules.DEFAULT_FREQUENCY}, "past")
		PuzzleManager.submit_action(Rules.ID, "tune_amplitude", {"amplitude": 70}, "past")
	else:
		radio.request_acquisition()
		if role == "past":
			PuzzleManager.submit_action(Rules.ID, "tune_frequency", {"frequency": Rules.DEFAULT_FREQUENCY})
			PuzzleManager.submit_action(Rules.ID, "tune_amplitude", {"amplitude": 70})


func _on_puzzle_changed(puzzle_id: String, _state: Dictionary, _revision: int) -> void:
	if puzzle_id == Rules.ID:
		_refresh()


func _on_request_rejected(_destination: String, _reason: String, message: String) -> void:
	exit_label.text = "EXIT: " + message


func _refresh() -> void:
	if not is_instance_valid(status_label):
		return
	var current := GameFlowManager.get_current_room_id()
	status_label.text = "ROOM  %s     TIMELINE  %s     SESSION  %d" % [
		current if not current.is_empty() else "(none)",
		"PAST / STUDENT" if role == "past" else "FUTURE / PROFESSOR",
		PuzzleManager.get_session_id()]
	var state := PuzzleManager.get_state(Rules.ID)
	if radio.has_established_link():
		link_label.text = "TEMPORAL LINK  ESTABLISHED  ·  %d MHz  ·  revision %d" % [Rules.DEFAULT_FREQUENCY, PuzzleManager.get_revision(Rules.ID)]
		link_label.add_theme_color_override("font_color", CYAN)
	else:
		link_label.text = "TEMPORAL LINK  NOT ESTABLISHED  ·  radios %s / %s" % [
			"ok" if state.get("student_radio", false) else "-", "ok" if state.get("professor_radio", false) else "-"]
		link_label.add_theme_color_override("font_color", AMBER)
	var readiness := GameFlowManager.get_readiness()
	if readiness.destination.is_empty():
		exit_label.text = "EXIT  idle"
	else:
		exit_label.text = "EXIT  %s   student %s   professor %s" % [
			readiness.destination, "ready" if readiness.past else "waiting", "ready" if readiness.future else "waiting"]
