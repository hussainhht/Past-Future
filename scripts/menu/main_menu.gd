extends Control

## Widest "THE OTHER" may grow before it shrinks to fit (the clock frame starts near x = 745).
const TITLE_MAX_WIDTH := 620.0
const TITLE_PAST_SIZE := 110
## "ME" is drawn this many times larger than "THE OTHER".
const TITLE_ME_SCALE := 1.9
const InputManager := preload("res://scripts/input/input_manager.gd")

var audio: AudioDirector

var settings_path: String = "user://menu_settings.cfg"
var _last_focus: Control
var _lan_mode: String = ""
var _quit_return_page: String = ""
var _entering_game: bool = false
## Kept configurable for automated loopback tests and occupied-port diagnostics.
var lan_port: int = 7000

@onready var backdrop: Control = $Atmosphere
@onready var overlay: ColorRect = $Overlay
@onready var panel: PanelContainer = $Overlay/Center/Panel
@onready var pages: VBoxContainer = $Overlay/Center/Panel/Margin/Pages
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var motion_toggle: CheckButton = %MotionToggle


func _ready() -> void:
	audio = load("res://scenes/audio/audio_system.tscn").instantiate()
	add_child(audio)
	_build_audio_settings()
	audio.bind_ui(self)
	_apply_theme()
	%PlayButton.pressed.connect(_open_page.bind("PlayPage"))
	%SettingsButton.pressed.connect(_open_page.bind("SettingsPage"))
	%CreditsButton.pressed.connect(_open_page.bind("CreditsPage"))
	%QuitButton.pressed.connect(_open_page.bind("QuitPage"))
	%BackButton.pressed.connect(_close_page)
	%ConfirmQuit.pressed.connect(func() -> void: get_tree().quit())
	%HostButton.pressed.connect(_open_host)
	%JoinButton.pressed.connect(_open_join)
	%ConnectButton.pressed.connect(_join_lan)
	%HostAddress.text_submitted.connect(func(_text: String) -> void: _join_lan())
	%CopyAddress.pressed.connect(_copy_host_address)
	%ReadyButton.pressed.connect(func() -> void: NetworkManager.set_ready(not NetworkManager.guest_ready))
	%StartGameButton.pressed.connect(func() -> void: NetworkManager.start_game())
	%PreviewButton.pressed.connect(_preview_spawn_area)
	%LevelTwoTestButton.pressed.connect(_preview_maintenance_corridor)
	%LevelThreeTestButton.pressed.connect(_preview_temporal_core)
	%LevelThreeMultiplayerButton.pressed.connect(_open_temporal_core_multiplayer)
	%LevelThreeMultiplayerButton.visible = OS.is_debug_build()
	NetworkManager.state_changed.connect(_refresh_lan)
	NetworkManager.game_started.connect(_enter_spawn_area)
	fullscreen_toggle.toggled.connect(_set_fullscreen)
	motion_toggle.toggled.connect(_set_motion)
	_load_settings()
	%PlayButton.grab_focus()
	_update_coop_hint()
	InputManager.get_instance().device_changed_signal.connect(func(_d: int, _c: int) -> void: _update_coop_hint())
	# Let the menu handle closing so an accidental window close can be cancelled.
	get_tree().auto_accept_quit = false


func _update_coop_hint() -> void:
	var hint: Label = get_node_or_null("Layout/CoopHint")
	if not is_instance_valid(hint):
		return
	var is_controller := InputManager.active_device_type == InputManager.DeviceType.CONTROLLER
	var is_dualsense := InputManager.active_controller_type == InputManager.ControllerType.DUALSENSE
	if is_controller:
		var confirm_btn := "✕" if is_dualsense else "A"
		var back_btn := "○" if is_dualsense else "B"
		hint.text = "A MYSTERY FOR TWO     ·     D-PAD / STICK + %s CONFIRM     ·     %s BACK" % [confirm_btn, back_btn]
	else:
		hint.text = "A MYSTERY FOR TWO     ·     MOUSE OR ↑ ↓ + ENTER     ·     ESC BACK"


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		if overlay.visible and not pages.get_node("QuitPage").visible:
			for page in pages.get_children():
				if page.name != "BackButton" and page.visible:
					_quit_return_page = str(page.name)
		_open_page("QuitPage")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel"):
		if overlay.visible:
			_close_page()
		else:
			_open_page("QuitPage")
		get_viewport().set_input_as_handled()


