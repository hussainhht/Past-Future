extends Node3D
## Independent lab. T switches offline roles, R unloads/reloads room presentation,
## N explicitly resets the session, X previews interference, D previews ONE UI line.
## LAN uses the existing lobby/ENet APIs. No sandbox RPC protocol is introduced.

const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const UI := preload("res://scripts/gameplay/frequency/frequency_ui.gd")

var player: CharacterBody3D
var radio: TemporalRadio
var terminal: Control
var reader: Control
var dialogue_view: PanelContainer
var dialogue_adapter: Node
var dialogue_preview: Node
var audio_bridge: Node
var room: Node3D
var prompt: CanvasLayer
var role_label: Label
var result_label: Label
var controls_label: Label
var _controller: Node
var _transition_probe: bool = false
var _ready_sent: bool = false


func _ready() -> void:
	var coordinator: Node = load("res://scripts/gameplay/frequency/frequency_puzzle_coordinator.gd").new()
	add_child(coordinator)
	var audio: Node = load("res://scenes/audio/audio_system.tscn").instantiate()
	add_child(audio)
	_build_world()
	player = load("res://scenes/characters/student_3d_player.tscn").instantiate()
	player.name = "Player"
	player.position = Vector3(-3, 0, 2)
	var rig: Node3D = load("res://scenes/interaction/interaction_rig.tscn").instantiate()
	player.add_child(rig)
	radio = load("res://scenes/gameplay/radio/temporal_radio.tscn").instantiate()
	player.add_child(radio)
	add_child(player)
	_controller = rig.get_node("InteractionController")
	_attach_radio_model()
	var camera_rig := Node3D.new()
	camera_rig.name = "CameraRig"
	camera_rig.set_script(load("res://scripts/world/follow_camera.gd"))
	camera_rig.set("target_path", NodePath("../Player"))
	camera_rig.set("distance", 17.0)
	camera_rig.set("pitch_degrees", 45.0)
	camera_rig.set("look_ahead", 0.0)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera_rig.add_child(camera)
	add_child(camera_rig)
	player.set("view_camera", camera)
	_build_ui()
	audio_bridge = load("res://scripts/gameplay/radio/radio_audio.gd").new()
	audio_bridge.audio_director = audio
	audio_bridge.radio = radio
	add_child(audio_bridge)
	terminal.audio_cue_requested.connect(audio_bridge.play_cue)
	PuzzleManager.puzzle_state_changed.connect(_on_state_changed)
	NetworkManager.state_changed.connect(_on_network_changed)
	_configure_network()
	_build_room()
	_apply_role()


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("0c1320")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("a7b9d1")
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -20, 0)
	sun.light_energy = 0.8
	add_child(sun)
	_box(self, Vector3(0, -0.25, 0), Vector3(22, 0.5, 18), Color("1d2e3c"), true)
	for boundary in [Vector3(-11, 0.5, 0), Vector3(11, 0.5, 0), Vector3(0, 0.5, -9), Vector3(0, 0.5, 9)]:
		_box(self, boundary, Vector3(0.3, 1, 18) if boundary.x != 0 else Vector3(22, 1, 0.3), Color("273d4a"), true)


func _attach_radio_model() -> void:
	var socket := Node3D.new()
	socket.position = Vector3(0.35, 1.1, 0.18)
	player.get_node("Visual").add_child(socket)
	var model: Node3D = load("res://scenes/gameplay/radio/placeholder_radio.tscn").instantiate()
	socket.add_child(model)
	var presenter := Node3D.new()
	presenter.set_script(load("res://scripts/gameplay/radio/radio_model_presenter.gd"))
	presenter.set("radio", radio)
	presenter.set("model", model)
	socket.add_child(presenter)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	layer.layer = 15
	add_child(layer)
	var header := VBoxContainer.new()
	header.position = Vector2(24, 22)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(header)
	header.add_child(UI.label("THE LOST FREQUENCY", 26))
	role_label = UI.label("PAST / STUDENT", 17, UI.CYAN)
	header.add_child(role_label)
	result_label = UI.label("Acquire the handheld radios. Calibrate the main computer.", 16, Color("c0ccd7"))
	header.add_child(result_label)
	var hud: Control = load("res://scenes/gameplay/radio/radio_hud.tscn").instantiate()
	hud.set("radio", radio)
	layer.add_child(hud)
	controls_label = UI.label("WASD / arrows  Move     F  Interact\nT  Switch offline role     R  Room transition probe\nX  Signal interference     D  Radio skin preview\nN  New session (host/offline)", 15, Color("b7c8d4"))
	controls_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls_label.position = Vector2(24, -120)
	controls_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(controls_label)
	dialogue_view = load("res://scenes/gameplay/radio/radio_dialogue_presenter.tscn").instantiate()
	dialogue_view.radio = radio
	layer.add_child(dialogue_view)
	dialogue_adapter = load("res://scripts/gameplay/radio/radio_dialogue_adapter.gd").new()
	dialogue_adapter.radio = radio
	dialogue_adapter.presenter = dialogue_view
	add_child(dialogue_adapter)
	dialogue_preview = load("res://scripts/testing/radio_dialogue_preview.gd").new()
	dialogue_preview.adapter = dialogue_adapter
	dialogue_preview.presenter = dialogue_view
	add_child(dialogue_preview)
	prompt = load("res://scenes/ui/interaction_prompt.tscn").instantiate()
	add_child(prompt)
	_controller.prompt_ui = prompt
	var modal_layer := CanvasLayer.new()
	modal_layer.layer = 30
	add_child(modal_layer)
	terminal = load("res://scenes/gameplay/frequency/frequency_terminal_ui.tscn").instantiate()
	modal_layer.add_child(terminal)
	reader = load("res://scripts/gameplay/frequency/frequency_log_reader.gd").new()
	modal_layer.add_child(reader)


