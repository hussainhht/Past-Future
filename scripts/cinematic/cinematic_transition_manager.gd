extends Node
## Room introductions (autoload "CinematicTransitionManager").
##
## Optional cinematic title cards, disabled during normal gameplay. When enabled, watches
## GameFlowManager and plays one title card per real room entry, styled for the
## local player's timeline. Everything here is local to this client: no RPCs, no puzzle state, no
## input locking. Each peer decides from its own role, so the Student sees the Past card and the
## Professor the Future card for the same room.
##
## Rooms are described by RoomIntroData resources in resources/cinematic/rooms/ and styled by
## RoomIntroStyle presets in resources/cinematic/presets/. A new room only needs a new .tres.
##
## Preview use (enable explicitly before playing):
##   CinematicTransitionManager.enabled = true
##   CinematicTransitionManager.show_room_intro("room_03")            # local timeline
##   CinematicTransitionManager.show_room_intro("room_03", "future")  # explicit timeline

## An introduction began on this client.
signal intro_started(room_id: String, timeline: String)
## It ended. completed is false when it was dismissed early.
signal intro_finished(room_id: String, completed: bool)
## An optional audio moment. Hook the game's audio here; unset cues never fire.
signal audio_cue_requested(cue: StringName, timeline: String, room_id: String)

const OverlayScene := preload("res://scenes/cinematic/cinematic_transition.tscn")
const INTRO_DIRECTORY := "res://resources/cinematic/rooms"
const PRESET_DIRECTORY := "res://resources/cinematic/presets"
const SETTINGS_PATH := "user://menu_settings.cfg"
const FALLBACK_PRESET := &"neutral"
## How long a pending introduction waits for the Journal or pause menu to close.
const MAX_WAIT_SECONDS := 8.0
const AUDIO_GROUP := &"lab_audio"

## Room entry goes straight to gameplay. Enable only for explicit cinematic previews.
var enabled: bool = false
## Global speed multiplier for every introduction (2.0 plays twice as fast).
var time_scale: float = 1.0
## null follows the main menu's "ambient motion" setting; true or false forces reduced motion.
var reduced_motion_override: Variant = null
var log_problems: bool = OS.is_debug_build()

var _intros: Dictionary = {}   # room_id -> RoomIntroData
var _styles: Dictionary = {}   # preset id -> RoomIntroStyle
var _overlay: CinematicTransition
var _overlay_room: String = ""
var _overlay_timeline: String = "past"
var _watched_node: Node
var _last_key: String = ""
var _pending_room: String = ""
var _pending_node: Node
var _token: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	load_presets()
	load_intro_directory()
	GameFlowManager.room_changed.connect(_on_room_changed)
	GameFlowManager.transition_started.connect(_on_transition_started)
	GameFlowManager.transition_completed.connect(_on_transition_completed)
	GameFlowManager.transition_failed.connect(_on_transition_failed)


func _exit_tree() -> void:
	_discard_overlay()


# --- Registry ------------------------------------------------------------------------------

## Make an introduction known. Returns false (and logs why) for an invalid or duplicate entry.
func register_intro(data: RoomIntroData, replace: bool = false) -> bool:
	if data == null:
		_problem("register_intro needs a RoomIntroData.")
		return false
	var error := data.validate()
	if not error.is_empty():
		_problem("Invalid room intro: %s" % error)
		return false
	if _intros.has(data.room_id) and _intros[data.room_id] != data and not replace:
		_problem("Room intro '%s' is already registered." % data.room_id)
		return false
	_intros[data.room_id] = data
	return true


func unregister_intro(room_id: String) -> bool:
	return _intros.erase(room_id)


func has_intro(room_id: String) -> bool:
	return _intros.has(room_id)


func get_intro(room_id: String) -> RoomIntroData:
	return _intros.get(room_id)


func register_style(style: RoomIntroStyle, replace: bool = false) -> bool:
	if style == null or style.preset_id == &"":
		_problem("register_style needs a RoomIntroStyle with a preset_id.")
		return false
	if _styles.has(style.preset_id) and _styles[style.preset_id] != style and not replace:
		return false
	_styles[style.preset_id] = style
	return true


## The preset by ID, or the neutral one for an unknown ID.
func get_style(preset_id: StringName) -> RoomIntroStyle:
	var style: RoomIntroStyle = _styles.get(preset_id)
	if style == null:
		_problem("Unknown intro preset '%s'; using '%s'." % [preset_id, FALLBACK_PRESET])
		style = _styles.get(FALLBACK_PRESET)
	return style


func load_intro_directory(directory: String = INTRO_DIRECTORY) -> int:
	var count := 0
	for path in _resource_paths(directory):
		var data := load(path) as RoomIntroData
		if data != null and register_intro(data):
			count += 1
	return count


func load_presets(directory: String = PRESET_DIRECTORY) -> int:
	var count := 0
	for path in _resource_paths(directory):
		var style := load(path) as RoomIntroStyle
		if style != null and register_style(style):
			count += 1
	return count


# --- Playing -------------------------------------------------------------------------------

