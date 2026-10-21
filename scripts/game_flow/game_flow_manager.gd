extends Node
## Level transitions for both players (autoload "GameFlowManager").
##
## Owns "which room are we in" and moves both peers to the next one without touching the ENet
## connection, the PuzzleManager session, or any puzzle state. The host (Student, Past) alone decides
## when a transition happens; the guest (Professor, Future) can only say "I am ready to go to X".
##   OFFLINE - solo preview: this instance is its own authority and waits for nobody.
##   HOST    - validates readiness and requests, begins, collects load acknowledgements, commits.
##   CLIENT  - sends readiness, obeys the host's begin / commit / abort.
## Protocol, in order (all reliable RPCs on this autoload, which survives every room change):
##   set_ready (guest) -> ready_state (host) -> begin (host) -> fade + load on both peers ->
##   loaded (guest) -> commit (host) -> fade in on both peers -> finished (guest).
## abort (host) replaces commit when anything fails. Rooms are identified by ID only: the scene to
## load always comes from this peer's own registered RoomDefinition, never from the network.

const RoomDef := preload("res://scripts/game_flow/room_definition.gd")
const OverlayScene := preload("res://scenes/game_flow/transition_overlay.tscn")
const InputManager := preload("res://scripts/input/input_manager.gd")

const PAST := RoomDef.PAST
const FUTURE := RoomDef.FUTURE
## Rooms found here are registered automatically. Test rooms live in a subfolder on purpose.
const ROOM_DIRECTORY := "res://resources/levels"
const SPAWN_GROUP := &"spawn_point"
const DIALOGUE_GROUP := &"dialogue_director"
const MAX_ID_LENGTH := 64

## Someone asked to leave for to_room (first ready player on the host, or its announcement on the guest).
signal transition_requested(from_room: String, to_room: String)
## The "who is ready" state changed. The destination is "" when nobody is ready.
signal readiness_changed(destination: String, past_ready: bool, future_ready: bool)
## A request was refused. message is a player-facing sentence.
signal request_rejected(destination: String, reason: String, message: String)
## The host authorised a transition and this peer began leaving from_room.
signal transition_started(from_room: String, to_room: String)
## 0..1 while loading; 1.0 once the new room is entered.
signal transition_progress_changed(progress: float)
## The old room is about to be removed. Fade its ambience here.
signal room_unloading(room_id: String)
## The black screen is up and the room scene is being loaded.
signal room_loading(room_id: String)
## The new room is in the tree (still hidden and locked). Start its soundscape here.
signal room_changed(room_id: String)
## The transition committed and this peer's fade-in finished; controls are back.
signal transition_completed(room_id: String)
## The transition was cancelled and the previous room restored (or the session was ended safely).
signal transition_failed(reason: String)
signal phase_changed(phase: int)
## Gameplay input is locked (true) or released (false). Rooms that manage their own controls resync on this.
signal input_lock_changed(locked: bool)

enum Phase { IDLE, FADING_OUT, LOADING, WAITING_FOR_PEERS, FADING_IN }
enum Mode { OFFLINE, HOST, CLIENT, LOST }

const MESSAGES := {
	"busy": "A transition is already in progress.",
	"partner_busy": "Your partner is still arriving. Try again in a moment.",
	"unknown_room": "That area is not available yet.",
	"not_adjacent": "There is no way through to that area from here.",
	"puzzle_incomplete": "Something here still needs to be finished before you can move on.",
	"no_partner": "Your partner is not connected.",
	"no_session": "The session is not ready yet.",
	"no_current_room": "This area is not part of the level flow.",
	"scene_missing": "That area could not be found.",
	"not_authority": "Only the Student can start this transition.",
	"blocked": "You cannot leave right now.",
}

## Cut directly between rooms; the cover is only needed while loading and synchronising peers.
var fade_out_seconds: float = 0.0
var fade_in_seconds: float = 0.0
## Host: seconds from "begin" until every peer must have loaded. The guest allows a little longer.
var transition_timeout_seconds: float = 20.0
## Host: how long to wait for the guest to report it left a transition before allowing the next one.
var finish_timeout_seconds: float = 15.0
## Refuse to mark ready while a DialogueDirector is playing a conversation.
var block_during_dialogue: bool = true
## Where an unrecoverable failure ends up, after the session is closed.
var fallback_scene: String = "res://scenes/menu/main_menu.tscn"
var log_problems: bool = OS.is_debug_build()

var overlay: TransitionOverlay

var _rooms: Dictionary = {}   # room_id -> RoomDefinition
var _current_id: String = ""
var _room_node: Node = null
var _blockers: Dictionary = {}  # blocker id -> Callable returning "" or a reason sentence

var _ready_destination: String = ""
var _ready_roles: Dictionary = {PAST: false, FUTURE: false}

