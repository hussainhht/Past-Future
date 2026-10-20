class_name InteractionDetector
extends Area3D
## Detects nearby Interactable3D candidates and selects the best active target.
##
## Employs area overlap events and proximity calculations with hysteresis
## to prevent target flickering.

const Interactable3D := preload("res://scripts/interaction/interactable_3d.gd")

signal target_changed(target: Interactable3D)
signal target_cleared()

@export var actor: Node3D = null
@export var default_role: String = ""
@export var detection_radius: float = 2.0
@export var hysteresis: float = 0.15

var _nearby_candidates: Array[Interactable3D] = []
var _current_target: Interactable3D = null
var _current_role: String = ""


func _ready() -> void:
	# Configure dedicated detection collision layer (Mask Layer 4 = bit 8)
	collision_layer = 0
	collision_mask = 8
	monitoring = true
	monitorable = false

	# Ensure a collision shape exists if none was authored
	_ensure_collision_shape()

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	if actor == null:
		_auto_detect_actor()

	if default_role.is_empty():
		_auto_detect_role()
	else:
		_current_role = default_role


func _ensure_collision_shape() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			return
	var col := CollisionShape3D.new()
	col.name = "DetectionShape"
	var sphere := SphereShape3D.new()
	sphere.radius = detection_radius
	col.shape = sphere
	add_child(col)


func _auto_detect_actor() -> void:
	var parent := get_parent()
	if parent is Node3D:
		actor = parent
	elif parent != null and parent.get_parent() is Node3D:
		actor = parent.get_parent()


func _auto_detect_role() -> void:
	if Engine.has_singleton("PuzzleManager"):
		var pm = Engine.get_singleton("PuzzleManager")
		if pm.has_method("get_local_role"):
			_current_role = pm.get_local_role()
	elif get_tree().root.has_node("PuzzleManager"):
		var pm = get_tree().root.get_node("PuzzleManager")
		if pm.has_method("get_local_role"):
			_current_role = pm.get_local_role()


func get_role() -> String:
	if not _current_role.is_empty():
		return _current_role
	if get_tree().root.has_node("PuzzleManager"):
		var pm = get_tree().root.get_node("PuzzleManager")
		return pm.get_local_role()
	return ""


func set_current_role(role: String) -> void:
	_current_role = role
	refresh_target()


func set_actor(new_actor: Node3D) -> void:
	actor = new_actor
	refresh_target()


func _physics_process(_delta: float) -> void:
	# Prune invalid candidates and re-evaluate nearest target as actor moves
	_prune_candidates()
	refresh_target()


func _on_area_entered(area: Area3D) -> void:
	if area is Interactable3D:
		var interactable := area as Interactable3D
		if interactable not in _nearby_candidates:
			_nearby_candidates.append(interactable)
			if not interactable.availability_changed.is_connected(_on_candidate_availability_changed):
				interactable.availability_changed.connect(_on_candidate_availability_changed)
			if not interactable.prompt_changed.is_connected(_on_candidate_prompt_changed):
				interactable.prompt_changed.connect(_on_candidate_prompt_changed.bind(interactable))
			if not interactable.tree_exiting.is_connected(_on_candidate_tree_exiting):
				interactable.tree_exiting.connect(_on_candidate_tree_exiting.bind(interactable))
			refresh_target()


func _on_area_exited(area: Area3D) -> void:
	if area is Interactable3D:
		var interactable := area as Interactable3D
		_remove_candidate(interactable)
		if _current_target == interactable:
			_set_current_target(null)
		refresh_target()


func _remove_candidate(candidate: Interactable3D) -> void:
	if candidate in _nearby_candidates:
		_nearby_candidates.erase(candidate)
	if is_instance_valid(candidate):
		if candidate.availability_changed.is_connected(_on_candidate_availability_changed):
			candidate.availability_changed.disconnect(_on_candidate_availability_changed)
		if candidate.prompt_changed.is_connected(_on_candidate_prompt_changed):
			candidate.prompt_changed.disconnect(_on_candidate_prompt_changed)
		if candidate.tree_exiting.is_connected(_on_candidate_tree_exiting):
			candidate.tree_exiting.disconnect(_on_candidate_tree_exiting)


func _on_candidate_availability_changed(_available: bool) -> void:
	refresh_target()


func _on_candidate_prompt_changed(_new_prompt: String, candidate: Interactable3D) -> void:
	if _current_target == candidate:
		target_changed.emit(candidate)


func _on_candidate_tree_exiting(candidate: Interactable3D) -> void:
	_remove_candidate(candidate)
	if _current_target == candidate:
		_set_current_target(null)
	refresh_target()


func _prune_candidates() -> void:
	var i := _nearby_candidates.size() - 1
	while i >= 0:
		var candidate := _nearby_candidates[i]
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			_nearby_candidates.remove_at(i)
		i -= 1


## Scans all nearby candidates and selects the closest eligible interactable with hysteresis.
func refresh_target() -> void:
	_prune_candidates()
	
	if actor == null:
		_auto_detect_actor()
		if actor == null:
			if _current_target != null:
				_set_current_target(null)
			return

	var role := get_role()
	var actor_pos: Vector3 = actor.global_position

	# Verify if current target remains valid and eligible
	var current_valid := false
	var current_dist := INF
	if is_instance_valid(_current_target) and not _current_target.is_queued_for_deletion():
		if _current_target.can_interact(actor, role):
			current_dist = actor_pos.distance_to(_current_target.get_interaction_position())
			if current_dist <= _current_target.interaction_distance:
				current_valid = true

	# Find the best candidate
	var best_candidate: Interactable3D = null
	var best_dist := INF
	var best_priority := -999999

	for candidate in _nearby_candidates:
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			continue
		if not candidate.can_interact(actor, role):
			continue
		
		var dist := actor_pos.distance_to(candidate.get_interaction_position())
		if dist > candidate.interaction_distance:
			continue
		
		var prio := candidate.interaction_priority
		if best_candidate == null:
			best_candidate = candidate
			best_dist = dist
			best_priority = prio
		elif prio > best_priority:
			best_candidate = candidate
			best_dist = dist
			best_priority = prio
		elif prio == best_priority:
			if dist < best_dist:
				best_candidate = candidate
				best_dist = dist

	# Determine whether to switch target
	if not current_valid:
		_set_current_target(best_candidate)
	elif best_candidate != null and best_candidate != _current_target:
		# Prioritize higher priority unconditionally
		if best_candidate.interaction_priority > _current_target.interaction_priority:
			_set_current_target(best_candidate)
		# For equal priority, apply hysteresis to prevent fluttering
		elif best_candidate.interaction_priority == _current_target.interaction_priority:
			if best_dist < (current_dist - hysteresis):
				_set_current_target(best_candidate)


func _set_current_target(new_target: Interactable3D) -> void:
	if _current_target == new_target:
		return
	
	if is_instance_valid(_current_target):
		_current_target.set_highlighted(false)
	
	_current_target = new_target
	
	if is_instance_valid(_current_target):
		_current_target.set_highlighted(true)
		target_changed.emit(_current_target)
	else:
		target_cleared.emit()


func get_current_target() -> Interactable3D:
	if is_instance_valid(_current_target) and not _current_target.is_queued_for_deletion():
		return _current_target
	return null


func get_nearby_interactables() -> Array[Interactable3D]:
	_prune_candidates()
	return _nearby_candidates.duplicate()


func clear_target() -> void:
	_set_current_target(null)
