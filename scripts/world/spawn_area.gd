extends Node3D
## Playable Signal Laboratory, entered by Solo Test or the existing LAN lobby.
## SpawnPoint and prop instances are editable in Godot.

const InputManager := preload("res://scripts/input/input_manager.gd")

@export_enum("Past", "Future") var timeline: String = "Past"
@export var pause_when_unfocused: bool = true

var _networked: bool = false
var _paused: bool = false
var _disconnected: bool = false
var _character_studio: Control
var _leaving: bool = false

@onready var player: CharacterBody3D = $Actors/Player
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var pause_panel: ColorRect = %PausePanel
@onready var gameplay: Node3D = $LaboratoryGameplay
@onready var lab: SignalLab = $SignalLab

# Keep the room's public accessors bound when solo mode replaces the character.
var interaction: InteractionController:
	get:
		return gameplay.controller as InteractionController
var radio: TemporalRadio:
	get:
		return gameplay.radio


func _ready() -> void:
	_networked = NetworkManager.in_game
	if _networked:
		timeline = "Past" if NetworkManager.role == "past" else "Future"
	else:
		timeline = "Future" if PuzzleManager.get_local_role() == "future" else "Past"
	NetworkManager.state_changed.connect(_on_network_changed)
	%PauseButton.pressed.connect(_set_paused.bind(true))
	%ResumeButton.pressed.connect(_set_paused.bind(false))
	%MenuButton.pressed.connect(_return_to_menu)
	%QuitGameButton.pressed.connect(func() -> void: get_tree().quit())
	%TimelineButton.pressed.connect(_switch_preview_timeline)
	%CharacterButton.pressed.connect(_open_character_studio)
	%ResetSoloButton.pressed.connect(reset_solo_session)
	%InterferenceButton.pressed.connect(_test_interference)
	%TimelineButton.visible = not _networked
	%ResetSoloButton.visible = not _networked
	%InterferenceButton.visible = not _networked
	player.view_camera = camera
	_apply_timeline()
	gameplay.initialize(self)
	respawn()
	# Level flow: this scene is Room 01, and its controls follow the transition lock.
	GameFlowManager.attach_room("room_01", self)
	GameFlowManager.input_lock_changed.connect(func(_locked: bool) -> void: gameplay.sync_controls())
	get_tree().auto_accept_quit = false
	_update_footer_hint()
	InputManager.get_instance().device_changed_signal.connect(func(_d: int, _c: int) -> void: _update_footer_hint())
	# The scene can also run directly with F6, without a network session.
	if _networked:
		_on_network_changed()


func _update_footer_hint() -> void:
	var hint: Label = get_node_or_null("HUD/Interface/Footer/Hint")
	if not is_instance_valid(hint):
		return
	var is_controller := InputManager.active_device_type == InputManager.DeviceType.CONTROLLER
	var is_dualsense := InputManager.active_controller_type == InputManager.ControllerType.DUALSENSE
	if is_controller:
		var interact_btn := "✕" if is_dualsense else "A"
		var sprint_btn := "L3" if is_dualsense else "LS"
		var cancel_btn := "○" if is_dualsense else "B"
		var pause_btn := "OPTIONS" if is_dualsense else "MENU"
		hint.text = "LEFT STICK  ·  MOVE     %s  ·  RUN     %s  ·  INTERACT / ADVANCE DIALOGUE\n%s  ·  PAUSE / RESUME     %s  ·  CANCEL / BACK" % [sprint_btn, interact_btn, pause_btn, cancel_btn]
	else:
		hint.text = "WASD / ARROWS  ·  MOVE     SHIFT  ·  RUN     F  ·  INTERACT     ENTER / CLICK DIALOGUE  ·  CONTINUE\nT  ·  SWITCH SOLO ROLE     F2  ·  CHARACTER STUDIO     R  ·  RESPAWN     ESC  ·  PAUSE"


func _input(event: InputEvent) -> void:
	if gameplay.configured and gameplay.has_modal() and not _paused:
		return  # the terminal/document owns Escape and all gameplay input
	if is_instance_valid(_character_studio):
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_F2):
			_character_studio.request_close()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if not _paused and GameFlowManager.is_local_ready():
			GameFlowManager.cancel_transition_request()
			get_viewport().set_input_as_handled()
			return
		if not _disconnected:
			_set_paused(not _paused)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and not _paused:
		if event.physical_keycode == KEY_F2:
			_open_character_studio()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_R:
			if not player.is_action_active() and not gameplay.director.is_gameplay_input_blocked():
				respawn()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_T:
			_switch_preview_timeline()
			get_viewport().set_input_as_handled()


