extends Node
## Host-authoritative puzzle coordinator (autoload "PuzzleManager").
##
## Holds the canonical state of every registered puzzle and the only networking code for them.
## Puzzle rules live in PuzzleBase implementations; scenes react to the signals below and never
## write state themselves. One code path serves three modes:
##   OFFLINE - no network session; this instance is its own authority (solo preview, split-screen).
##   HOST    - the Past player: validates and applies every action, then publishes it to the guest.
##   CLIENT  - the Future player: sends requests, applies only what the host confirms.

const PuzzleBase := preload("res://scripts/puzzles/puzzle_base.gd")
const Status := PuzzleBase.Status
const ROLES := [PuzzleBase.PAST, PuzzleBase.FUTURE]

## A confirmed change, on every peer. State is a copy; editing it changes nothing.
signal puzzle_state_changed(puzzle_id: String, state: Dictionary, revision: int)
## Fires once each time a puzzle goes from unsolved to solved through an action.
signal puzzle_completed(puzzle_id: String)
## A puzzle (or all of them) went back to its initial state. Follows puzzle_state_changed.
signal puzzle_reset(puzzle_id: String)
## An action was refused. On the host this covers local and remote requests; on a client, its own.
signal action_rejected(puzzle_id: String, action: String, reason: String, actor_role: String)
signal session_started
signal session_ended

enum Mode { OFFLINE, HOST, CLIENT }
## Why a record changed; decides which extra signals fire.
enum Cause { ACTION, RESET, INITIAL }

## Role used for local actions while no network session exists (solo preview, split-screen).
var offline_role: String = PuzzleBase.PAST
## Warn about refused actions. Rejections are normal gameplay; keep the log quiet in release builds.
var log_rejections: bool = OS.is_debug_build()

var _logic: Dictionary = {}    # puzzle_id -> PuzzleBase; survives scene changes
var _records: Dictionary = {}  # puzzle_id -> Record; the canonical (or replicated) state
var _mode: Mode = Mode.OFFLINE
var _session_id: int = 0
var _session_active: bool = false
var _revision: int = 0
var _was_in_game: bool = false
var _sync_requested: bool = false


class Record:
	var state: Dictionary = {}
	var solved: bool = false
	var revision: int = 0

	func to_dict() -> Dictionary:
		return {"state": state.duplicate(true), "solved": solved, "revision": revision}

	static func from_dict(data: Dictionary) -> Record:
		var record := Record.new()
		var state: Variant = data.get("state")
		if state is Dictionary:
			record.state = state.duplicate(true)
		record.solved = data.get("solved", false) == true
		record.revision = int(data.get("revision", 0))
		return record


func _ready() -> void:
	NetworkManager.state_changed.connect(_on_network_changed)
	NetworkManager.game_started.connect(_on_game_started)
	_on_network_changed()


# --- Registration -------------------------------------------------------------------------

## Attach rules to an ID. Safe to call from a room's _ready(); registering the same instance
## twice is a no-op, and a different instance needs replace = true. State is kept while a puzzle
## is unregistered, so progress survives room unloads.
func register_puzzle(puzzle_id: String, logic: PuzzleBase, replace: bool = false) -> Error:
	if puzzle_id.is_empty() or logic == null:
		_log("register_puzzle needs a non-empty ID and a logic object.")
		return ERR_INVALID_PARAMETER
	var existing: PuzzleBase = _logic.get(puzzle_id)
	if existing == logic:
		return OK
	if existing != null and not replace:
		_log("Puzzle '%s' is already registered; pass replace = true to swap its logic." % puzzle_id)
		return ERR_ALREADY_EXISTS
	if not logic.puzzle_id.is_empty():
		_log("That logic object is already registered as '%s'; create one instance per puzzle." % logic.puzzle_id)
		return ERR_ALREADY_IN_USE
	if existing != null:
		existing.puzzle_id = ""
	logic.puzzle_id = puzzle_id
	_logic[puzzle_id] = logic
	if _session_active and _mode != Mode.CLIENT and not _records.has(puzzle_id):
		# Room loaded after the session began: create its state and tell the guest.
		_commit_record(puzzle_id, logic, _initial_state(logic), Cause.INITIAL)
	return OK