func _apply_theme() -> void:
	# Button, label and toggle styling lives in resources/ui/menu_theme.tres (assigned on the scene root).
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("122028")
	panel_style.border_color = Color("627f80")
	panel_style.set_border_width_all(1)
	panel_style.shadow_color = Color(0, 0, 0, 0.45)
	panel_style.shadow_size = 30
	panel.add_theme_stylebox_override("panel", panel_style)
	_apply_title_typography()


## Broken is reserved for the game name; menu controls take Oxanium from the theme.
## "THE OTHER" fits the free column beside the clock; "ME" is set at a larger scale so the name reads as a lockup.
func _apply_title_typography() -> void:
	var title_font := Typography.font(&"menu_title")
	var past: Label = $Layout/TitleBlock/Past
	var future: Label = $Layout/TitleBlock/Future
	var past_px := Typography.fit_size(title_font, past.text, TITLE_PAST_SIZE, TITLE_MAX_WIDTH, 40)
	var future_px := roundi(past_px * TITLE_ME_SCALE)
	for entry: Array in [[past, past_px], [future, future_px]]:
		var label: Label = entry[0]
		label.add_theme_font_override("font", title_font)
		label.add_theme_font_size_override("font_size", entry[1])


func _open_page(page_name: String) -> void:
	audio.play_ui(&"menu_open")
	if not overlay.visible:
		_last_focus = get_viewport().gui_get_focus_owner()
	for page in pages.get_children():
		if page.name != "BackButton":
			page.visible = page.name == page_name
	$Layout.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	overlay.show()
	%BackButton.text = "STAY" if page_name == "QuitPage" else "BACK"
	if page_name == "PlayPage":
		%PreviewButton.grab_focus()
	elif page_name == "SettingsPage":
		pages.get_node("SettingsPage/SettingsContent").tabs.get_tab_bar().grab_focus()
	elif page_name == "QuitPage":
		%ConfirmQuit.grab_focus()
	else:
		%BackButton.grab_focus()


func _close_page() -> void:
	audio.play_ui(&"menu_close")
	if pages.get_node("QuitPage").visible and not _quit_return_page.is_empty():
		var return_page := _quit_return_page
		_quit_return_page = ""
		_open_page(return_page)
		_refresh_lan()
		return
	if pages.get_node("LanPage").visible:
		NetworkManager.leave_game()
	overlay.hide()
	$Layout.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	if is_instance_valid(_last_focus):
		_last_focus.grab_focus()


func _open_host() -> void:
	_lan_mode = "host"
	%HostAddresses.clear()
	for address in NetworkManager.local_addresses():
		%HostAddresses.add_item(address)
	%HostAddresses.disabled = %HostAddresses.item_count == 0
	%CopyAddress.disabled = %HostAddresses.item_count == 0
	NetworkManager.host_game(lan_port)
	_open_page("LanPage")
	_refresh_lan()


func _open_join() -> void:
	_lan_mode = "join"
	NetworkManager.leave_game()
	_open_page("LanPage")
	_refresh_lan()
	%HostAddress.grab_focus()


func _join_lan() -> void:
	if NetworkManager.state != NetworkManager.State.IDLE or _lan_mode != "join":
		return
	NetworkManager.join_game(%HostAddress.text, lan_port)


func _copy_host_address() -> void:
	if %HostAddresses.item_count > 0:
		DisplayServer.clipboard_set(%HostAddresses.get_item_text(%HostAddresses.selected))