var _phase: Phase = Phase.IDLE
var _phase_since_ms: int = 0
var _seq: int = 0            # host: last transition ID handed out
var _highest_tid: int = 0    # highest ID this peer has accepted; anything lower is stale
var _tid: int = 0            # the transition in flight, 0 when idle
var _from_room: String = ""
var _to_room: String = ""
var _target_room: String = ""
var _transition_mode: Mode = Mode.OFFLINE
var _my_role: String = PAST
var _expected_roles: Array = []
var _confirmed: Dictionary = {}
var _deadline_ms: int = 0
var _committed: bool = false
var _swapped: bool = false
var _rolling_back: bool = false
var _failing_reason: String = ""
var _failure_reported: bool = false
var _progress: float = 0.0
var _load_path: String = ""
var _orphan_loads: Array[String] = []
var _settle_frames: int = 0
var _settle_physics: int = 0
var _awaiting_settle: bool = false

var _partner_busy: bool = false
var _partner_tid: int = 0
var _partner_deadline_ms: int = 0

var _input_locked: bool = false
var _locked_bodies: Dictionary = {}  # instance id -> controls_enabled before the lock
var _locked_controllers: Array[int] = []
var _reactor_restart_attempt: int = -1
var _reactor_restart_session: int = 0
var _reactor_guest_finished: int = -1
var _reactor_restart_deadline: int = 0
var _campaign_restart_in_flight := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = OverlayScene.instantiate()
	add_child(overlay)
	overlay.fade_finished.connect(_on_fade_finished)
	NetworkManager.state_changed.connect(_on_network_changed)
	PuzzleManager.session_ended.connect(_on_session_ended)
	load_room_directory()
	InputManager.ensure_initialized(self)


func _exit_tree() -> void:
	# Every threaded request must be collected or the engine reports a leaked resource.
	_discard_pending_load()
	for path in _orphan_loads:
		ResourceLoader.load_threaded_get(path)
	_orphan_loads.clear()


# --- Registry -----------------------------------------------------------------------------

## Make a room known. Returns false (and logs why) for an invalid definition or a duplicate ID.
## Registering the same resource twice is a no-op; a different resource needs replace = true.
func register_room(definition: RoomDef, replace: bool = false) -> bool:
	if definition == null:
		_problem("register_room needs a RoomDefinition.")
		return false
	var problems := definition.validate()
	if not problems.is_empty():
		_problem("Room '%s' was not registered: %s." % [definition.room_id, "; ".join(problems)])
		return false
	var existing: RoomDef = _rooms.get(definition.room_id)
	if existing == definition:
		return true
	if existing != null and not replace:
		_problem("Room ID '%s' is already registered; pass replace = true to swap it." % definition.room_id)
		return false
	if _phase != Phase.IDLE:
		_problem("Rooms cannot be registered during a transition.")
		return false
	_rooms[definition.room_id] = definition
	var missing := definition.missing_scenes()
	if not missing.is_empty():
		_problem("Room '%s' points at missing scenes: %s." % [definition.room_id, ", ".join(missing)])
	return true


## Register every RoomDefinition .tres directly inside a folder. Returns how many were added.
func load_room_directory(directory: String = ROOM_DIRECTORY) -> int:
	var dir := DirAccess.open(directory)
	if dir == null:
		return 0
	var added := 0
	for file in dir.get_files():
		var file_name := file.trim_suffix(".remap")  # exported projects list resources as .tres.remap
		if not file_name.ends_with(".tres"):
			continue
		var resource := ResourceLoader.load(directory.path_join(file_name))
		if resource is RoomDef and register_room(resource):
			added += 1
	return added


func unregister_room(room_id: String) -> bool:
	if _phase != Phase.IDLE or room_id == _current_id:
		return false
	return _rooms.erase(room_id)


func has_room(room_id: String) -> bool:
	return _rooms.has(room_id)


func get_room(room_id: String) -> RoomDef:
	return _rooms.get(room_id)


func get_room_ids() -> PackedStringArray:
	return PackedStringArray(_rooms.keys())


func get_room_display_name(room_id: String) -> String:
	var definition: RoomDef = _rooms.get(room_id)
	if definition == null:
		return ""
	return definition.display_name if not definition.display_name.is_empty() else definition.room_id


# --- Current room -------------------------------------------------------------------------

## "" when the active scene is not a room (menu, loading) or was replaced behind our back.
func get_current_room_id() -> String:
	return _current_id if is_instance_valid(_room_node) and _room_node.is_inside_tree() else ""


func get_current_room() -> RoomDef:
	return _rooms.get(get_current_room_id())


func get_current_room_node() -> Node:
	return _room_node if get_current_room_id() != "" else null


func is_transitioning() -> bool:
	return _phase != Phase.IDLE


func get_phase() -> Phase:
	return _phase


func get_transition_id() -> int:
	return _tid


func is_input_locked() -> bool:
	return _input_locked


## Enter the first room of a session (both peers call this when the game starts). No fade, no
## network traffic; the scene becomes the current scene and the room's entry spawn applies.
func start_room(room_id: String) -> bool:
	if _phase != Phase.IDLE:
		return false
	var definition: RoomDef = _rooms.get(room_id)
	if definition == null:
		_problem("start_room: unknown room '%s'." % room_id)
		return false
	var path := definition.get_scene_path(_local_role())
	var packed: PackedScene = ResourceLoader.load(path, "PackedScene") if ResourceLoader.exists(path) else null
	var instance := packed.instantiate() if packed != null else null
	if instance == null:
		_problem("start_room: '%s' could not be loaded." % path)
		return false
	_clear_readiness()
	_swap_in(room_id, instance)
	room_changed.emit(room_id)
	return true


