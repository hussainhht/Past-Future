extends Control
## Debug-only route. Does not add shortcuts to the shipping menu or alter Room B.

var address: LineEdit
var status: Label
var _started: bool = false
var _automatic: bool = false


func _ready() -> void:
	if not OS.is_debug_build():
		get_tree().change_scene_to_file.call_deferred("res://scenes/menu/main_menu.tscn")
		return
	NetworkManager.game_started.connect(_enter)
	NetworkManager.state_changed.connect(_network_changed)
	var backdrop := ColorRect.new()
	backdrop.color = Color("111d28")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 750
	box.add_theme_constant_override("separation", 15)
	center.add_child(box)
	var title := Label.new()
	title.text = "THE FINAL FRACTURE / DEVELOPMENT LAUNCHER"
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	for timeline: String in ["past", "future"]:
		_button(box, "SOLO / " + timeline.to_upper(), _solo.bind(timeline))
	address = LineEdit.new()
	address.text = "127.0.0.1"
	address.placeholder_text = "Host IP address"
	address.custom_minimum_size.y = 48
	box.add_child(address)
	_button(box, "HOST / STUDENT", func() -> void: NetworkManager.host_game())
	_button(box, "JOIN / PROFESSOR", func() -> void: NetworkManager.join_game(address.text))
	_button(box, "PROFESSOR READY", func() -> void: NetworkManager.set_ready(true))
	_button(box, "HOST / ENTER ROOM C", func() -> void: NetworkManager.start_game())
	_button(box, "RETURN TO MENU", func() -> void:
		NetworkManager.leave_game()
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(750, 72)
	box.add_child(status)
	var args := OS.get_cmdline_user_args()
	if "--core-solo" in args:
		var index := args.find("--core-solo")
		_solo(args[index + 1] if args.size() > index + 1 else "past")
	elif "--core-host" in args:
		_automatic = true
		var index := args.find("--core-host")
		NetworkManager.host_game(int(args[index + 1]) if args.size() > index + 1 else NetworkManager.PORT)
	elif "--core-join" in args:
		_automatic = true
		var index := args.find("--core-join")
		if args.size() > index + 1:
			NetworkManager.join_game(args[index + 1], int(args[index + 2]) if args.size() > index + 2 else NetworkManager.PORT)


func _button(parent: Node, text: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 48
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(callback)
	parent.add_child(b)


func _solo(timeline: String) -> void:
	NetworkManager.leave_game()
	PuzzleManager.offline_role = "future" if timeline == "future" else "past"
	_enter()


func _network_changed() -> void:
	status.text = NetworkManager.status
	if _automatic and NetworkManager.state == NetworkManager.State.CONNECTED and not NetworkManager.in_game:
		if NetworkManager.role == "future": NetworkManager.set_ready(true)
		elif NetworkManager.guest_ready: NetworkManager.start_game()


func _enter() -> void:
	if _started: return
	_started = true
	GameFlowManager.start_room.call_deferred("room_03")