func _open_character_studio() -> void:
	if _disconnected or is_instance_valid(_character_studio) or player.is_action_active() or (gameplay.configured and (gameplay.has_modal() or gameplay.director.is_dialogue_active())):
		return
	_set_paused(true)
	pause_panel.hide()
	_character_studio = load("res://scenes/characters/%s_3d_studio.tscn" % ("professor" if timeline == "Future" else "student")).instantiate()
	$HUD/Interface.add_child(_character_studio)
	_character_studio.close_requested.connect(func() -> void:
		_character_studio = null
		_set_paused(false)
	)
	gameplay.sync_controls()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		_set_paused(true)
		%PauseTitle.text = "Leave this timeline?"
		%QuitGameButton.show()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and pause_when_unfocused and not _paused:
		_set_paused(true)


func respawn() -> void:
	player.global_position = $SpawnPoint.global_position
	player.velocity = Vector3.ZERO
	$CameraRig.snap_to_target()


func _apply_timeline() -> void:
	_replace_character_for_timeline()
	var future := timeline == "Future"
	var accent := Color("89ccd4") if future else Color("e4bf7f")
	$Floor.future = future
	$Floor.spawn_position = $SpawnPoint.position
	for prop in $Actors.get_children():
		if prop != player:
			prop.future = future
	player.body_color = accent
	lab.future = future
	%TimelineLabel.text = "II  /  FUTURE" if future else "I  /  PAST"
	%TimelineLabel.add_theme_color_override("font_color", accent)
	%RoleLabel.text = "THE PROFESSOR" if future else "THE STUDENT"
	%TimelineButton.text = "PLAY AS STUDENT" if future else "PLAY AS PROFESSOR"
	%ConnectionLabel.text = "LAN CO-OP  ·  TWO TIMELINES" if _networked else "SOLO TEST  ·  T TO SWITCH ROLE"
	if not _networked:
		PuzzleManager.offline_role = "future" if future else "past"
	if gameplay.configured:
		gameplay.apply_timeline()


func _replace_character_for_timeline() -> void:
	var path := "res://scenes/characters/%s_3d_player.tscn" % ("professor" if timeline == "Future" else "student")
	if player.scene_file_path == path:
		return
	if gameplay.configured:
		gameplay.detach_player()
	var old := player
	var last_position := old.position
	old.controls_enabled = false
	$Actors.remove_child(old)
	old.queue_free()
	player = load(path).instantiate()
	player.name = "Player"
	player.position = last_position
	$Actors.add_child(player)
	player.view_camera = camera
	$CameraRig.target = player
	if gameplay.configured:
		gameplay.bind_player()
	$CameraRig.snap_to_target()


func _switch_preview_timeline() -> void:
	if _networked or not gameplay.can_switch_role():
		return
	timeline = "Future" if timeline == "Past" else "Past"
	_apply_timeline()
	$CameraRig.snap_to_target()


func _set_paused(paused: bool) -> void:
	if _disconnected and not paused:
		return
	if _paused != paused and gameplay.configured:
		gameplay.audio.play_ui(&"ui_pause" if paused else &"ui_unpause")
	_paused = paused
	player.controls_enabled = not paused
	player.velocity = Vector3.ZERO
	pause_panel.visible = paused
	%PauseTitle.text = "A moment between years"
	%PauseDescription.text = "Take your time. The lab will be here."
	%QuitGameButton.hide()
	if paused:
		%ResumeButton.grab_focus()
	if gameplay.configured:
		gameplay.sync_controls()


func is_gameplay_paused() -> bool:
	return _paused or _disconnected or is_instance_valid(_character_studio) or GameFlowManager.is_input_locked()


## Level-flow hook: a transition is starting, so close whatever is open.
func game_flow_suspend() -> void:
	gameplay.close_overlays()


func is_character_studio_open() -> bool:
	return is_instance_valid(_character_studio)


func reset_solo_session() -> void:
	if _networked or _disconnected:
		return
	gameplay.close_overlays()
	PuzzleManager.begin_session()
	timeline = "Past"
	_apply_timeline()
	_set_paused(false)
	respawn()


func _test_interference() -> void:
	_set_paused(false)
	gameplay.radio.interfere(2.0)


func _on_network_changed() -> void:
	if _leaving or not _networked or (NetworkManager.state == NetworkManager.State.CONNECTED and NetworkManager.in_game):
		return
	gameplay.audio.play_sfx(&"radio_disconnect")
	_disconnected = true
	gameplay.close_overlays()
	_set_paused(true)
	%PauseTitle.text = "The connection was lost"
	%PauseDescription.text = "Your partner left the session. Return to the menu to reconnect."
	%ResumeButton.hide()
	%MenuButton.grab_focus()


func _return_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	gameplay.shutdown(0.18)
	await get_tree().create_timer(0.2).timeout
	NetworkManager.leave_game()
	PuzzleManager.reset_all()
	get_tree().change_scene_to_file.call_deferred("res://scenes/menu/main_menu.tscn")