## Tell the manager that a scene entered outside it (menu, F6) is this room. Idempotent.
func attach_room(room_id: String, node: Node) -> bool:
	if node == _room_node and room_id == _current_id:
		return true
	if not _rooms.has(room_id) or _phase != Phase.IDLE or node == null:
		return false
	_room_node = node
	_current_id = room_id
	_clear_readiness()
	room_changed.emit(room_id)
	return true


## Where a player enters the current room, by the timeline's configured spawn ID.
func get_entry_spawn_id(role: String = "") -> StringName:
	var definition := get_current_room()
	if definition == null:
		return &""
	return definition.get_spawn_id(role if not role.is_empty() else _local_role())


## A Marker3D named spawn_id inside the current room (or scene_root). Prefers markers in the
## "spawn_point" group; any Marker3D with that name works too. Rooms call this from _ready().
func find_spawn_point(spawn_id: StringName, scene_root: Node = null) -> Marker3D:
	var root := scene_root if scene_root != null else (_room_node if is_instance_valid(_room_node) else get_tree().current_scene)
	if root == null or spawn_id == &"":
		return null
	for node in get_tree().get_nodes_in_group(SPAWN_GROUP):
		if node is Marker3D and node.name == spawn_id and root.is_ancestor_of(node):
			return node
	return root.find_child(String(spawn_id), true, false) as Marker3D


# --- Rules --------------------------------------------------------------------------------

## "" when the players could leave for room_id right now, otherwise a reason code.
func get_block_reason(room_id: String) -> String:
	var mode := _mode()
	if mode == Mode.LOST:
		return "no_partner"
	if mode != Mode.OFFLINE and not PuzzleManager.is_session_active():
		return "no_session"
	if _phase != Phase.IDLE:
		return "busy"
	if mode == Mode.HOST and (_partner_busy or _guest_peer() == 0):
		return "partner_busy" if _partner_busy else "no_partner"
	var current := get_current_room()
	if current == null:
		return "no_current_room"
	var target: RoomDef = _rooms.get(room_id)
	if target == null:
		return "unknown_room"
	if not current.get_destinations().has(room_id):
		return "not_adjacent"
	if not get_missing_puzzles(room_id).is_empty():
		return "puzzle_incomplete"
	if not ResourceLoader.exists(target.get_scene_path(_local_role())):
		return "scene_missing"
	return ""


func can_enter_room(room_id: String) -> bool:
	return get_block_reason(room_id).is_empty()


## Required puzzles of the current room that are not solved yet (only its main exit is gated).
func get_missing_puzzles(room_id: String) -> PackedStringArray:
	var missing := PackedStringArray()
	var current := get_current_room()
	if current == null:
		return missing
	for puzzle_id in current.get_required_puzzles(room_id):
		if not PuzzleManager.is_solved(puzzle_id):
			missing.append(puzzle_id)
	return missing


func get_reason_message(reason: String) -> String:
	if reason == "puzzle_incomplete":
		var current := get_current_room()
		if current != null and not current.locked_message.is_empty():
			return current.locked_message
	return MESSAGES.get(reason, "You cannot do that right now.")


## Local rooms add conditions that stop this player from marking ready, such as an open
## terminal. check is called with no arguments and returns "" or a sentence saying why not.
func add_ready_blocker(blocker_id: StringName, check: Callable) -> void:
	_blockers[blocker_id] = check


func remove_ready_blocker(blocker_id: StringName) -> void:
	_blockers.erase(blocker_id)


# --- Readiness ----------------------------------------------------------------------------

## The local player confirms they are ready to go to room_id. When everyone required is ready,
## the host begins the transition by itself. Returns "" when accepted (a guest's request is
## still checked by the host: watch readiness_changed / request_rejected), else a reason code.
func request_transition(room_id: String) -> String:
	var reason := get_block_reason(room_id)
	var message := ""
	if reason.is_empty():
		message = _local_blocker_message()
		if not message.is_empty():
			reason = "blocked"
	if not reason.is_empty():
		_reject(room_id, reason, message)
		return reason
	if _mode() == Mode.CLIENT:
		_rpc_set_ready.rpc_id(1, PuzzleManager.get_session_id(), room_id, true)
		return ""
	reason = _host_set_ready(_local_role(), room_id, true)
	if not reason.is_empty():
		_reject(room_id, reason)
	return reason


## Withdraw the local player's readiness. Safe at any time before the transition begins.
func cancel_transition_request() -> void:
	if _ready_destination.is_empty() or _phase != Phase.IDLE:
		return
	match _mode():
		Mode.CLIENT:
			_rpc_set_ready.rpc_id(1, PuzzleManager.get_session_id(), _ready_destination, false)
		Mode.LOST:
			_clear_readiness()
		_:
			_host_set_ready(_local_role(), _ready_destination, false)


func is_local_ready(destination: String = "") -> bool:
	if _ready_destination.is_empty() or (not destination.is_empty() and destination != _ready_destination):
		return false
	return _ready_roles.get(_local_role(), false) == true


func get_readiness() -> Dictionary:
	return {"destination": _ready_destination, PAST: _ready_roles[PAST], FUTURE: _ready_roles[FUTURE]}


