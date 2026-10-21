extends Node
## Personal objective tracker for the local player (autoload "ObjectiveManager").
##
## Objectives are ObjectiveDefinition .tres files under DIRECTORY, one list per timeline. The manager
## never decides that something happened: it re-reads confirmed state whenever that state changes
## (PuzzleManager's replicated puzzle state, the player's own journal discoveries, the room the
## players are in) and completes every objective whose conditions now hold. Nothing here writes
## puzzle state, sends a message or owns a timer, so each peer derives its own progress from the
## same authoritative facts and a joining or reconnecting peer simply re-derives it.
##
## Rules this keeps:
##  - A peer tracks and shows only its own timeline. (An offline game has one machine playing both
##    timelines, so both lists are tracked there; the view still follows the active timeline.)
##  - A completed objective is remembered for the whole session, across rooms, and never completes
##    twice. A fresh puzzle session (new campaign) forgets everything.
##  - Work that was already done when the manager looked (a snapshot from the host, a direct room
##    launch, a new scene) is filled in silently; only progress made while playing is announced.
##  - Objectives of a puzzle that restarts an attempt (the reactor overloading) are tracked afresh.

const DIRECTORY := "res://resources/objectives"
const ACTION := &"mission_log"
const TrackerScene := preload("res://scenes/ui/objective_tracker.tscn")
const LogScene := preload("res://scenes/ui/mission_log.tscn")
const ROLES := ["past", "future"]

## An objective was completed by live play on this peer (never for restored progress).
signal objective_completed(role: String, objective_id: String)
## The local player's current objective changed (new id, "" when nothing is active).
signal objective_activated(role: String, objective_id: String)
## Anything the tracker or log shows changed.
signal state_changed
signal log_opened
signal log_closed

var tracker: CanvasLayer
var mission_log: CanvasLayer

var _defs: Dictionary = {}                                  # objective_id -> ObjectiveDefinition
var _by_role: Dictionary = {"past": [], "future": []}       # role -> definitions in play order
var _chapters: Dictionary = {}                              # room_id -> chapter_order
var _completed: Dictionary = {"past": {}, "future": {}}     # role -> {objective_id: completion index}
var _expired: Dictionary = {"past": {}, "future": {}}       # role -> {objective_id: true}
var _active: Dictionary = {"past": "", "future": ""}
var _reached: Dictionary = {}                               # room_id -> true, rooms seen this session
var _attempts: Dictionary = {}                              # puzzle_id -> last attempt number
var _completions: int = 0
var _silent: bool = true
var _evaluate_queued: bool = false
var _reseed_generation: int = 0
var _open: bool = false
var _locked_bodies: Dictionary = {}                         # instance id -> controls_enabled before opening
var _locked_controllers: Array[int] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000  # after every room has recomputed its controls for the frame
	set_process(false)
	_ensure_action()
	load_directory(DIRECTORY)
	tracker = TrackerScene.instantiate()
	add_child(tracker)
	# The log must hear Escape before a room does, and rooms are added to the root after autoloads.
	mission_log = LogScene.instantiate()
	get_tree().root.add_child.call_deferred(mission_log)
	PuzzleManager.puzzle_state_changed.connect(_on_puzzle_changed)
	PuzzleManager.session_started.connect(reset)
	PuzzleManager.session_ended.connect(reset)
	JournalManager.entry_unlocked.connect(_on_entry_unlocked)
	GameFlowManager.room_changed.connect(_on_room_changed)
	GameFlowManager.transition_started.connect(func(_from: String, _to: String) -> void: close_log())
	GameFlowManager.transition_completed.connect(func(_room_id: String) -> void: _queue_evaluate())
	NetworkManager.state_changed.connect(_queue_evaluate)
	reset()


func _exit_tree() -> void:
	if is_instance_valid(mission_log):
		mission_log.queue_free()


# --- Definitions --------------------------------------------------------------------------

## Register every ObjectiveDefinition .tres below a folder. Returns how many were added.
func load_directory(directory: String) -> int:
	var dir := DirAccess.open(directory)
	if dir == null:
		return 0
	var added := 0
	for sub in dir.get_directories():
		added += load_directory(directory.path_join(sub))
	for file in dir.get_files():
		var file_name := file.trim_suffix(".remap")  # exported projects list resources as .tres.remap
		if file_name.ends_with(".tres") and register_objective(ResourceLoader.load(directory.path_join(file_name))):
			added += 1
	return added