## Detach the rules, keep the state. Actions for the puzzle are refused until it is registered again.
func unregister_puzzle(puzzle_id: String) -> bool:
	var logic: PuzzleBase = _logic.get(puzzle_id)
	if logic == null:
		return false
	logic.puzzle_id = ""
	_logic.erase(puzzle_id)
	return true


func is_registered(puzzle_id: String) -> bool:
	return _logic.has(puzzle_id)


func get_puzzle_ids() -> PackedStringArray:
	return PackedStringArray(_logic.keys())


# --- Queries ------------------------------------------------------------------------------

func has_state(puzzle_id: String) -> bool:
	return _records.has(puzzle_id)


## A private copy of the confirmed state; {} when the puzzle has none.
func get_state(puzzle_id: String) -> Dictionary:
	var record: Record = _records.get(puzzle_id)
	return record.state.duplicate(true) if record != null else {}


func is_solved(puzzle_id: String) -> bool:
	var record: Record = _records.get(puzzle_id)
	return record != null and record.solved


## Revision of the puzzle's last confirmed change (0 until it changes).
func get_revision(puzzle_id: String) -> int:
	var record: Record = _records.get(puzzle_id)
	return record.revision if record != null else 0


## Highest revision seen in this session, across all puzzles.
func get_latest_revision() -> int:
	return _revision


func get_session_id() -> int:
	return _session_id


## False while a host waits in the lobby or a client waits for the host's first snapshot.
func is_session_active() -> bool:
	return _session_active


## True when this instance validates actions itself (host or offline), false for a client.
func is_authority() -> bool:
	return _mode != Mode.CLIENT


## The timeline this peer plays. Use it to choose Past or Future visuals.
func get_local_role() -> String:
	return offline_role if _mode == Mode.OFFLINE else NetworkManager.role


# --- Actions ------------------------------------------------------------------------------

## Ask for an action. Returns a result dictionary: {status, puzzle_id, action, reason?, message?, revision?}.
## status is Status.REJECTED, NO_CHANGE, CHANGED, COMPLETED, or PENDING (a client's request is on its way
## to the host; watch puzzle_state_changed / action_rejected for the outcome).
## actor_role matters only offline, where the caller is trusted to say which local player acts
## (split-screen); in a network session the assigned role is always used.
func submit_action(puzzle_id: String, action: String, payload: Dictionary = {}, actor_role: String = "") -> Dictionary:
	if _mode == Mode.CLIENT:
		return _request_from_host(puzzle_id, action, payload)
	return _handle_request(puzzle_id, action, payload, _local_role(actor_role))


## Return one puzzle to its initial state. Host/offline only. Returns false if it cannot.
func reset_puzzle(puzzle_id: String) -> bool:
	var logic: PuzzleBase = _logic.get(puzzle_id)
	if not _can_administer() or logic == null:
		return false
	_commit_record(puzzle_id, logic, _initial_state(logic), Cause.RESET)
	return true


## Return every registered puzzle to its initial state under one revision, and drop state of
## puzzles that are not registered. Host/offline only.
func reset_all() -> bool:
	if not _can_administer():
		return false
	_revision += 1
	_rebuild_records(_revision)
	_push_snapshot(Cause.RESET)
	_announce_all(Cause.RESET)
	return true


## Start a fresh session: new session ID, every puzzle back to its initial state. Called for you when
## a LAN game starts; call it yourself when a solo or split-screen run begins. Host/offline only.
func begin_session() -> void:
	if _mode == Mode.CLIENT:
		_log("Only the host or an offline game can begin a session.")
		return
	_session_id = _new_session_id()
	_session_active = true
	_revision = 0
	_rebuild_records(0)
	_push_snapshot(Cause.INITIAL)
	session_started.emit()
	_announce_all(Cause.INITIAL)


## Client only: ask the host for the full state. Used automatically if an update arrives from an unknown session.
func request_sync() -> void:
	if _mode == Mode.CLIENT and _connected_to_host():
		_rpc_request_snapshot.rpc_id(1)


# --- Session lifecycle --------------------------------------------------------------------