## Host or offline only: start the transition now, skipping the ready step. For narrative
## events and scripted exits. Prerequisites and destination rules still apply.
func begin_transition(room_id: String) -> String:
	if _mode() == Mode.CLIENT:
		_reject(room_id, "not_authority")
		return "not_authority"
	var reason := get_block_reason(room_id)
	if not reason.is_empty():
		_reject(room_id, reason)
		return reason
	_start_authorized(room_id)
	return ""


## Called by each local cinematic only after its final black frame. The host waits
## briefly for the guest, then uses the existing begin/load/ack/commit protocol.
func reactor_cinematic_finished(attempt: int) -> void:
	if get_current_room_id() != "room_03": return
	if _mode() == Mode.CLIENT:
		_rpc_reactor_finished.rpc_id(1, PuzzleManager.get_session_id(), attempt)
		return
	var core := PuzzleManager.get_state("puzzle_03_final_fracture")
	if core.get("stage") != "OVERLOAD" or core.get("attempt") != attempt: return
	if _reactor_restart_attempt == attempt: return
	_reactor_restart_attempt = attempt
	_reactor_restart_session = PuzzleManager.get_session_id()
	_reactor_restart_deadline = Time.get_ticks_msec() + 2500


func _poll_reactor_restart() -> void:
	if _reactor_restart_attempt < 0: return
	if _reactor_restart_session != PuzzleManager.get_session_id() or get_current_room_id() != "room_03":
		_reactor_restart_attempt = -1
		return
	# Never wait on a disconnected peer. A severed session returns to its existing recovery UI.
	if _mode() == Mode.LOST:
		_reactor_restart_attempt = -1
		return
	if _phase != Phase.IDLE: return
	if _mode() == Mode.HOST and _reactor_guest_finished != _reactor_restart_attempt and Time.get_ticks_msec() < _reactor_restart_deadline: return
	_reactor_restart_attempt = -1
	var guest := _guest_peer()
	if guest != 0: _rpc_prepare_campaign_restart.rpc_id(guest, PuzzleManager.get_session_id())
	_prepare_campaign_restart()
	# A new gameplay session invalidates queued actions and resets every rules object,
	# journal, private vote, radio, item and device record. ENet and assigned roles survive.
	PuzzleManager.begin_session()
	_start_authorized("room_01")


func _prepare_campaign_restart() -> void:
	_campaign_restart_in_flight = true
	PuzzleManager.gameplay_suspended = true
	_blockers.clear()
	_clear_readiness()
	CinematicTransitionManager.reset_history()


## Host or offline only: cancel the transition in flight, restoring the previous room.
func abort_transition(reason: String = "cancelled") -> bool:
	if _phase == Phase.IDLE or _committed or _mode() == Mode.CLIENT:
		return false
	_abort(reason)
	return true


# --- Host: readiness and begin ------------------------------------------------------------

func _host_set_ready(role: String, destination: String, is_ready: bool) -> String:
	if _phase != Phase.IDLE:
		return "busy"
	if is_ready:
		var reason := get_block_reason(destination)
		if not reason.is_empty():
			return reason
		if _ready_destination != destination:
			_ready_roles = {PAST: false, FUTURE: false}
			_ready_destination = destination
			transition_requested.emit(get_current_room_id(), destination)
		_ready_roles[role] = true
	else:
		if _ready_destination != destination:
			return ""
		_ready_roles[role] = false
		if not _ready_roles[PAST] and not _ready_roles[FUTURE]:
			_ready_destination = ""
	_publish_readiness()
	if is_ready and _required_ready():
		_start_authorized(destination)
	return ""


func _required_ready() -> bool:
	var current := get_current_room()
	if current == null:
		return false
	if _mode() == Mode.OFFLINE:
		return _ready_roles.get(_local_role(), false) == true
	if not current.require_both_ready:
		return _ready_roles[PAST] or _ready_roles[FUTURE]
	return _ready_roles[PAST] and _ready_roles[FUTURE]


func _start_authorized(destination: String) -> void:
	_seq += 1
	var tid := _seq
	var from := get_current_room_id()
	var mode := _mode()
	_my_role = _local_role()
	_expected_roles = [PAST, FUTURE] if mode == Mode.HOST else [_my_role]
	_confirmed.clear()
	for role in _expected_roles:
		_confirmed[role] = false
	_ready_roles = {PAST: false, FUTURE: false}
	_ready_destination = ""
	readiness_changed.emit("", false, false)
	if mode == Mode.HOST:
		_partner_busy = true
		_partner_tid = tid
		_partner_deadline_ms = Time.get_ticks_msec() + int(finish_timeout_seconds * 1000.0) + int(transition_timeout_seconds * 1000.0)
		_rpc_begin.rpc_id(_guest_peer(), PuzzleManager.get_session_id(), tid, from, destination)
	if mode != Mode.OFFLINE:
		overlay.show_departing()
	_begin_local(tid, from, destination)


func _publish_readiness() -> void:
	readiness_changed.emit(_ready_destination, _ready_roles[PAST], _ready_roles[FUTURE])
	_refresh_readiness_ui()
	var guest := _guest_peer()
	if _mode() == Mode.HOST and guest != 0:
		_rpc_ready_state.rpc_id(guest, PuzzleManager.get_session_id(), _ready_destination, _ready_roles[PAST], _ready_roles[FUTURE])