func _refresh_lan() -> void:
	if not is_node_ready():
		return
	var connected := NetworkManager.state == NetworkManager.State.CONNECTED
	var idle := NetworkManager.state == NetworkManager.State.IDLE
	var focus_ready: bool = connected and _lan_mode == "join" and %ConnectButton.visible
	%LanTitle.text = "Host on Wi-Fi" if _lan_mode == "host" else "Join on Wi-Fi"
	%HostDetails.visible = _lan_mode == "host"
	%JoinDetails.visible = _lan_mode == "join"
	%HostAddress.editable = idle
	%ConnectButton.disabled = not idle
	%ConnectButton.text = "CONNECTING…" if NetworkManager.state == NetworkManager.State.CONNECTING else "JOIN GAME"
	%ConnectButton.visible = not connected
	%LanStatus.text = NetworkManager.status
	if NetworkManager.status.is_empty():
		%LanStatus.text = "Ask the host for the address shown on their screen."
	%PastRole.text = "STUDENT · PAST\nHost connected" if not idle else "STUDENT · PAST\nWaiting for host"
	%FutureRole.text = "PROFESSOR · FUTURE\n" + ("Ready" if NetworkManager.guest_ready else "Connected") if connected else "PROFESSOR · FUTURE\nWaiting to join"
	%ReadyButton.visible = connected and _lan_mode == "join"
	%StartGameButton.visible = connected and _lan_mode == "host"
	%StartGameButton.disabled = not NetworkManager.guest_ready
	%ReadyButton.text = "READY ✓" if NetworkManager.guest_ready else "I'M READY"
	if focus_ready and pages.get_node("LanPage").visible:
		%ReadyButton.grab_focus.call_deferred()
	%SessionHint.visible = connected
	if pages.get_node("LanPage").visible:
		%BackButton.text = "BACK" if idle else "LEAVE SESSION"


func _preview_spawn_area() -> void:
	if NetworkManager.state == NetworkManager.State.IDLE:
		PuzzleManager.offline_role = "past"
		PuzzleManager.begin_session()  # a new solo run starts with fresh puzzles
		_enter_spawn_area()


## Temporary testing shortcut. Seed only Level 01; the corridor starts unsolved.
func _preview_maintenance_corridor() -> void:
	if _entering_game or NetworkManager.state != NetworkManager.State.IDLE:
		return
	_entering_game = true
	PuzzleManager.offline_role = "past"
	PuzzleManager.begin_session()
	var frequency = load("res://scripts/puzzles/implementations/frequency_puzzle.gd")
	if not PuzzleManager.is_registered(frequency.ID):
		PuzzleManager.register_puzzle(frequency.ID, frequency.new())
	PuzzleManager.submit_action(frequency.ID, "acquire_radio", {"radio_role": "past"}, "past")
	PuzzleManager.submit_action(frequency.ID, "acquire_radio", {"radio_role": "future"}, "future")
	PuzzleManager.submit_action(frequency.ID, "tune_frequency", {"frequency": 67}, "past")
	PuzzleManager.submit_action(frequency.ID, "tune_amplitude", {"amplitude": 70}, "past")
	get_tree().change_scene_to_file.call_deferred("res://scenes/world/maintenance_corridor.tscn")


## Reuse Room C's offline role switch and real rules; no earlier puzzles are marked solved.
func _preview_temporal_core() -> void:
	if _entering_game or NetworkManager.state != NetworkManager.State.IDLE:
		return
	_entering_game = true
	PuzzleManager.offline_role = "past"
	PuzzleManager.begin_session()
	GameFlowManager.start_room.call_deferred("room_03")


func _open_temporal_core_multiplayer() -> void:
	if _entering_game or NetworkManager.state != NetworkManager.State.IDLE:
		return
	_entering_game = true
	get_tree().change_scene_to_file.call_deferred("res://scenes/testing/temporal_core_sandbox.tscn")


func _enter_spawn_area() -> void:
	if _entering_game:
		return
	_entering_game = true
	get_tree().change_scene_to_file.call_deferred("res://scenes/world/spawn_area.tscn")


func _set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()


func _set_motion(enabled: bool) -> void:
	backdrop.motion_enabled = enabled
	_save_settings()


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(settings_path)
	config.set_value("display", "fullscreen", fullscreen_toggle.button_pressed)
	config.set_value("display", "ambient_motion", motion_toggle.button_pressed)
	var error := config.save(settings_path)
	if error != OK:
		push_warning("Could not save menu settings: %s" % error_string(error))


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	var fullscreen := bool(config.get_value("display", "fullscreen", false))
	var motion := bool(config.get_value("display", "ambient_motion", true))
	fullscreen_toggle.set_pressed_no_signal(fullscreen)
	motion_toggle.set_pressed_no_signal(motion)
	backdrop.motion_enabled = motion
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func _build_audio_settings() -> void:
	var settings := pages.get_node("SettingsPage")
	var content := preload("res://scripts/ui/settings_content.gd").new()
	content.name = "SettingsContent"
	content.audio = audio
	settings.add_child(content)
	content.add_display_page(fullscreen_toggle, motion_toggle)
	settings.get_node("Hint").hide()
