extends Node3D
## Controller for the standalone Audio Sandbox.
## Provides manual preview controls for all sound IDs, volume sliders,
## ambience switching, and real-time movement/footstep status inspection.

@onready var audio_system: AudioDirector = $AudioSystem
@onready var player_character: CharacterBody3D = $Student3DPlayer
@onready var footstep_emitter: FootstepEmitter3D = $Student3DPlayer/FootstepEmitter3D
@onready var world_emitter_marker: Marker3D = $WorldAudioMarker

@onready var status_label: Label = %StatusLabel
@onready var footstep_label: Label = %FootstepLabel

# Volume sliders
@onready var slider_master: HSlider = %SliderMaster
@onready var slider_sfx: HSlider = %SliderSFX
@onready var slider_ui: HSlider = %SliderUI
@onready var slider_ambience: HSlider = %SliderAmbience
@onready var slider_music: HSlider = %SliderMusic

func _ready() -> void:
	# Ensure the player character has camera reference
	if is_instance_valid(player_character):
		player_character.view_camera = $FollowCamera/Camera3D
	
	# Connect footstep feedback
	if is_instance_valid(footstep_emitter):
		footstep_emitter.footstep_played.connect(_on_footstep_played)
	
	if is_instance_valid(audio_system):
		audio_system.sound_played.connect(_on_sound_played)
	
	_setup_volume_sliders()
	_setup_button_focus()

func _setup_volume_sliders() -> void:
	if not is_instance_valid(audio_system):
		return
	
	slider_master.value = audio_system.get_category_volume_linear(&"Master")
	slider_sfx.value = audio_system.get_category_volume_linear(&"SFX")
	slider_ui.value = audio_system.get_category_volume_linear(&"UI")
	slider_ambience.value = audio_system.get_category_volume_linear(&"Ambience")
	slider_music.value = audio_system.get_category_volume_linear(&"Music")
	
	slider_master.value_changed.connect(func(v: float): audio_system.set_category_volume_linear(&"Master", v))
	slider_sfx.value_changed.connect(func(v: float): audio_system.set_category_volume_linear(&"SFX", v))
	slider_ui.value_changed.connect(func(v: float): audio_system.set_category_volume_linear(&"UI", v))
	slider_ambience.value_changed.connect(func(v: float): audio_system.set_category_volume_linear(&"Ambience", v))
	slider_music.value_changed.connect(func(v: float): audio_system.set_category_volume_linear(&"Music", v))

func _setup_button_focus() -> void:
	# Set all UI controls to FOCUS_NONE so arrow keys and space stay on the character
	for node in find_children("*", "Control", true, false):
		var ctrl := node as Control
		if ctrl is Button or ctrl is Slider:
			ctrl.focus_mode = Control.FOCUS_NONE

func _process(_delta: float) -> void:
	if not is_instance_valid(player_character):
		return
	
	var vel := player_character.velocity
	var speed := Vector2(vel.x, vel.z).length()
	var state := "IDLE"
	if not player_character.is_on_floor():
		state = "AIRBORNE"
	elif speed >= footstep_emitter.run_speed_threshold:
		state = "RUNNING"
	elif speed >= footstep_emitter.movement_threshold:
		state = "WALKING"
	
	footstep_label.text = "Player Speed: %.2f m/s | State: %s | On Floor: %s" % [
		speed, state, str(player_character.is_on_floor())
	]

func _on_footstep_played(idx: int, pos: Vector3) -> void:
	status_label.text = "Footstep #%d played at (%.1f, %.1f, %.1f)" % [idx + 1, pos.x, pos.y, pos.z]

func _on_sound_played(id: StringName, is_3d: bool, pos: Vector3) -> void:
	if is_3d:
		status_label.text = "World SFX 3D: '%s' at (%.1f, %.1f, %.1f)" % [id, pos.x, pos.y, pos.z]
	else:
		status_label.text = "2D SFX / UI: '%s'" % id

# UI SFX triggers
func _on_btn_ui_click_pressed() -> void:
	audio_system.play_ui(&"ui_click")

func _on_btn_ui_hover_pressed() -> void:
	audio_system.play_ui(&"ui_hover")

func _on_btn_ui_confirm_pressed() -> void:
	audio_system.play_ui(&"ui_confirm")

func _on_btn_ui_back_pressed() -> void:
	audio_system.play_ui(&"ui_back")

# Interaction SFX triggers
func _on_btn_interact_click_pressed() -> void:
	audio_system.play_sfx(&"interaction_click")

func _on_btn_interact_success_pressed() -> void:
	audio_system.play_sfx(&"interaction_success")

func _on_btn_interact_denied_pressed() -> void:
	audio_system.play_sfx(&"interaction_denied")

# Environment SFX triggers (played at WorldAudioMarker 3D position)
func _on_btn_door_open_pressed() -> void:
	var pos := world_emitter_marker.global_position if is_instance_valid(world_emitter_marker) else Vector3.ZERO
	audio_system.play_world_sfx(&"door_open", pos)

func _on_btn_door_locked_pressed() -> void:
	var pos := world_emitter_marker.global_position if is_instance_valid(world_emitter_marker) else Vector3.ZERO
	audio_system.play_world_sfx(&"door_locked", pos)

func _on_btn_computer_beep_pressed() -> void:
	var pos := world_emitter_marker.global_position if is_instance_valid(world_emitter_marker) else Vector3.ZERO
	audio_system.play_world_sfx(&"computer_beep", pos)

func _on_btn_switch_toggle_pressed() -> void:
	var pos := world_emitter_marker.global_position if is_instance_valid(world_emitter_marker) else Vector3.ZERO
	audio_system.play_world_sfx(&"switch_toggle", pos)

func _on_btn_rift_hum_pressed() -> void:
	audio_system.play_sfx(&"rift_hum")

# Ambience triggers
func _on_btn_ambience_past_pressed() -> void:
	audio_system.start_ambience(&"lab_ambience_past")
	status_label.text = "Ambience: Past Laboratory started"

func _on_btn_ambience_future_pressed() -> void:
	audio_system.start_ambience(&"lab_ambience_future")
	status_label.text = "Ambience: Future Laboratory started"

func _on_btn_ambience_stop_pressed() -> void:
	audio_system.stop_ambience()
	status_label.text = "Ambience: Stopped"

