extends Node
## Session-long journal (autoload "JournalManager"): the Student's notebook and the Professor's
## DataPad share this one backend. Each timeline owns a separate set of unlocked entries and nothing
## is sent over the network - a discovery is local progress, and players must tell each other.
##
## Entries are JournalEntry .tres files under ENTRY_DIRECTORY (scanned recursively). To add one,
## drop in a resource and trigger it with a JournalUnlock node, unlock_on_puzzle, or unlock_entry().
## Progress lives in this autoload, so it survives room changes, and is cleared when the puzzle
## session starts or ends (a new game).

const ENTRY_DIRECTORY := "res://resources/journal"
const ACTION := &"journal"
const UIScene := preload("res://scenes/journal/journal_ui.tscn")

## A page was newly added to the local player's journal.
signal entry_unlocked(entry: JournalEntry)
signal journal_opened
signal journal_closed
## Something visible changed (unlock, reset, entry read). The HUD hint refreshes on this.
signal state_changed

var _entries: Dictionary = {}                     # entry_id -> JournalEntry
var _unlocked: Dictionary = {"past": [], "future": []}  # role -> ordered entry IDs
var _seen: Dictionary = {"past": {}, "future": {}}
var _ui: JournalUI
var _open: bool = false
var _locked_bodies: Dictionary = {}               # instance id -> controls_enabled before opening
var _locked_controllers: Array[int] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_action()
	load_directory(ENTRY_DIRECTORY)
	_ui = UIScene.instantiate()
	add_child(_ui)
	entry_unlocked.connect(_ui.show_toast)
	state_changed.connect(_ui.refresh_hint)
	PuzzleManager.session_started.connect(reset)
	PuzzleManager.session_ended.connect(reset)
	PuzzleManager.puzzle_completed.connect(_on_puzzle_completed)
	GameFlowManager.transition_started.connect(func(_from: String, _to: String) -> void: close_journal())


# --- Entries ------------------------------------------------------------------------------

## Register every JournalEntry .tres below a folder. Returns how many were added.
func load_directory(directory: String) -> int:
	var dir := DirAccess.open(directory)
	if dir == null:
		return 0
	var added := 0
	for sub in dir.get_directories():
		added += load_directory(directory.path_join(sub))
	for file in dir.get_files():
		var file_name := file.trim_suffix(".remap")  # exported projects list resources as .tres.remap
		if file_name.ends_with(".tres") and register_entry(ResourceLoader.load(directory.path_join(file_name))):
			added += 1
	return added


## Make an entry known (code-created entries work too). False for an invalid or duplicate ID.
func register_entry(entry: Resource) -> bool:
	if not entry is JournalEntry or entry.entry_id.is_empty() or _entries.has(entry.entry_id):
		return false
	_entries[entry.entry_id] = entry
	return true


func get_entry(entry_id: String) -> JournalEntry:
	return _entries.get(entry_id)


## The timeline this peer plays: "past" or "future".
func get_local_role() -> String:
	return "future" if PuzzleManager.get_local_role() == "future" else "past"


# --- Progress -----------------------------------------------------------------------------

## Add an entry to the local player's journal. True only when it was newly added; unknown IDs,
## duplicates and entries that belong to the other timeline do nothing.
func unlock_entry(entry_id: String) -> bool:
	var entry := get_entry(entry_id)
	var role := get_local_role()
	if entry == null or not entry.allows_role(role) or is_unlocked(entry_id):
		return false
	_unlocked[role].append(entry_id)
	entry_unlocked.emit(entry)
	state_changed.emit()
	return true


func is_unlocked(entry_id: String, role: String = "") -> bool:
	return _unlocked[role if role in _unlocked else get_local_role()].has(entry_id)


