extends Node3D
## The playable room: the Signal Laboratory (SignalLab) around the original greybox furniture.
## SpawnPoint and prop instances are editable in Godot.

@export_enum("Past", "Future") var timeline: String = "Past"
@export var pause_when_unfocused: bool = true

var _networked: bool = false
var _paused: bool = false
var _disconnected: bool = false
var _character_studio: Control
var _modal_open: bool = false

@onready var player: CharacterBody3D = $Actors/Player
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var pause_panel: ColorRect = %PausePanel
@onready var lab: SignalLab = $SignalLab
@onready var interaction: InteractionController = $Actors/Player/InteractionRig/InteractionController
@onready var radio: TemporalRadio = $Actors/Player/TemporalRadio


func _ready() -> void:
	_networked = NetworkManager.in_game
	if _networked:
		timeline = "Past" if NetworkManager.role == "past" else "Future"
	NetworkManager.state_changed.connect(_on_network_changed)
	%PauseButton.pressed.connect(_set_paused.bind(true))
	%ResumeButton.pressed.connect(_set_paused.bind(false))
	%MenuButton.pressed.connect(_return_to_menu)
	%QuitGameButton.pressed.connect(func() -> void: get_tree().quit())
	%TimelineButton.pressed.connect(_switch_preview_timeline)
	%CharacterButton.pressed.connect(_open_character_studio)
	%TimelineButton.visible = not _networked
	player.view_camera = camera
	interaction.prompt_ui = $InteractionPrompt
	# Sit the interaction prompt above the footer hint bar instead of on top of it.
	var prompt_panel: Control = $InteractionPrompt/Root/PromptPanel
	prompt_panel.offset_top -= 56.0
	prompt_panel.offset_bottom -= 56.0
	lab.ui.modal_changed.connect(_on_modal_changed)
	lab.attach_radio(radio)
	for screen in [lab.terminal, lab.reader]:
		screen.modal_changed.connect(_on_modal_changed)
	_apply_timeline()
	respawn()
	get_tree().auto_accept_quit = false
	# The scene can also run directly with F6, without a network session.
	if _networked:
		_on_network_changed()


func _input(event: InputEvent) -> void:
	if is_instance_valid(_character_studio):
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_F2):
			_character_studio.request_close()
			get_viewport().set_input_as_handled()
		return
	if _modal_open:
		return  # A LabUI or frequency screen owns the keyboard while it is open.
	if event.is_action_pressed("ui_cancel"):
		if not _disconnected:
			_set_paused(not _paused)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and not _paused:
		if event.physical_keycode == KEY_F2:
			_open_character_studio()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_R:
			respawn()
			get_viewport().set_input_as_handled()


func _open_character_studio() -> void:
	if _disconnected or is_instance_valid(_character_studio):
		return
	_set_paused(true)
	pause_panel.hide()
	_character_studio = load("res://scenes/characters/student_3d_studio.tscn").instantiate()
	$HUD/Interface.add_child(_character_studio)
	_character_studio.close_requested.connect(func() -> void:
		_character_studio = null
		_set_paused(false)
	)


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
	var future := timeline == "Future"
	var accent := Color("89ccd4") if future else Color("e4bf7f")
	$Floor.future = future
	$Floor.spawn_position = $SpawnPoint.position
	for prop in $Actors.get_children():
		if prop != player:
			prop.future = future
	player.body_color = accent
	lab.future = future
	var role := "future" if future else "past"
	if not _networked:
		# Solo preview: actions taken here act for the timeline on screen.
		PuzzleManager.offline_role = role
	interaction.detector.set_current_role(role)
	interaction.detector.refresh_target()
	radio.set_player_role(role)
	$Actors/Player/Visual/RadioSocket/RadioModel.future = future
	%TimelineLabel.text = "II  /  FUTURE" if future else "I  /  PAST"
	%TimelineLabel.add_theme_color_override("font_color", accent)
	%RoleLabel.text = "THE PROFESSOR" if future else "THE STUDENT"
	%TimelineButton.text = "VIEW PAST" if future else "VIEW FUTURE"
	%ConnectionLabel.text = "LAN CO-OP  ·  TWO TIMELINES" if _networked else "SOLO PREVIEW"


func _switch_preview_timeline() -> void:
	if _networked:
		return
	timeline = "Future" if timeline == "Past" else "Past"
	_apply_timeline()


func _set_paused(paused: bool) -> void:
	if _disconnected and not paused:
		return
	_paused = paused
	_update_controls()
	player.velocity = Vector3.ZERO
	pause_panel.visible = paused
	%PauseTitle.text = "A moment between years"
	%PauseDescription.text = "Take your time. The lab will be here."
	%QuitGameButton.hide()
	if paused:
		%ResumeButton.grab_focus()


func _on_modal_changed(_open: bool) -> void:
	_modal_open = lab.ui.is_modal_open() or lab.terminal.visible or lab.reader.visible
	_update_controls()


func _update_controls() -> void:
	player.controls_enabled = not _paused and not _modal_open
	interaction.set_interaction_blocked(_paused or _modal_open)


func _on_network_changed() -> void:
	if not _networked or (NetworkManager.state == NetworkManager.State.CONNECTED and NetworkManager.in_game):
		return
	_disconnected = true
	_set_paused(true)
	%PauseTitle.text = "The connection was lost"
	%PauseDescription.text = "Your partner left the session. Return to the menu to reconnect."
	%ResumeButton.hide()
	%MenuButton.grab_focus()


func _return_to_menu() -> void:
	if _networked:
		NetworkManager.leave_game()
	get_tree().change_scene_to_file.call_deferred("res://scenes/menu/main_menu.tscn")