## Make an objective known. False for an invalid definition or a duplicate ID (the reason is logged).
func register_objective(resource: Resource) -> bool:
	if not resource is ObjectiveDefinition:
		return false
	var definition: ObjectiveDefinition = resource
	var problems := definition.validate()
	if _defs.has(definition.objective_id) and not definition.objective_id.is_empty():
		problems.append("duplicate objective_id")
	if not problems.is_empty():
		push_warning("[ObjectiveManager] '%s' was not registered: %s." % [definition.objective_id, "; ".join(problems)])
		return false
	_defs[definition.objective_id] = definition
	var list: Array = _by_role[definition.role]
	list.append(definition)
	list.sort_custom(func(a: ObjectiveDefinition, b: ObjectiveDefinition) -> bool:
		if a.chapter_order != b.chapter_order:
			return a.chapter_order < b.chapter_order
		return a.sort_order < b.sort_order)
	_chapters[definition.chapter] = definition.chapter_order
	_queue_evaluate()
	return true


func get_definition(objective_id: String) -> ObjectiveDefinition:
	return _defs.get(objective_id)


## Every definition for a timeline in play order. For tooling and tests; the UI uses the views below.
func get_definitions(role: String = "") -> Array:
	return (_by_role[role if role in ROLES else get_local_role()] as Array).duplicate()


# --- Views for the HUD and the log ---------------------------------------------------------

## The timeline this peer plays: "past" (Student) or "future" (Professor).
func get_local_role() -> String:
	return "future" if PuzzleManager.get_local_role() == "future" else "past"


## The objective to work on now, or null when there is none (no chapter reached, or all done for now).
func get_current(role: String = "") -> ObjectiveDefinition:
	return _defs.get(_active[_role(role)])


func is_completed(objective_id: String, role: String = "") -> bool:
	return _completed[_role(role)].has(objective_id)


## Completed objectives in the order they were finished.
func get_completed(role: String = "") -> Array[ObjectiveDefinition]:
	var done: Dictionary = _completed[_role(role)]
	var ids: Array = done.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return done[a] < done[b])
	var result: Array[ObjectiveDefinition] = []
	for id: String in ids:
		result.append(_defs[id])
	return result


## What lies ahead, already safe to show. Each entry is {kind, chapter, definition?}:
##   "known"   the next step, shown in full
##   "locked"  a later step in the current chapter: only that it exists
##   "chapter" a chapter not reached yet: one placeholder, no name and no count
func get_upcoming(role: String = "") -> Array[Dictionary]:
	var who := _role(role)
	var entries: Array[Dictionary] = []
	var reach := _reach_order()
	var shown_known := false
	for definition: ObjectiveDefinition in _by_role[who]:
		if definition.chapter_order < reach or _completed[who].has(definition.objective_id) or _expired[who].has(definition.objective_id):
			continue
		if definition.objective_id == _active[who]:
			continue
		if definition.chapter_order == reach:
			if not shown_known and not definition.secret:
				entries.append({"kind": "known", "chapter": definition.chapter, "definition": definition})
			else:
				entries.append({"kind": "locked", "chapter": definition.chapter})
			shown_known = true
		elif not _has_chapter_placeholder(entries, definition.chapter):
			entries.append({"kind": "chapter", "chapter": definition.chapter})
	return entries


## "n / m" for a current objective that defines progress, else Vector2i.ZERO.
func get_progress(definition: ObjectiveDefinition, role: String = "") -> Vector2i:
	if definition == null or definition.progress.is_empty():
		return Vector2i.ZERO
	return ObjectiveConditions.count(definition.progress, _context(_role(role)))


## The chapter's name as the players know it (the room's display name).
func get_chapter_name(room_id: String) -> String:
	var name := GameFlowManager.get_room_display_name(room_id)
	return name if not name.is_empty() else room_id


func get_completed_count(role: String = "") -> int:
	return (_completed[_role(role)] as Dictionary).size()


## True when the local player has anything to show: a chapter has been reached.
func has_content() -> bool:
	return _reach_order() > 0


## True while the peer has nothing left to do in the chapter it has reached.
func is_chapter_done(role: String = "") -> bool:
	return has_content() and _active[_role(role)].is_empty()


# --- Evaluation ---------------------------------------------------------------------------

## Forget everything: a new campaign (or the end of one) starts from the first objective.
func reset() -> void:
	close_log()
	_completed = {"past": {}, "future": {}}
	_expired = {"past": {}, "future": {}}
	_active = {"past": "", "future": ""}
	_reached = {}
	_attempts = {}
	_completions = 0
	_silent = true  # whatever the first evaluation finds was already true; do not announce it
	_reseed_generation += 1
	_reseed(_reseed_generation)
	_queue_evaluate()
	state_changed.emit()