func _refresh_readiness_ui() -> void:
	var anyone: bool = _ready_roles[PAST] or _ready_roles[FUTURE]
	if _ready_destination.is_empty() or not anyone or _mode() == Mode.OFFLINE or _phase != Phase.IDLE:
		overlay.hide_readiness()
	else:
		overlay.show_readiness(get_room_display_name(_ready_destination), _ready_roles[PAST], _ready_roles[FUTURE])


func _clear_readiness() -> void:
	if _ready_destination.is_empty() and not _ready_roles[PAST] and not _ready_roles[FUTURE]:
		return
	_ready_destination = ""
	_ready_roles = {PAST: false, FUTURE: false}
	readiness_changed.emit("", false, false)
	_refresh_readiness_ui()
	if _mode() == Mode.HOST and _guest_peer() != 0 and _phase == Phase.IDLE:
		_rpc_ready_state.rpc_id(_guest_peer(), PuzzleManager.get_session_id(), "", false, false)


func _reject(destination: String, reason: String, message: String = "") -> void:
	if message.is_empty():
		message = get_reason_message(reason)
	request_rejected.emit(destination, reason, message)
	overlay.show_notice(message)


func _local_blocker_message() -> String:
	if block_during_dialogue:
		for director in get_tree().get_nodes_in_group(DIALOGUE_GROUP):
			if director.has_method("is_dialogue_active") and director.is_dialogue_active():
				return "Finish the conversation first."
	for blocker_id in _blockers:
		var message: Variant = _blockers[blocker_id].call()
		if message is String and not message.is_empty():
			return message
	return ""


# --- Local transition (both peers) --------------------------------------------------------

func _begin_local(tid: int, from: String, destination: String) -> void:
	_tid = tid
	_highest_tid = maxi(_highest_tid, tid)
	_from_room = from
	_to_room = destination
	_target_room = destination
	_transition_mode = _mode()
	_my_role = _local_role()
	_committed = false
	_swapped = false
	_rolling_back = false
	_failing_reason = ""
	_failure_reported = false
	_awaiting_settle = false
	_progress = 0.0
	_deadline_ms = Time.get_ticks_msec() + int(transition_timeout_seconds * 1000.0)
	_set_phase(Phase.FADING_OUT)
	overlay.set_status("LOADING...", "")
	_set_input_locked(true)
	overlay.fade_out(fade_out_seconds)
	_request_load(destination)
	# Last, so a listener that reacts by cancelling or disconnecting finds a complete transition.
	transition_started.emit(from, destination)


func _set_phase(phase: Phase) -> void:
	if phase == _phase:
		return
	_phase = phase
	_phase_since_ms = Time.get_ticks_msec()
	phase_changed.emit(phase)


func _on_fade_finished(covering: bool) -> void:
	if covering and _phase == Phase.FADING_OUT:
		overlay.hide_readiness()
		_set_phase(Phase.LOADING)
		room_loading.emit(_target_room)
	elif not covering and _phase == Phase.FADING_IN:
		_finish(_failing_reason.is_empty())


## Start loading this peer's scene for a room, on a worker thread.
func _request_load(room_id: String) -> void:
	var definition: RoomDef = _rooms.get(room_id)
	if definition == null:
		_load_failed("unknown_room")
		return
	var path := definition.get_scene_path(_my_role)
	if not ResourceLoader.exists(path):
		_load_failed("scene_missing")
		return
	# One worker thread keeps the main thread free. Sub-thread loading leaks loader objects at exit.
	if ResourceLoader.load_threaded_request(path, "PackedScene", false) != OK:
		_load_failed("scene_load_failed")
		return
	_load_path = path


func _poll_load() -> void:
	if _load_path.is_empty():
		return
	var progress: Array = []
	match ResourceLoader.load_threaded_get_status(_load_path, progress):
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not progress.is_empty():
				_set_progress(float(progress[0]) * 0.8)
		ResourceLoader.THREAD_LOAD_LOADED:
			var path := _load_path
			_load_path = ""
			var packed := ResourceLoader.load_threaded_get(path) as PackedScene
			var instance := packed.instantiate() if packed != null else null
			if instance == null:
				_load_failed("scene_instantiate_failed")
			else:
				_enter_room(instance)
		_:
			ResourceLoader.load_threaded_get(_load_path)  # a failed request must still be collected
			_load_path = ""
			_load_failed("scene_load_failed")


## The loaded scene replaces the old room, still hidden behind the black screen and locked.
func _enter_room(instance: Node) -> void:
	_swap_in(_target_room, instance)
	_swapped = not _rolling_back
	_settle_frames = 2
	_settle_physics = 1
	_awaiting_settle = true
	_set_progress(0.9)
	room_changed.emit(_target_room)


func _swap_in(room_id: String, instance: Node) -> void:
	var tree := get_tree()
	var old := tree.current_scene
	if old != null and old != instance:
		if get_current_room_id() != "":
			room_unloading.emit(_current_id)
		_locked_bodies.clear()
		_locked_controllers.clear()
		tree.root.remove_child(old)
		old.queue_free()
	_room_node = instance
	_current_id = room_id
	tree.root.add_child(instance)
	tree.current_scene = instance
	if _input_locked:
		_apply_input_lock()