func _build_room() -> void:
	room = Node3D.new()
	room.name = "PresentationRoom"
	add_child(room)
	var indicator: Node3D = load("res://scenes/gameplay/frequency/temporal_link_indicator.tscn").instantiate()
	indicator.position = Vector3(0, 1.4, -4)
	room.add_child(indicator)
	_label(room, "TEMPORAL RIFT", Vector3(0, 3.2, -4), UI.CYAN)
	if _transition_probe:
		_label(room, "ROOM TRANSITION PROBE\nState retained by PuzzleManager\nR returns to the laboratory", Vector3(0, 1.4, 0), UI.CYAN)
		return
	for role in ["past", "future"]:
		var x := -3.0 if role == "past" else 3.0
		var station := Node3D.new()
		station.name = "PastStation" if role == "past" else "FutureStation"
		room.add_child(station)
		_box(station, Vector3(x, 0.3, 0), Vector3(1.8, 0.6, 1.4), Color("3e4a50"))
		var pickup: Area3D = load("res://scenes/gameplay/radio/radio_pickup.tscn").instantiate()
		pickup.set("radio_role", role)
		pickup.position = Vector3(x, 1, 0)
		pickup.radio_acquired.connect(_on_pickup)
		station.add_child(pickup)
		_label(station, "HANDHELD RADIO", Vector3(x, 2.1, 0), UI.AMBER)
	var computer: Area3D = load("res://scenes/gameplay/frequency/frequency_computer.tscn").instantiate()
	computer.name = "Computer"
	computer.position = Vector3(-4, 0.6, -3)
	computer.set("terminal", terminal)
	room.add_child(computer)
	_label(computer, "MAIN COMPUTER", Vector3(0, 1.2, 0), UI.AMBER)
	var clue: Area3D = load("res://scenes/gameplay/frequency/frequency_clue.tscn").instantiate()
	clue.name = "ResearchLog"
	clue.position = Vector3(4, 0.8, -3)
	clue.set("reader", reader)
	room.add_child(clue)
	_label(clue, "RESEARCH LOG", Vector3(0, 0.9, 0), UI.CYAN)
	_box(clue, Vector3(0, -0.5, 0), Vector3(1.6, 0.7, 1.2), Color("41484e"))
	_apply_role()


func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid: bool = false) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	box.material = material
	mesh.mesh = box
	mesh.position = pos
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.position = pos
		body.add_child(collision)
		parent.add_child(body)


func _label(parent: Node3D, text: String, pos: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 36
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.position = pos
	parent.add_child(label)


func _apply_role() -> void:
	var role := PuzzleManager.get_local_role()
	radio.set_player_role(role)
	_controller.detector.set_current_role(role)
	role_label.text = ("PAST / STUDENT" if role == "past" else "FUTURE / PROFESSOR") + ("  [OFFLINE]" if NetworkManager.state == NetworkManager.State.IDLE else "  [LAN]")
	player.set("body_color", UI.AMBER if role == "past" else UI.CYAN)
	if is_instance_valid(room) and not _transition_probe:
		room.get_node("PastStation").visible = role == "past"
		room.get_node("FutureStation").visible = role == "future"
		room.get_node("Computer").visible = role == "past"
		room.get_node("ResearchLog").visible = role == "future"
	_update_result()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_T:
			if NetworkManager.state == NetworkManager.State.IDLE:
				PuzzleManager.offline_role = "future" if radio.player_role == "past" else "past"
				_apply_role()
		KEY_R:
			_transition_probe = not _transition_probe
			room.free()
			_build_room()
		KEY_N:
			if PuzzleManager.is_authority():
				PuzzleManager.begin_session()
		KEY_X:
			radio.interfere(2.0)
		KEY_D:
			dialogue_adapter.request_conversation(&"sandbox.radio_check")
		_:
			return
	get_viewport().set_input_as_handled()


func _on_pickup(role: String) -> void:
	if role == radio.player_role:
		audio_bridge.play_cue(&"pickup")


func _on_state_changed(puzzle_id: String, _state: Dictionary, _revision: int) -> void:
	if puzzle_id == Rules.ID:
		_update_result()


func _update_result() -> void:
	result_label.text = "TEMPORAL RADIO LINK ESTABLISHED" if radio.has_established_link() else "Acquire the handheld radios. Calibrate the main computer."


func _configure_network() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1 and args[0] == "--radio-host":
		var port := args[1].to_int() if args.size() > 1 else NetworkManager.PORT
		var error := NetworkManager.host_game(port)
		if error != OK:
			result_label.text = "Unable to host: " + error_string(error)
	elif args.size() >= 2 and args[0] == "--radio-join":
		var port := args[2].to_int() if args.size() > 2 else NetworkManager.PORT
		NetworkManager.join_game(args[1], port)


func _on_network_changed() -> void:
	if NetworkManager.role == "future" and NetworkManager.state == NetworkManager.State.CONNECTED and not NetworkManager.in_game and not _ready_sent:
		_ready_sent = true
		NetworkManager.set_ready(true)
	if NetworkManager.role == "past" and NetworkManager.guest_ready and not NetworkManager.in_game:
		NetworkManager.start_game()
	if is_instance_valid(radio) and is_instance_valid(role_label):
		_apply_role()