## A reset can happen while leaving a room (a chapter restart changes scene right after it) or while
## staying in one (a peer receiving the host's snapshot). Wait for any scene change, then take the room
## the players are really in as reached.
func _reseed(generation: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if generation != _reseed_generation:
		return
	_seed_current_room()
	_silent = true
	_queue_evaluate()


func _seed_current_room() -> void:
	var room_id := GameFlowManager.get_current_room_id()
	if _chapters.has(room_id):
		_reached[room_id] = true


func _queue_evaluate() -> void:
	if _evaluate_queued:
		return
	_evaluate_queued = true
	_evaluate.call_deferred()


func _on_puzzle_changed(_puzzle_id: String, _state: Dictionary, _revision: int) -> void:
	_queue_evaluate()


func _on_entry_unlocked(_entry: JournalEntry) -> void:
	_queue_evaluate()


func _on_room_changed(room_id: String) -> void:
	if _chapters.has(room_id):
		_reached[room_id] = true
	_queue_evaluate()


func _tracked_roles() -> Array:
	# Online, a peer only ever knows its own timeline. Offline, one machine plays both.
	if NetworkManager.state == NetworkManager.State.IDLE:
		return ROLES
	return [get_local_role()]


## The timeline a view call is about. A peer can only be told about a timeline it tracks, so asking
## for the other player's objectives online answers with its own: nothing can leak by accident.
func _role(role: String) -> String:
	return role if role in _tracked_roles() else get_local_role()


func _context(role: String) -> ObjectiveConditions.Context:
	var context := ObjectiveConditions.Context.new()
	context.role = role
	context.state_of = func(puzzle_id: String) -> Dictionary: return PuzzleManager.get_state(puzzle_id)
	context.solved_of = func(puzzle_id: String) -> bool: return PuzzleManager.is_solved(puzzle_id)
	context.journal_has = func(entry_id: String, who: String) -> bool: return JournalManager.is_unlocked(entry_id, who)
	context.rooms = _reached
	context.rooms = ObjectiveConditions.derive_rooms(_reached, context)
	return context


func _evaluate() -> void:
	_evaluate_queued = false
	var silent := _silent
	_silent = false
	var local := get_local_role()
	var changed := false
	var finished: Array[Array] = []
	var restarted := false
	var previous_active: String = _active[local]
	for role: String in _tracked_roles():
		var context := _context(role)
		# A room that is provably reached stays reached, even if the scene that proved it is gone.
		for room_id: String in context.rooms:
			_reached[room_id] = true
		if _forget_restarted_attempts(role, context):
			restarted = true
			changed = true
		for definition: ObjectiveDefinition in _by_role[role]:
			var id := definition.objective_id
			if _completed[role].has(id) or _expired[role].has(id) or not context.rooms.has(definition.chapter):
				continue
			if ObjectiveConditions.all_hold(definition.conditions, context):
				_completions += 1
				_completed[role][id] = _completions
				finished.append([role, id])
				changed = true
			elif ObjectiveConditions.any_holds(definition.expires, context):
				_expired[role][id] = true
				changed = true
		var active := _pick_active(role)
		if active != _active[role]:
			_active[role] = active
			changed = true
	if changed:
		state_changed.emit()
	# A restarted attempt re-derives what the players already knew (pages they had read); that is not news.
	if not silent and not restarted:
		for done: Array in finished:
			if done[0] == local:
				objective_completed.emit(done[0], done[1])
	if _active[local] != previous_active:
		objective_activated.emit(local, _active[local])


## The first unfinished objective of the furthest chapter reached. Unfinished work in an earlier
## chapter is left behind, as when a room is launched directly without playing the ones before it.
func _pick_active(role: String) -> String:
	var reach := _reach_order()
	for definition: ObjectiveDefinition in _by_role[role]:
		if definition.chapter_order == reach and not _completed[role].has(definition.objective_id) and not _expired[role].has(definition.objective_id):
			return definition.objective_id
	return ""


func _reach_order() -> int:
	var order := 0
	for room_id: String in _reached:
		order = maxi(order, int(_chapters.get(room_id, 0)))
	return order


func _has_chapter_placeholder(entries: Array[Dictionary], room_id: String) -> bool:
	for entry in entries:
		if entry.kind == "chapter" and entry.chapter == room_id:
			return true
	return false


## When a puzzle starts a new attempt, objectives tied to it start over (and may be announced again).
func _forget_restarted_attempts(role: String, context: ObjectiveConditions.Context) -> bool:
	var forgotten := false
	for definition: ObjectiveDefinition in _by_role[role]:
		if definition.attempt_puzzle.is_empty():
			continue
		var state: Dictionary = context.state_of.call(definition.attempt_puzzle)
		if not state.has("attempt"):
			continue
		var key := "%s/%s" % [role, definition.attempt_puzzle]
		var attempt := int(state.attempt)
		if _attempts.get(key, attempt) != attempt:
			forgotten = _completed[role].erase(definition.objective_id) or forgotten
			forgotten = _expired[role].erase(definition.objective_id) or forgotten
	# Remember the attempts only after every objective of the role has been checked against them.
	for definition: ObjectiveDefinition in _by_role[role]:
		var state: Dictionary = context.state_of.call(definition.attempt_puzzle) if not definition.attempt_puzzle.is_empty() else {}
		if state.has("attempt"):
			_attempts["%s/%s" % [role, definition.attempt_puzzle]] = int(state.attempt)
	return forgotten


# --- Mission Log: opening, closing and the gameplay lock ----------------------------------

func is_log_open() -> bool:
	return _open


## False in menus, during transitions and cinematics, and while a dialogue, terminal, device,
## journal or pause screen already owns the player's attention.
func can_open_log() -> bool:
	if not has_content() or not PuzzleManager.is_session_active():
		return false
	var room := GameFlowManager.get_current_room_node()
	if not is_instance_valid(room) or GameFlowManager.is_transitioning() or GameFlowManager.is_input_locked():
		return false
	if JournalManager.is_open() or CinematicTransitionManager.is_playing():
		return false
	if room.has_method("is_gameplay_paused") and room.is_gameplay_paused():
		return false
	var gameplay: Variant = room.get("gameplay")
	if gameplay != null and gameplay.configured and (gameplay.has_modal() or gameplay.director.is_dialogue_active()):
		return false
	var player: Variant = room.get("player")
	return not (player != null and player.has_method("is_action_active") and player.is_action_active())


func open_log() -> bool:
	if _open or not can_open_log():
		return false
	_open = true
	_lock_gameplay()
	set_process(true)
	mission_log.open(get_local_role())
	log_opened.emit()
	state_changed.emit()
	return true


func close_log() -> void:
	if not _open:
		return
	_open = false
	set_process(false)
	mission_log.close()
	_unlock_gameplay()
	log_closed.emit()
	state_changed.emit()


func toggle_log() -> void:
	if _open:
		close_log()
	else:
		open_log()


func _ensure_action() -> void:
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)
	var has_key := false
	var has_pad := false
	for event in InputMap.action_get_events(ACTION):
		has_key = has_key or event is InputEventKey
		has_pad = has_pad or event is InputEventJoypadButton
	if not has_key:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_M
		InputMap.action_add_event(ACTION, key)
	if not has_pad:
		# View / Create, then the DualSense touchpad. Neither is used by any other action.
		for button: JoyButton in [JOY_BUTTON_BACK, JOY_BUTTON_TOUCHPAD]:
			var pad := InputEventJoypadButton.new()
			pad.button_index = button
			InputMap.action_add_event(ACTION, pad)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION) and not event.is_echo():
		toggle_log()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# Rooms recompute their own controls every frame; hold the lock until the log closes.
	if _open:
		_hold_lock()