func _room_settled() -> bool:
	if not is_instance_valid(_room_node):
		return false
	if _room_node.has_method("is_game_flow_ready") and not _room_node.call("is_game_flow_ready"):
		return false
	return true


## The new room is initialised on this peer. The host counts itself; the guest tells the host.
func _local_loaded() -> void:
	_awaiting_settle = false
	if _input_locked:
		_apply_input_lock()  # a character spawned late by the room is held too
	if _rolling_back:
		_enter_fading_in()
		return
	_set_phase(Phase.WAITING_FOR_PEERS)
	if _transition_mode == Mode.CLIENT:
		_rpc_loaded.rpc_id(1, PuzzleManager.get_session_id(), _tid)
	else:
		_confirmed[_my_role] = true
		_try_commit()


func _try_commit() -> void:
	if _phase != Phase.WAITING_FOR_PEERS or _committed:
		return
	for role in _expected_roles:
		if _confirmed.get(role, false) != true:
			return
	if _transition_mode == Mode.HOST:
		var guest := _guest_peer()
		if guest == 0:
			_abort("peer_disconnected")
			return
		_rpc_commit.rpc_id(guest, PuzzleManager.get_session_id(), _tid)
	_committed = true
	_enter_fading_in()


func _enter_fading_in() -> void:
	if _input_locked:
		_apply_input_lock()  # nothing may move until the fade-in has finished
	_set_phase(Phase.FADING_IN)
	_set_progress(1.0)
	overlay.fade_in(fade_in_seconds)


func _finish(success: bool) -> void:
	var finished_tid := _tid
	var finished_mode := _transition_mode
	var reason := _failing_reason
	_tid = 0
	_committed = false
	_swapped = false
	_rolling_back = false
	_failing_reason = ""
	_awaiting_settle = false
	_confirmed.clear()
	_set_phase(Phase.IDLE)
	overlay.clear_status()
	overlay.snap(false)
	_set_input_locked(false)
	if _campaign_restart_in_flight:
		_campaign_restart_in_flight = false
		PuzzleManager.gameplay_suspended = false
	if finished_mode == Mode.CLIENT and _mode() == Mode.CLIENT:
		_rpc_finished.rpc_id(1, PuzzleManager.get_session_id(), finished_tid)
	if success:
		transition_completed.emit(get_current_room_id())
	else:
		transition_failed.emit(reason)


# --- Failure and recovery -----------------------------------------------------------------

## This peer cannot load the target room (or, while rolling back, the room it left).
func _load_failed(reason: String) -> void:
	_problem("Transition %d: could not load '%s' (%s)." % [_tid, _target_room, reason])
	if _rolling_back:
		_fatal("rollback_failed")
	elif _transition_mode == Mode.CLIENT:
		# Only the host can cancel: report and wait for its abort.
		if not _failure_reported:
			_failure_reported = true
			_rpc_load_failed.rpc_id(1, PuzzleManager.get_session_id(), _tid, reason)
	else:
		_abort(reason)


## Host or offline: cancel for everyone, then recover locally.
func _abort(reason: String) -> void:
	if _phase == Phase.IDLE or _committed:
		return
	if _transition_mode == Mode.HOST and _guest_peer() != 0:
		_rpc_abort.rpc_id(_guest_peer(), PuzzleManager.get_session_id(), _tid, reason)
	_recover(reason)


## Stop what is in flight and get back to a playable room. Peers that never left their room
## just fade back in; peers that already entered the new one reload the room they left.
func _recover(reason: String) -> void:
	if _phase == Phase.IDLE or _committed or not _failing_reason.is_empty():
		return
	# A failed fresh-game load cannot restore a destroyed chamber with erased progress.
	if _campaign_restart_in_flight:
		_campaign_restart_in_flight = false
		_fatal(reason)
		return
	_failing_reason = reason
	_discard_pending_load()
	_awaiting_settle = false
	_confirmed.clear()
	overlay.hide_readiness()
	if _swapped:
		_rolling_back = true
		_swapped = false
		_deadline_ms = Time.get_ticks_msec() + int(transition_timeout_seconds * 1000.0)
		_target_room = _from_room
		_set_phase(Phase.LOADING)
		overlay.set_status("LOADING...", "RESTORING PREVIOUS AREA...")
		room_loading.emit(_target_room)
		_request_load(_target_room)
	else:
		_enter_fading_in()


## Nothing can be restored. End the session cleanly and go to the menu instead of a dead room.
func _fatal(reason: String) -> void:
	_problem("Transition %d failed beyond recovery: %s." % [_tid, reason])
	_discard_pending_load()
	_tid = 0
	_committed = false
	_swapped = false
	_rolling_back = false
	_failing_reason = ""
	_awaiting_settle = false
	_confirmed.clear()
	_set_phase(Phase.IDLE)
	overlay.clear_status()
	overlay.snap(false)
	_set_input_locked(false)
	_current_id = ""
	_room_node = null
	transition_failed.emit(reason)
	NetworkManager.leave_game("The level transition failed. Return to the menu to start again.")
	get_tree().change_scene_to_file.call_deferred(fallback_scene)