## Unlocked entries for a role (default: the local one), ordered by category, sort_order, title.
func get_unlocked_entries(role: String = "") -> Array[JournalEntry]:
	var result: Array[JournalEntry] = []
	for id in _unlocked[role if role in _unlocked else get_local_role()]:
		result.append(_entries[id])
	result.sort_custom(func(a: JournalEntry, b: JournalEntry) -> bool:
		if a.category != b.category:
			return a.category < b.category
		if a.sort_order != b.sort_order:
			return a.sort_order < b.sort_order
		return a.title < b.title)
	return result


func is_new(entry_id: String) -> bool:
	return is_unlocked(entry_id) and not _seen[get_local_role()].has(entry_id)


func get_new_count() -> int:
	var count := 0
	for id in _unlocked[get_local_role()]:
		if not _seen[get_local_role()].has(id):
			count += 1
	return count


func mark_seen(entry_id: String) -> void:
	if is_new(entry_id):
		_seen[get_local_role()][entry_id] = true
		state_changed.emit()


## Forget all discoveries (a new game session).
func reset() -> void:
	close_journal()
	_unlocked = {"past": [], "future": []}
	_seen = {"past": {}, "future": {}}
	state_changed.emit()


func _on_puzzle_completed(puzzle_id: String) -> void:
	for entry: JournalEntry in _entries.values():
		if entry.unlock_on_puzzle == puzzle_id:
			unlock_entry(entry.entry_id)


# --- Opening ------------------------------------------------------------------------------

func is_open() -> bool:
	return _open


## False in menus, during transitions, dialogue, other modals (terminal, document, pause) or actions.
func can_open() -> bool:
	var room := GameFlowManager.get_current_room_node()
	if not is_instance_valid(room) or GameFlowManager.is_transitioning() or GameFlowManager.is_input_locked():
		return false
	if room.has_method("is_gameplay_paused") and room.is_gameplay_paused():
		return false
	var gameplay: Variant = room.get("gameplay")
	if gameplay != null and gameplay.configured and (gameplay.has_modal() or gameplay.director.is_dialogue_active()):
		return false
	var player: Variant = room.get("player")
	return not (player != null and player.has_method("is_action_active") and player.is_action_active())


func open_journal() -> bool:
	if _open or not can_open():
		return false
	_open = true
	_lock_gameplay()
	_ui.open(get_local_role())
	journal_opened.emit()
	state_changed.emit()
	return true


func close_journal() -> void:
	if not _open:
		return
	_open = false
	_ui.close()
	_unlock_gameplay()
	journal_closed.emit()
	state_changed.emit()


func toggle_journal() -> void:
	if _open:
		close_journal()
	else:
		open_journal()


func _ensure_action() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	InputMap.action_add_event(ACTION, key)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION) and not event.is_echo():
		toggle_journal()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# Rooms ignore Escape while has_modal() is true, so the journal closes first.
	if _open and event.is_action_pressed(&"ui_cancel"):
		close_journal()
		get_viewport().set_input_as_handled()


# --- Gameplay lock ------------------------------------------------------------------------
# Same approach as the level-flow lock: hold the local bodies and interaction controllers, and put
# back exactly what was there. Room 01 also reports the journal through gameplay.has_modal().

func _scene_root() -> Node:
	var room := GameFlowManager.get_current_room_node()
	return room if is_instance_valid(room) else get_tree().current_scene


func _lock_gameplay() -> void:
	var scene := _scene_root()
	if scene == null:
		return
	for body in scene.find_children("*", "CharacterBody3D", true, false):
		if "controls_enabled" in body:
			_locked_bodies[body.get_instance_id()] = body.controls_enabled
			body.controls_enabled = false
			body.velocity = Vector3.ZERO
	for controller in scene.find_children("InteractionController", "", true, false):
		if controller.has_method("set_interaction_blocked"):
			_locked_controllers.append(controller.get_instance_id())
			controller.call("set_interaction_blocked", true)
	_sync_room()


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


## Let a room that manages its own controls recompute them now that is_open() changed.
func _sync_room() -> void:
	var gameplay: Variant = _scene_root().get("gameplay") if _scene_root() != null else null
	if gameplay != null and gameplay.has_method("sync_controls"):
		gameplay.sync_controls()