func _scene_root() -> Node:
	var room := GameFlowManager.get_current_room_node()
	return room if is_instance_valid(room) else get_tree().current_scene


func _lock_gameplay() -> void:
	_hold_lock()
	_sync_room()


## Freeze the local characters and block interaction, remembering what was there before.
func _hold_lock() -> void:
	var scene := _scene_root()
	if scene == null:
		return
	for body in scene.find_children("*", "CharacterBody3D", true, false):
		if "controls_enabled" not in body:
			continue
		if not _locked_bodies.has(body.get_instance_id()):
			_locked_bodies[body.get_instance_id()] = body.controls_enabled
		body.controls_enabled = false
		body.velocity = Vector3.ZERO
	for controller in scene.find_children("InteractionController", "", true, false):
		if not controller.has_method("set_interaction_blocked"):
			continue
		if not _locked_controllers.has(controller.get_instance_id()):
			_locked_controllers.append(controller.get_instance_id())
		controller.call("set_interaction_blocked", true)


func _unlock_gameplay() -> void:
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
	_sync_room()


## Let a room that manages its own controls recompute them now that the log's state changed.
func _sync_room() -> void:
	var scene := _scene_root()
	var gameplay: Variant = scene.get("gameplay") if scene != null else null
	if gameplay != null and gameplay.has_method("sync_controls"):
		gameplay.sync_controls()