func _on_network_changed() -> void:
	var mode := _compute_mode()
	var in_game := NetworkManager.in_game
	# A different role, or a game that just stopped, ends whatever session was running.
	if mode != _mode or (_was_in_game and not in_game):
		_end_session()
		_mode = mode
	_was_in_game = in_game
	if _mode == Mode.OFFLINE and not _session_active:
		begin_session()


func _on_game_started() -> void:
	_on_network_changed()
	# The client does nothing here: the host's snapshot is what starts its session.
	if _mode == Mode.HOST:
		begin_session()


func _compute_mode() -> Mode:
	if NetworkManager.state == NetworkManager.State.IDLE:
		return Mode.OFFLINE
	return Mode.HOST if NetworkManager.role == PuzzleBase.PAST else Mode.CLIENT


func _end_session() -> void:
	if not _session_active:
		return
	_session_active = false
	_session_id = 0
	_revision = 0
	_sync_requested = false
	_records.clear()
	session_ended.emit()


func _new_session_id() -> int:
	var id := randi_range(1, 0x7fffffff)
	while id == _session_id:
		id = randi_range(1, 0x7fffffff)
	return id


# --- Authoritative path (host and offline) ------------------------------------------------

func _local_role(requested: String) -> String:
	if _mode == Mode.OFFLINE:
		return requested if not requested.is_empty() else offline_role
	if not requested.is_empty() and requested != NetworkManager.role:
		_log("Ignored requested role '%s': this session always acts as '%s'." % [requested, NetworkManager.role])
	return NetworkManager.role


func _can_administer() -> bool:
	if _mode == Mode.CLIENT:
		_log("Only the host or an offline game can reset puzzles.")
		return false
	return _session_active


func _handle_request(puzzle_id: String, action: String, payload: Variant, role: String) -> Dictionary:
	var result := _run_action(puzzle_id, action, payload, role)
	if result.status == Status.REJECTED:
		_log("Rejected %s.%s from %s: %s %s" % [puzzle_id, action, role, result.reason, result.message])
		action_rejected.emit(puzzle_id, action, result.reason, role)
	return result


## The single validation-and-execution path for local and remote actions.
func _run_action(puzzle_id: String, action: String, payload: Variant, role: String) -> Dictionary:
	if not _session_active:
		return _rejected(puzzle_id, action, "no_session", "no game session is running")
	if typeof(payload) != TYPE_DICTIONARY:
		return _rejected(puzzle_id, action, "invalid_payload", "payload must be a Dictionary")
	if not role in ROLES:
		return _rejected(puzzle_id, action, "invalid_role", "'%s' is not a timeline role" % role)
	var logic: PuzzleBase = _logic.get(puzzle_id)
	if logic == null:
		return _rejected(puzzle_id, action, "unknown_puzzle")
	for prerequisite in logic.get_prerequisites():
		if not is_solved(prerequisite):
			return _rejected(puzzle_id, action, "prerequisite_not_met", prerequisite)
	if not _records.has(puzzle_id):
		_commit_record(puzzle_id, logic, _initial_state(logic), Cause.INITIAL)
	var record: Record = _records[puzzle_id]
	# Puzzles get copies, so neither a buggy puzzle nor a caller can alias canonical state.
	var reason: Variant = logic.validate_action(action, payload.duplicate(true), role, record.state.duplicate(true))
	if typeof(reason) != TYPE_STRING:
		return _rejected(puzzle_id, action, "invalid_result", "validate_action must return a String")
	if not reason.is_empty():
		return _rejected(puzzle_id, action, reason)
	var outcome: Variant = logic.apply_action(action, payload.duplicate(true), role, record.state.duplicate(true))
	if typeof(outcome) != TYPE_DICTIONARY:
		return _rejected(puzzle_id, action, "invalid_result", "apply_action must return reject(), no_change() or change()")
	match outcome.get("status", Status.REJECTED):
		Status.REJECTED:
			return _rejected(puzzle_id, action, str(outcome.get("reason", "rejected")), str(outcome.get("message", "")))
		Status.NO_CHANGE:
			return _result(Status.NO_CHANGE, puzzle_id, action, {"message": str(outcome.get("message", ""))})
		Status.CHANGED:
			var new_state: Variant = outcome.get("state")
			if typeof(new_state) != TYPE_DICTIONARY:
				return _rejected(puzzle_id, action, "invalid_result", "change() needs a state Dictionary")
			if new_state == record.state:
				return _result(Status.NO_CHANGE, puzzle_id, action)
			var completed := _commit_record(puzzle_id, logic, new_state, Cause.ACTION)
			return _result(Status.COMPLETED if completed else Status.CHANGED, puzzle_id, action, {"revision": _records[puzzle_id].revision})
	return _rejected(puzzle_id, action, "invalid_result", "unknown result status")