func _on_network_changed() -> void:
	var mode := _mode()
	if mode == Mode.LOST or mode == Mode.OFFLINE:
		_partner_busy = false
	# state_changed also fires for harmless lobby details; only a different mode ends a transition.
	if _phase != Phase.IDLE and not _committed and mode != _transition_mode:
		_recover_from_connection_loss()
	if mode != Mode.HOST or _guest_peer() == 0:
		_clear_readiness()


func _on_session_ended() -> void:
	_clear_readiness()
	_partner_busy = false
	if _phase != Phase.IDLE and not _committed:
		_recover_from_connection_loss()


## The connection or session changed under a transition. PuzzleManager's session_ended and
## NetworkManager's state_changed both arrive for one disconnect, so both come here.
func _recover_from_connection_loss() -> void:
	if _mode() != _transition_mode:
		_recover("host_disconnected" if _transition_mode == Mode.CLIENT else "peer_disconnected")
	else:
		_recover("session_ended")


# --- Frame loop ---------------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if _awaiting_settle and _settle_physics > 0:
		_settle_physics -= 1


func _process(_delta: float) -> void:
	_poll_orphans()
	_poll_reactor_restart()
	var now := Time.get_ticks_msec()
	if _partner_busy and now > _partner_deadline_ms:
		_partner_busy = false
		_problem("The guest never reported leaving transition %d; allowing new transitions." % _partner_tid)
	if _phase == Phase.IDLE:
		if overlay.is_covering():
			overlay.snap(false)  # a fade must never outlive its transition
		return
	if _phase == Phase.LOADING:
		_poll_load()
		if _awaiting_settle:
			_settle_frames -= 1
			if _settle_frames <= 0 and _settle_physics <= 0 and _room_settled():
				_local_loaded()
	if not _committed and now > _deadline_ms:
		if _rolling_back:
			_fatal("rollback_timeout")
		elif _failing_reason.is_empty():
			if _transition_mode != Mode.CLIENT:
				_abort("timeout")
			elif now > _deadline_ms + 5000:
				_fatal("host_unresponsive")  # the host's own timeout would have aborted long before
	elif _phase == Phase.FADING_IN and now - _phase_since_ms > 10000:
		overlay.snap(false)  # the fade tween should have ended long ago
		_finish(_failing_reason.is_empty())


func _set_progress(progress: float) -> void:
	progress = clampf(progress, 0.0, 1.0)
	if absf(progress - _progress) < 0.005 and progress < 1.0:
		return
	_progress = progress
	overlay.set_progress(progress)
	transition_progress_changed.emit(progress)


# --- Threaded loading housekeeping --------------------------------------------------------

## A request nobody will use still has to be collected, so it is parked until the worker ends.
func _discard_pending_load() -> void:
	if not _load_path.is_empty():
		_orphan_loads.append(_load_path)
		_load_path = ""


func _poll_orphans() -> void:
	var index := _orphan_loads.size() - 1
	while index >= 0:
		var path := _orphan_loads[index]
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			ResourceLoader.load_threaded_get(path)
			_orphan_loads.remove_at(index)
		index -= 1


# --- Input lock ---------------------------------------------------------------------------

## Freeze the local characters and block interaction while a transition runs. Works on whatever is
## in the current room: bodies exposing controls_enabled and nodes named InteractionController.
func _set_input_locked(locked: bool) -> void:
	if locked == _input_locked:
		return
	_input_locked = locked
	if locked:
		if is_instance_valid(_room_node) and _room_node.has_method("game_flow_suspend"):
			_room_node.call("game_flow_suspend")  # let the room close its modals and conversations
		_apply_input_lock()
	else:
		for id in _locked_bodies:
			var body := instance_from_id(id)
			if is_instance_valid(body):
				body.set("controls_enabled", _locked_bodies[id])
		for id in _locked_controllers:
			var controller := instance_from_id(id)
			if is_instance_valid(controller):
				controller.call("set_interaction_blocked", false)
		_locked_bodies.clear()
		_locked_controllers.clear()
	input_lock_changed.emit(locked)


func _apply_input_lock() -> void:
	var scene := _room_node if is_instance_valid(_room_node) else get_tree().current_scene
	if scene == null:
		return
	# Safe to repeat: a body is recorded once (with its value from before the lock) but held every time.
	for body in scene.find_children("*", "CharacterBody3D", true, false):
		if "controls_enabled" not in body:
			continue
		if not _locked_bodies.has(body.get_instance_id()):
			_locked_bodies[body.get_instance_id()] = body.controls_enabled
		if body.controls_enabled:
			body.controls_enabled = false
		body.velocity = Vector3.ZERO
	for controller in scene.find_children("InteractionController", "", true, false):
		if not controller.has_method("set_interaction_blocked"):
			continue
		if not _locked_controllers.has(controller.get_instance_id()):
			_locked_controllers.append(controller.get_instance_id())
		controller.call("set_interaction_blocked", true)


# --- Network boundary ---------------------------------------------------------------------
# Everything below is the only code that touches RPCs.

func _mode() -> Mode:
	if NetworkManager.state == NetworkManager.State.IDLE:
		return Mode.OFFLINE
	if not NetworkManager.in_game or NetworkManager.state != NetworkManager.State.CONNECTED:
		return Mode.LOST
	return Mode.HOST if NetworkManager.role == PAST else Mode.CLIENT


