extends Node3D
## Playable Signal Laboratory, entered by Solo Test or the existing LAN lobby.
## SpawnPoint and prop instances are editable in Godot.

const InputManager := preload("res://scripts/input/input_manager.gd")
const TemporalGhost := preload("res://scripts/world/temporal_ghost.gd")

@export_enum("Past", "Future") var timeline: String = "Past"
@export var pause_when_unfocused: bool = true
@export var level_travel_enabled: bool = true
@export var temporal_ghost_enabled: bool = true
## Opens the "how to play" popup the first time this player reaches the room (never when headless).
@export var tutorial_auto_show: bool = DisplayServer.get_name() != "headless"

const CorridorRules := preload("res://scripts/puzzles/implementations/maintenance_corridor_puzzle.gd")

var _networked: bool = false
var _paused: bool = false
var _disconnected: bool = false
var _character_studio: Control
var _leaving: bool = false
var temporal_ghost: Node3D
var settings_overlay: CanvasLayer
var tutorial: TutorialPopup

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
	settings_overlay = preload("res://scripts/ui/settings_overlay.gd").new()
	add_child(settings_overlay)
	settings_overlay.configure(gameplay.audio)
	%SettingsButton.pressed.connect(func() -> void:
		pause_panel.hide()
		settings_overlay.open()
	)
	settings_overlay.closed.connect(func() -> void:
		pause_panel.show()
		%SettingsButton.grab_focus()
	)
	tutorial = load("res://scenes/ui/tutorial_popup.tscn").instantiate()
	add_child(tutorial)
	tutorial.configure(gameplay.audio)
	tutorial.closed.connect(_on_tutorial_closed)
	tutorial.opened.connect(gameplay.sync_controls)
	%HowToPlayButton.pressed.connect(_open_tutorial.bind(true))
	if not PuzzleManager.is_registered(CorridorRules.ID):
		PuzzleManager.register_puzzle(CorridorRules.ID, CorridorRules.new())
	lab.player_exited.connect(_on_laboratory_exit)
	respawn()
	if not _networked and temporal_ghost_enabled:
		if not gameplay._positions.has("future"): gameplay._positions["future"] = $SpawnPoint.global_position
		var roots: Array[Node3D] = [$SignalLab/Layout]
		for prop in $Actors.get_children():
			if prop != player: roots.append(prop.get_node("Visual"))
		temporal_ghost = TemporalGhost.new()
		add_child(temporal_ghost)
		temporal_ghost.configure(self, roots, _temporal_ghost_context)
	# Level flow: this scene is Room 01, and its controls follow the transition lock.
	GameFlowManager.attach_room("room_01", self)
	GameFlowManager.input_lock_changed.connect(func(_locked: bool) -> void: gameplay.sync_controls())
	get_tree().auto_accept_quit = false
	# The scene can also run directly with F6, without a network session.
	if _networked:
		_on_network_changed()
	if tutorial_auto_show:
		_show_first_time_tutorial()


func _temporal_ghost_context() -> Dictionary:
	return {"role": "future" if timeline == "Future" else "past", "player": player,
		"past_position": player.global_position if timeline == "Past" else gameplay._positions.get("past", $SpawnPoint.global_position),
		"future_position": player.global_position if timeline == "Future" else gameplay._positions.get("future", $SpawnPoint.global_position),
		"inspecting": gameplay.physical_devices != null and gameplay.physical_devices.inspector.active,
		"blocked": is_gameplay_paused() or _leaving or JournalManager.is_open()}


func _input(event: InputEvent) -> void:
	if settings_overlay != null and settings_overlay.handle_input(event): return
	if tutorial != null and tutorial.handle_input(event): return  # owns Escape / back while open
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


func _on_laboratory_exit(body: Node3D) -> void:
	if not level_travel_enabled or body != player or _leaving:
		return
	PuzzleManager.submit_action(CorridorRules.ID, "arrive")
	# Walking through the door and using the exit share the same host-authoritative flow.
	GameFlowManager.request_transition("room_02")


## Opens the tutorial for this player's own role only. Local: the partner and the session go on.
func _open_tutorial(from_pause: bool = false) -> void:
	if tutorial.is_open() or _leaving:
		return
	pause_panel.hide()
	tutorial.open("future" if timeline == "Future" else "past", from_pause)


func _on_tutorial_closed(_dismissed: bool) -> void:
	if _paused and not is_instance_valid(_character_studio):
		pause_panel.show()
		%HowToPlayButton.grab_focus()
	gameplay.sync_controls()


func _tutorial_can_open() -> bool:
	if _paused or _disconnected or _leaving or tutorial.is_open() or is_instance_valid(_character_studio):
		return false
	if CinematicTransitionManager.is_playing() or GameFlowManager.is_transitioning() or GameFlowManager.is_input_locked():
		return false
	return not (gameplay.has_modal() or gameplay.director.is_dialogue_active() or player.is_action_active())


## First visit only: waits for the room introduction, level flow and any early dialogue to settle.
func _show_first_time_tutorial() -> void:
	if TutorialPopup.has_been_shown():
		return
	while is_inside_tree() and not _tutorial_can_open():
		await get_tree().create_timer(0.25).timeout
	if is_inside_tree() and not TutorialPopup.has_been_shown():
		_open_tutorial()


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
	%TimelineLabel.text = "FUTURE" if future else "PAST"
	%TimelineLabel.add_theme_color_override("font_color", accent)
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
	if settings_overlay != null: settings_overlay.hide()
	%PauseTitle.text = "A moment between years"
	%PauseDescription.text = "Take your time. The lab will be here."
	%QuitGameButton.hide()
	if tutorial != null and tutorial.is_open():
		pause_panel.hide()  # a lost focus or connection must not cover or steal focus from it
	elif paused:
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
