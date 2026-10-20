class_name PuzzleInteractable3D
extends "res://scripts/interaction/interactable_3d.gd"
## Connects an interactable 3D world object to the authoritative PuzzleManager.
##
## Submits puzzle actions upon interaction and reacts to state updates,
## completions, and rejections without mutating shared puzzle state directly.

signal puzzle_action_submitted(puzzle_id: String, action: String, result: Dictionary)
signal puzzle_action_accepted(puzzle_id: String, action: String)
signal puzzle_action_rejected(puzzle_id: String, action: String, reason: String)

@export var puzzle_id: String = ""
@export var puzzle_action: String = ""
@export var puzzle_payload: Dictionary = {}
@export var disable_on_complete: bool = false
@export var disable_on_success: bool = false
@export var update_prompt_on_state: bool = true


func _ready() -> void:
	super._ready()
	_connect_to_puzzle_manager()


func _connect_to_puzzle_manager() -> void:
	if not Engine.has_singleton("PuzzleManager") and not get_tree().root.has_node("PuzzleManager"):
		return
	
	var pm = get_tree().root.get_node_or_null("PuzzleManager")
	if pm == null:
		return
	
	if not pm.puzzle_state_changed.is_connected(_on_puzzle_state_changed):
		pm.puzzle_state_changed.connect(_on_puzzle_state_changed)
	if not pm.puzzle_completed.is_connected(_on_puzzle_completed):
		pm.puzzle_completed.connect(_on_puzzle_completed)
	if not pm.action_rejected.is_connected(_on_action_rejected):
		pm.action_rejected.connect(_on_action_rejected)
	
	if not puzzle_id.is_empty():
		if pm.has_method("is_solved") and pm.is_solved(puzzle_id):
			if disable_on_complete:
				set_interaction_enabled(false)
		if pm.has_method("get_state"):
			var current_state: Dictionary = pm.get_state(puzzle_id)
			if not current_state.is_empty():
				_apply_puzzle_state(current_state)


func get_payload(_actor: Node, _role: String) -> Dictionary:
	return puzzle_payload.duplicate(true)


func _execute_interaction(actor: Node, role: String) -> void:
	if puzzle_id.is_empty() or puzzle_action.is_empty():
		push_warning("PuzzleInteractable3D '%s' has empty puzzle_id or puzzle_action." % name)
		return

	var pm = get_tree().root.get_node_or_null("PuzzleManager")
	if pm == null:
		push_error("PuzzleInteractable3D cannot find PuzzleManager autoload.")
		return

	var actual_role := role
	if actual_role.is_empty() and pm.has_method("get_local_role"):
		actual_role = pm.get_local_role()

	var payload := get_payload(actor, actual_role)
	var result: Dictionary = pm.submit_action(puzzle_id, puzzle_action, payload, actual_role)
	puzzle_action_submitted.emit(puzzle_id, puzzle_action, result)

	var status = result.get("status", -1)
	# Check against PuzzleManager status enum:
	# REJECTED = 0, NO_CHANGE = 1, CHANGED = 2, COMPLETED = 3, PENDING = 4
	if status == 0: # REJECTED
		puzzle_action_rejected.emit(puzzle_id, puzzle_action, result.get("reason", ""))
	elif status == 2: # CHANGED
		puzzle_action_accepted.emit(puzzle_id, puzzle_action)
		if disable_on_success:
			set_interaction_enabled(false)
	elif status == 3: # COMPLETED
		puzzle_action_accepted.emit(puzzle_id, puzzle_action)
		if disable_on_complete or disable_on_success:
			set_interaction_enabled(false)
	elif status == 4: # PENDING
		# Remote request in flight, awaiting confirmation from host
		pass


func _on_puzzle_state_changed(p_id: String, state: Dictionary, _revision: int) -> void:
	if p_id == puzzle_id:
		_apply_puzzle_state(state)


func _on_puzzle_completed(p_id: String) -> void:
	if p_id == puzzle_id and disable_on_complete:
		set_interaction_enabled(false)


func _on_action_rejected(p_id: String, action: String, reason: String, _actor_role: String) -> void:
	if p_id == puzzle_id and action == puzzle_action:
		puzzle_action_rejected.emit(p_id, action, reason)


## Override in subclasses to update object visuals or prompt based on puzzle state.
func _apply_puzzle_state(_state: Dictionary) -> void:
	pass