func _local_role() -> String:
	return PuzzleManager.get_local_role()


## The guest's peer ID, or 0 when nobody can be reached. Never RPC without checking this.
func _guest_peer() -> int:
	if _mode() != Mode.HOST:
		return 0
	var guest := NetworkManager.guest_id
	return guest if guest > 1 and multiplayer.get_peers().has(guest) else 0


## True when the current RPC comes from the connected guest, inside the current session.
func _from_guest(session_id: int) -> bool:
	var sender := multiplayer.get_remote_sender_id()
	return _mode() == Mode.HOST and sender > 1 and sender == _guest_peer() and session_id == PuzzleManager.get_session_id() and PuzzleManager.is_session_active()


## True when the current RPC comes from the host, inside the current session.
func _from_host(session_id: int) -> bool:
	return _mode() == Mode.CLIENT and multiplayer.get_remote_sender_id() == 1 and session_id == PuzzleManager.get_session_id() and PuzzleManager.is_session_active()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_reactor_finished(session_id: int, attempt: int) -> void:
	if not _from_guest(session_id) or get_current_room_id() != "room_03": return
	var core := PuzzleManager.get_state("puzzle_03_final_fracture")
	if core.get("stage") == "OVERLOAD" and core.get("attempt") == attempt:
		_reactor_guest_finished = attempt


@rpc("authority", "call_remote", "reliable")
func _rpc_prepare_campaign_restart(session_id: int) -> void:
	if _from_host(session_id): _prepare_campaign_restart()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_ready(session_id: int, destination: String, is_ready: bool) -> void:
	if not _from_guest(session_id) or destination.length() > MAX_ID_LENGTH:
		return
	var sender := multiplayer.get_remote_sender_id()
	var reason := _host_set_ready(FUTURE, destination, is_ready)
	if not reason.is_empty() and _guest_peer() == sender:
		_rpc_request_rejected.rpc_id(sender, session_id, destination, reason)


@rpc("authority", "call_remote", "reliable")
func _rpc_request_rejected(session_id: int, destination: String, reason: String) -> void:
	if _from_host(session_id):
		_reject(destination, reason)


@rpc("authority", "call_remote", "reliable")
func _rpc_ready_state(session_id: int, destination: String, past_ready: bool, future_ready: bool) -> void:
	if not _from_host(session_id) or _phase != Phase.IDLE:
		return
	if not destination.is_empty() and destination != _ready_destination:
		transition_requested.emit(get_current_room_id(), destination)
	_ready_destination = destination
	_ready_roles = {PAST: past_ready, FUTURE: future_ready}
	readiness_changed.emit(destination, past_ready, future_ready)
	_refresh_readiness_ui()


@rpc("authority", "call_remote", "reliable")
func _rpc_begin(session_id: int, tid: int, from_room: String, to_room: String) -> void:
	if not _from_host(session_id) or tid <= _highest_tid:
		return  # not from our host, or a stale / repeated message
	_highest_tid = tid
	if _phase == Phase.FADING_IN and _committed:
		overlay.snap(false)
		_finish(true)  # the previous transition is over; do not make the host wait for it
	var reason := ""
	if _phase != Phase.IDLE:
		reason = "busy"
	elif not _rooms.has(to_room):
		reason = "unknown_room"
	elif from_room != get_current_room_id():
		reason = "room_desync"
	if not reason.is_empty():
		# Never started on this side: tell the host why, and that this peer is already free again.
		_rpc_load_failed.rpc_id(1, session_id, tid, reason)
		_rpc_finished.rpc_id(1, session_id, tid)
		return
	_clear_readiness()
	overlay.show_departing()
	_begin_local(tid, from_room, to_room)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_loaded(session_id: int, tid: int) -> void:
	if not _from_guest(session_id) or tid != _tid or _phase == Phase.IDLE or _committed:
		return
	if _confirmed.get(FUTURE, true) == true:
		return  # duplicate
	_confirmed[FUTURE] = true
	_try_commit()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_load_failed(session_id: int, tid: int, reason: String) -> void:
	if not _from_guest(session_id) or tid != _tid or _phase == Phase.IDLE or _committed:
		return
	_problem("The guest could not enter '%s' (%s)." % [_to_room, reason.left(48)])
	_abort("partner_load_failed")


@rpc("authority", "call_remote", "reliable")
func _rpc_commit(session_id: int, tid: int) -> void:
	if not _from_host(session_id) or tid != _tid or _phase != Phase.WAITING_FOR_PEERS or _committed:
		return
	_committed = true
	_enter_fading_in()


@rpc("authority", "call_remote", "reliable")
func _rpc_abort(session_id: int, tid: int, reason: String) -> void:
	if not _from_host(session_id) or tid != _tid or _phase == Phase.IDLE:
		return
	_recover(reason.left(48))


@rpc("any_peer", "call_remote", "reliable")
func _rpc_finished(session_id: int, tid: int) -> void:
	if _from_guest(session_id) and tid == _partner_tid:
		_partner_busy = false


func _problem(message: String) -> void:
	if log_problems:
		push_warning("[GameFlowManager] " + message)
