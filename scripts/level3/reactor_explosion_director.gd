extends Node
## Local cinematic clock follows host elapsed snapshots. Never authorizes gameplay failure.
signal finished
signal explosion_audio_cue_requested(cue: StringName)

const Instability := preload("res://scripts/level3/reactor_instability_controller.gd")
const DURATION := 5.0
var active := false
var elapsed := 0.0
var _complete := false
var _impact := false
var _shockwave := false
var _room: Node3D
var _controllers: Dictionary = {}
var _layer: CanvasLayer
var _white: ColorRect
var _black: ColorRect
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _reduced := false
var _preference_age := 0.0


func setup(room: Node3D) -> void:
	_room = room
	_reduced = CinematicTransitionManager.is_reduced_motion()
	for timeline: String in room.worlds:
		var controller := Instability.new()
		room.worlds[timeline].add_child(controller)
		controller.setup(room.worlds[timeline], room.reactor_bridge.modules.get(timeline))
		controller.reduced_motion = _reduced
		_controllers[timeline] = controller
	_layer = CanvasLayer.new()
	_layer.layer = 95
	add_child(_layer)
	_white = _rect(Color(0.83, 0.92, 1, 0))
	_black = _rect(Color(0, 0, 0, 0))
	_bar_top = _rect(Color.BLACK)
	_bar_bottom = _rect(Color.BLACK)
	for bar in [_bar_top, _bar_bottom]: bar.hide()
	_bar_top.anchor_bottom = 0.075
	_bar_bottom.anchor_top = 0.925


func _rect(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


func begin(confirmed_elapsed: float = 0.0) -> void:
	if active: return
	active = true
	elapsed = clampf(confirmed_elapsed, 0.0, DURATION)
	_bar_top.show()
	_bar_bottom.show()
	# Covers HUD buttons and consumes mouse input, while keyboard is locked by the room.
	_black.mouse_filter = Control.MOUSE_FILTER_STOP


func confirm_time(value: float) -> void:
	if active: elapsed = maxf(elapsed, clampf(value, 0.0, DURATION))


func release_cover() -> void:
	_layer.hide()


func _process(delta: float) -> void:
	if _room == null or not _room._configured: return
	_preference_age += delta
	if _preference_age >= 0.75:
		_preference_age = 0.0
		_reduced = CinematicTransitionManager.is_reduced_motion()
		for item: Node3D in _controllers.values(): item.reduced_motion = _reduced
	var state: Dictionary = _room.state
	var armed: bool = state.get("stage") in ["STAGE_A", "STAGE_B", "STAGE_C"]
	if active and not _complete: elapsed = minf(DURATION, elapsed + delta)
	var remaining: float = state.get("remaining", 150.0)
	if armed: remaining = maxf(0.0, remaining - (_room._clock() - _room._snapshot_at))
	var controller: Node3D = _controllers[_room.role]
	controller.update_presentation(delta if active or not _room._paused else 0.0, remaining, armed, elapsed if active else -1.0)
	var shake: float = pow(controller.intensity, 2.0) * 0.07
	if active:
		var impact_age := maxf(0, elapsed - 0.8)
		shake = 0.10 + (0.27 * exp(-impact_age*2.5) if elapsed >= 0.8 else elapsed * 0.12)
		shake *= 1.0 - smoothstep(3.5, 4.6, elapsed)
		_room.camera_rig.cinematic_focus = _room.worlds[_room.role].global_position + Vector3(0, 1.8, 0)
		_room.camera_rig.cinematic_weight = smoothstep(0.0, 0.75, elapsed) * 0.65
		if elapsed >= 0.8 and not _impact:
			_impact = true
			explosion_audio_cue_requested.emit(&"impact")
			explosion_audio_cue_requested.emit(&"rupture")
		if elapsed >= 1.1 and not _shockwave:
			_shockwave = true
			explosion_audio_cue_requested.emit(&"shockwave")
		# One soft impact wash, then an authored white-to-black collapse. No strobes.
		var wash := sin(clampf((elapsed - 0.8) / 0.6, 0, 1) * PI) * (0.06 if _reduced else 0.18)
		_white.color.a = maxf(wash, smoothstep(3.45, 4.18, elapsed) * (0.55 if _reduced else 1.0))
		_black.color.a = smoothstep(4.16, 4.8, elapsed)
	var motion_time: float = controller._clock
	if _reduced: shake = 0.0
	_room.camera.h_offset = (sin(motion_time*23)*0.6 + sin(motion_time*37)*0.4)*shake
	_room.camera.v_offset = sin(motion_time*29)*shake*0.55
	if active and elapsed >= DURATION and not _complete:
		_complete = true
		finished.emit()


func _exit_tree() -> void:
	if is_instance_valid(_room) and is_instance_valid(_room.camera):
		_room.camera.h_offset = 0
		_room.camera.v_offset = 0
		_room.camera_rig.cinematic_weight = 0
