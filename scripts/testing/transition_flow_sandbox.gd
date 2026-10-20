extends Control
## Standalone entry point for the level-flow system (scenes/testing/transition_flow_sandbox.tscn).
## Uses the real NetworkManager lobby API and GameFlowManager; it adds no network protocol.
##
## Command line (after "--"): --flow-solo past|future   --flow-host [port]   --flow-join <ip> [port]

const TEST_ROOM_DIRECTORY := "res://resources/levels/test"
const FIRST_ROOM := "test_room_a"

var _status: Label
var _address: LineEdit
var _ready_button: Button
var _start_button: Button
var _lobby_buttons: Array[Button] = []
var _cli_mode: bool = false
var _entered: bool = false
var _ready_sent: bool = false


func _ready() -> void:
	GameFlowManager.load_room_directory(TEST_ROOM_DIRECTORY)
	NetworkManager.state_changed.connect(_on_network_changed)
	NetworkManager.game_started.connect(_enter_game)
	_build_ui()
	_apply_command_line()
	_on_network_changed()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color("0c1320")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(460, 0)
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)
	var title := Label.new()
	title.text = "LEVEL TRANSITION SANDBOX"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("e4bf7f"))
	column.add_child(title)
	var intro := Label.new()
	intro.text = "Two placeholder rooms. Press F9 in a room to establish the radio link, then use the exit."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(intro)
	_lobby_buttons.append(_button(column, "SOLO  -  STUDENT (PAST)", _start_solo.bind("past")))
	_lobby_buttons.append(_button(column, "SOLO  -  PROFESSOR (FUTURE)", _start_solo.bind("future")))
	_lobby_buttons.append(_button(column, "HOST  -  STUDENT (PAST)", _host))
	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	_address.placeholder_text = "Host address"
	column.add_child(_address)
	_lobby_buttons.append(_button(column, "JOIN  -  PROFESSOR (FUTURE)", _join))
	_ready_button = _button(column, "I'M READY", func() -> void: NetworkManager.set_ready(not NetworkManager.guest_ready))
	_start_button = _button(column, "START GAME", func() -> void: NetworkManager.start_game())
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _apply_command_line() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return
	_cli_mode = true
	match args[0]:
		"--flow-solo":
			_start_solo(args[1] if args.size() > 1 else "past")
		"--flow-host":
			NetworkManager.host_game(args[1].to_int() if args.size() > 1 else NetworkManager.PORT)
		"--flow-join":
			if args.size() > 1:
				NetworkManager.join_game(args[1], args[2].to_int() if args.size() > 2 else NetworkManager.PORT)


func _start_solo(role: String) -> void:
	if NetworkManager.state != NetworkManager.State.IDLE:
		return
	PuzzleManager.offline_role = role
	PuzzleManager.begin_session()  # a fresh solo run starts with fresh puzzles
	_enter_game()


func _host() -> void:
	NetworkManager.host_game()


func _join() -> void:
	NetworkManager.join_game(_address.text)


func _enter_game() -> void:
	if _entered:
		return
	_entered = true
	GameFlowManager.start_room.call_deferred(FIRST_ROOM)


func _on_network_changed() -> void:
	if _entered:
		return
	var idle := NetworkManager.state == NetworkManager.State.IDLE
	for button in _lobby_buttons:
		button.disabled = not idle
	_address.editable = idle
	var guest_waiting := NetworkManager.state == NetworkManager.State.CONNECTED and NetworkManager.role == "future"
	var host_connected := NetworkManager.state == NetworkManager.State.CONNECTED and NetworkManager.role == "past"
	_ready_button.visible = guest_waiting
	_ready_button.text = "READY" if NetworkManager.guest_ready else "I'M READY"
	_start_button.visible = host_connected
	_start_button.disabled = not NetworkManager.guest_ready
	_status.text = NetworkManager.status
	if _cli_mode:
		if guest_waiting and not _ready_sent:
			_ready_sent = true
			NetworkManager.set_ready(true)
		if host_connected and NetworkManager.guest_ready:
			NetworkManager.start_game()