## Play the introduction for room_id. timeline is "past" or "future"; empty uses the local role.
## The same room entry never plays twice unless force is true. Returns whether one started.
func show_room_intro(room_id: String, timeline: String = "", force: bool = false) -> bool:
	if not enabled:
		return false
	var data: RoomIntroData = _intros.get(room_id)
	if data == null:
		return false
	var side := _normalize_timeline(timeline)
	var node := _room_node_for(room_id)
	var key := "%s:%d" % [room_id, node.get_instance_id() if node != null else 0]
	if not force and key == _last_key:
		return false
	_discard_overlay()
	_last_key = key
	_watched_node = node
	_overlay_room = room_id
	_overlay_timeline = side
	_overlay = OverlayScene.instantiate() as CinematicTransition
	add_child(_overlay)
	_overlay.finished.connect(_on_overlay_finished.bind(_overlay))
	_overlay.audio_cue.connect(_on_overlay_cue)
	_overlay.play(data, get_style(data.get_preset(side)), side, is_reduced_motion(), time_scale)
	set_process(true)
	intro_started.emit(room_id, side)
	return true


func is_playing() -> bool:
	return _overlay != null and not _overlay.is_ended()


## End the running introduction with a short fade. Nothing happens when none is playing.
func dismiss() -> void:
	if is_playing():
		_overlay.dismiss()


## Forget which room entry already played, so the current room may introduce itself again.
func reset_history() -> void:
	_last_key = ""


func is_reduced_motion() -> bool:
	if reduced_motion_override != null:
		return bool(reduced_motion_override)
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return false
	return not bool(config.get_value("display", "ambient_motion", true))


# --- GameFlowManager integration -----------------------------------------------------------

func _on_room_changed(room_id: String) -> void:
	_pending_room = room_id if _intros.has(room_id) else ""
	_pending_node = GameFlowManager.get_current_room_node()
	if _pending_room.is_empty():
		_token += 1
		return
	# During a level transition the screen is still black: wait for transition_completed.
	if not GameFlowManager.is_transitioning():
		_present_when_ready()


func _on_transition_started(_from_room: String, _to_room: String) -> void:
	_token += 1
	_pending_room = ""
	dismiss()


func _on_transition_completed(room_id: String) -> void:
	if room_id == _pending_room and not room_id.is_empty():
		_present_when_ready()


func _on_transition_failed(_reason: String) -> void:
	_token += 1
	_pending_room = ""


## Waits for the room to finish its own _ready and for full-screen UI to close, then plays once.
func _present_when_ready() -> void:
	_token += 1
	var token := _token
	var room_id := _pending_room
	var node := _pending_node
	await get_tree().process_frame
	await get_tree().process_frame
	var deadline := Time.get_ticks_msec() + int(MAX_WAIT_SECONDS * 1000.0)
	while token == _token and _is_blocked():
		if Time.get_ticks_msec() > deadline:
			return
		await get_tree().process_frame
	if token != _token or not is_instance_valid(node) or not node.is_inside_tree():
		return
	if GameFlowManager.get_current_room_id() != room_id or GameFlowManager.get_current_room_node() != node:
		return
	_pending_room = ""
	show_room_intro(room_id)


## True while something full-screen sits above the room: the Journal or the pause menu.
func _is_blocked() -> bool:
	if JournalManager.is_open():
		return true
	var room := GameFlowManager.get_current_room_node()
	return is_instance_valid(room) and room.has_method("is_gameplay_paused") and bool(room.call("is_gameplay_paused"))


# --- Overlay lifecycle ---------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _overlay == null:
		set_process(false)
		return
	# The room the introduction belongs to is gone (menu, disconnect, replaced scene).
	if _watched_node != null and (not is_instance_valid(_watched_node) or not _watched_node.is_inside_tree()):
		_watched_node = null
		_overlay.dismiss()


func _on_overlay_finished(completed: bool, overlay: CinematicTransition) -> void:
	if overlay == _overlay:
		_overlay = null
		_watched_node = null
		set_process(false)
		intro_finished.emit(_overlay_room, completed)
	overlay.queue_free()


func _discard_overlay() -> void:
	if _overlay == null:
		return
	var overlay := _overlay
	_overlay = null
	if overlay.finished.is_connected(_on_overlay_finished):
		overlay.finished.disconnect(_on_overlay_finished)
	overlay.queue_free()
	_watched_node = null
	set_process(false)


func _on_overlay_cue(cue: StringName) -> void:
	audio_cue_requested.emit(cue, _overlay_timeline, _overlay_room)
	# Play through the game's existing AudioDirector when one is in the room; otherwise stay silent.
	for director in get_tree().get_nodes_in_group(AUDIO_GROUP):
		if director.has_method("has_sound") and director.has_sound(cue):
			director.play_ui(cue)
			return


# --- Helpers -------------------------------------------------------------------------------

func _normalize_timeline(timeline: String) -> String:
	var side := timeline.to_lower() if not timeline.is_empty() else PuzzleManager.get_local_role()
	return "future" if side == "future" else "past"


func _room_node_for(room_id: String) -> Node:
	if GameFlowManager.get_current_room_id() == room_id:
		return GameFlowManager.get_current_room_node()
	return null


func _resource_paths(directory: String) -> PackedStringArray:
	var paths := PackedStringArray()
	var dir := DirAccess.open(directory)
	if dir == null:
		return paths
	for file in dir.get_files():
		var file_name := file.trim_suffix(".remap")  # exported projects list resources as .tres.remap
		if file_name.ends_with(".tres"):
			paths.append(directory.path_join(file_name))
	paths.sort()
	return paths


func _problem(message: String) -> void:
	if log_problems:
		push_warning("CinematicTransitionManager: " + message)