## Store, publish, then announce, so a signal handler that submits another action cannot
## reach the guest ahead of this change. Returns true if this change solved the puzzle.
func _commit_record(puzzle_id: String, logic: PuzzleBase, state: Dictionary, cause: int) -> bool:
	var solved := logic.is_solved(state.duplicate(true)) == true
	_revision += 1
	var was_solved := _store(puzzle_id, state, solved, _revision)
	_publish_update(puzzle_id, cause)
	_announce(puzzle_id, cause, was_solved)
	return solved and not was_solved


func _rebuild_records(revision: int) -> void:
	_records.clear()
	for puzzle_id in _logic:
		var logic: PuzzleBase = _logic[puzzle_id]
		var state := _initial_state(logic)
		_store(puzzle_id, state, logic.is_solved(state.duplicate(true)) == true, revision)


func _initial_state(logic: PuzzleBase) -> Dictionary:
	var state: Variant = logic.get_initial_state()
	if state is Dictionary:
		return state.duplicate(true)
	_log("%s.get_initial_state() must return a Dictionary." % logic.puzzle_id)
	return {}


func _rejected(puzzle_id: String, action: String, reason: String, message: String = "") -> Dictionary:
	return _result(Status.REJECTED, puzzle_id, action, {"reason": reason, "message": message})


func _result(status: int, puzzle_id: String, action: String, extra: Dictionary = {}) -> Dictionary:
	var result := {"status": status, "puzzle_id": puzzle_id, "action": action}
	result.merge(extra)
	return result


# --- Shared storage and signals -----------------------------------------------------------

## Write one puzzle's record. Returns whether it was solved before.
func _store(puzzle_id: String, state: Dictionary, solved: bool, revision: int) -> bool:
	var record: Record = _records.get(puzzle_id)
	var was_solved := record != null and record.solved
	if record == null:
		record = Record.new()
		_records[puzzle_id] = record
	record.state = state.duplicate(true)
	record.solved = solved
	record.revision = revision
	_revision = maxi(_revision, revision)
	return was_solved


func _announce(puzzle_id: String, cause: int, was_solved: bool) -> void:
	var record: Record = _records.get(puzzle_id)
	if record == null:
		return
	puzzle_state_changed.emit(puzzle_id, record.state.duplicate(true), record.revision)
	if cause == Cause.RESET:
		puzzle_reset.emit(puzzle_id)
	elif cause == Cause.ACTION and record.solved and not was_solved:
		puzzle_completed.emit(puzzle_id)


func _announce_all(cause: int) -> void:
	for puzzle_id in _records.keys():
		_announce(puzzle_id, cause, false)


func _snapshot() -> Dictionary:
	var records := {}
	for puzzle_id in _records:
		records[puzzle_id] = _records[puzzle_id].to_dict()
	return records


# --- Network boundary ---------------------------------------------------------------------
# Everything below is the only code that touches RPCs. Puzzle implementations never see it.

func _connected_to_host() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## The guest's peer ID, or 0 when nobody can be reached. Never RPC without checking this.
func _guest_peer() -> int:
	if _mode != Mode.HOST:
		return 0
	var guest := NetworkManager.guest_id
	return guest if guest > 1 and multiplayer.get_peers().has(guest) else 0


## Role of a remote sender, from the real connection. Clients cannot name their own role.
func _role_of_peer(peer_id: int) -> String:
	return PuzzleBase.FUTURE if peer_id > 1 and peer_id == NetworkManager.guest_id and multiplayer.get_peers().has(peer_id) else ""


func _request_from_host(puzzle_id: String, action: String, payload: Dictionary) -> Dictionary:
	if not _session_active or not _connected_to_host():
		var result := _rejected(puzzle_id, action, "no_session", "not connected to a started game")
		action_rejected.emit(puzzle_id, action, "no_session", NetworkManager.role)
		return result
	_rpc_request_action.rpc_id(1, puzzle_id, action, payload)
	return _result(Status.PENDING, puzzle_id, action)


func _publish_update(puzzle_id: String, cause: int) -> void:
	var guest := _guest_peer()
	if guest == 0:
		return
	var record: Record = _records[puzzle_id]
	_rpc_apply_update.rpc_id(guest, _session_id, puzzle_id, record.state, record.solved, record.revision, cause)


func _push_snapshot(cause: int) -> void:
	var guest := _guest_peer()
	if guest != 0:
		_rpc_apply_snapshot.rpc_id(guest, _session_id, _revision, _snapshot(), cause)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_action(puzzle_id: String, action: String, payload: Variant) -> void:
	if _mode != Mode.HOST:
		return
	var sender := multiplayer.get_remote_sender_id()
	var role := _role_of_peer(sender)
	if role.is_empty():
		_log("Ignored puzzle action from unknown peer %d." % sender)
		return
	var result := _handle_request(puzzle_id, action, payload, role)
	if result.status == Status.REJECTED and multiplayer.get_peers().has(sender):
		_rpc_action_rejected.rpc_id(sender, puzzle_id, action, result.reason)


@rpc("authority", "call_remote", "reliable")
func _rpc_action_rejected(puzzle_id: String, action: String, reason: String) -> void:
	if _mode == Mode.CLIENT and multiplayer.get_remote_sender_id() == 1:
		action_rejected.emit(puzzle_id, action, reason, NetworkManager.role)


@rpc("authority", "call_remote", "reliable")
func _rpc_apply_update(session_id: int, puzzle_id: String, state: Dictionary, solved: bool, revision: int, cause: int) -> void:
	if _mode != Mode.CLIENT or multiplayer.get_remote_sender_id() != 1:
		return
	if not _session_active and not _sync_requested:
		# An update from a session we have not been told about: get a full snapshot instead of guessing.
		_sync_requested = true
		request_sync()
		return
	_receive_update(session_id, puzzle_id, state, solved, revision, cause)


@rpc("authority", "call_remote", "reliable")
func _rpc_apply_snapshot(session_id: int, revision: int, records: Dictionary, cause: int) -> void:
	if _mode == Mode.CLIENT and multiplayer.get_remote_sender_id() == 1:
		_receive_snapshot(session_id, revision, records, cause)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_snapshot() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if _mode != Mode.HOST or not _session_active or _role_of_peer(sender).is_empty():
		return
	_rpc_apply_snapshot.rpc_id(sender, _session_id, _revision, _snapshot(), Cause.INITIAL)


## Apply one confirmed change from the host. Returns false if it was ignored as stale or foreign.
func _receive_update(session_id: int, puzzle_id: String, state: Dictionary, solved: bool, revision: int, cause: int) -> bool:
	if not _session_active or session_id != _session_id:
		return false
	var record: Record = _records.get(puzzle_id)
	if record != null and revision <= record.revision:
		return false
	var was_solved := _store(puzzle_id, state, solved, revision)
	_announce(puzzle_id, cause, was_solved)
	return true


## Replace everything with the host's full state. A snapshot from a new session always wins;
## one from the current session must not be older than what we hold.
func _receive_snapshot(session_id: int, revision: int, records: Dictionary, cause: int) -> bool:
	var same_session := _session_active and session_id == _session_id
	if same_session and revision < _revision:
		return false
	_session_id = session_id
	_session_active = true
	_sync_requested = false
	_revision = revision
	_records.clear()
	for puzzle_id in records:
		if typeof(puzzle_id) == TYPE_STRING and typeof(records[puzzle_id]) == TYPE_DICTIONARY:
			_records[puzzle_id] = Record.from_dict(records[puzzle_id])
	if not same_session:
		session_started.emit()
	_announce_all(cause)
	return true


func _log(message: String) -> void:
	if log_rejections:
		push_warning("[PuzzleManager] " + message)
