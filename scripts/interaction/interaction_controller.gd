class_name InteractionController
extends Node
## Coordinates player interaction execution, character animations, movement locking,
## and prompt UI synchronization.

const Interactable3D := preload("res://scripts/interaction/interactable_3d.gd")
const InteractionDetector := preload("res://scripts/interaction/interaction_detector.gd")

signal interaction_performed(target: Interactable3D)
signal interaction_failed(reason: String)

@export var detector: InteractionDetector = null
@export var actor: CharacterBody3D = null
@export var prompt_ui: Node = null

var _interaction_blocked: bool = false
var _is_executing_interaction: bool = false
var _pending_target: Interactable3D = null


func _ready() -> void:
	_auto_wire_components()


func _auto_wire_components() -> void:
	if detector == null:
		# Check siblings, children, or parent for detector
		detector = get_node_or_null("../InteractionDetector")
		if detector == null:
			detector = find_child("InteractionDetector", true, false)
		if detector == null and get_parent() is InteractionDetector:
			detector = get_parent() as InteractionDetector

	if actor == null:
		# Search parent hierarchy for CharacterBody3D
		var current := get_parent()
		while current != null:
			if current is CharacterBody3D:
				actor = current
				break
			current = current.get_parent()

	if detector != null:
		if not detector.target_changed.is_connected(_on_target_changed):
			detector.target_changed.connect(_on_target_changed)
		if not detector.target_cleared.is_connected(_on_target_cleared):
			detector.target_cleared.connect(_on_target_cleared)


func _on_target_changed(target: Interactable3D) -> void:
	if is_instance_valid(prompt_ui) and not _interaction_blocked:
		var prompt_text := target.get_interaction_prompt(actor)
		if prompt_ui.has_method("set_target"):
			prompt_ui.call("set_target", target)
		if prompt_ui.has_method("show_prompt"):
			prompt_ui.call("show_prompt", prompt_text, get_actor_role())


func _on_target_cleared() -> void:
	if is_instance_valid(prompt_ui):
		if prompt_ui.has_method("hide_prompt"):
			prompt_ui.call("hide_prompt")


## Returns true if an interaction can currently be triggered by input.
func is_interaction_available() -> bool:
	if _interaction_blocked or _is_executing_interaction:
		return false
	if detector == null:
		return false
	var target := detector.get_current_target()
	return target != null and target.can_interact(actor, get_actor_role())


## Attempts to interact with the currently focused interactable.
## Returns true if interaction input was consumed.
func try_interact() -> bool:
	if _interaction_blocked:
		interaction_failed.emit("blocked")
		return false
	
	if _is_executing_interaction:
		interaction_failed.emit("busy")
		return false
	
	if detector == null:
		interaction_failed.emit("no_detector")
		return false
	
	var target := detector.get_current_target()
	if target == null:
		interaction_failed.emit("no_target")
		return false
	
	var role := get_actor_role()
	if not target.can_interact(actor, role):
		interaction_failed.emit("ineligible")
		return false
	
	_execute_target_interaction(target, role)
	return true


func _execute_target_interaction(target: Interactable3D, role: String) -> void:
	if target.play_interaction_animation and is_instance_valid(actor) and actor.has_method("play_action"):
		_is_executing_interaction = true
		_pending_target = target
		
		var action_name := target.animation_action_name
		var animation_started: bool = actor.call("play_action", action_name)
		if not animation_started:
			_is_executing_interaction = false
			_pending_target = null
			interaction_failed.emit("animation_rejected")
			return
		
		# If timing is IMMEDIATE, trigger interaction behavior immediately
		if target.timing == Interactable3D.Timing.IMMEDIATE:
			target.interact(actor, role)
			interaction_performed.emit(target)
		
		# Connect to action_finished to unlock control and trigger AFTER_ANIMATION
		var cb := Callable(self, "_on_actor_action_finished")
		if not actor.action_finished.is_connected(cb):
			actor.action_finished.connect(cb, CONNECT_ONE_SHOT)
	else:
		# Direct execution without animation lock
		target.interact(actor, role)
		interaction_performed.emit(target)


func _on_actor_action_finished(_action: String) -> void:
	_is_executing_interaction = false
	var target := _pending_target
	_pending_target = null
	
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		if target.timing == Interactable3D.Timing.AFTER_ANIMATION:
			target.interact(actor, get_actor_role())
			interaction_performed.emit(target)
	
	if is_instance_valid(detector):
		detector.refresh_target()


func set_interaction_blocked(blocked: bool) -> void:
	_interaction_blocked = blocked
	if blocked:
		if is_instance_valid(prompt_ui) and prompt_ui.has_method("hide_prompt"):
			prompt_ui.call("hide_prompt")
	else:
		if is_instance_valid(detector) and detector.get_current_target() != null:
			_on_target_changed(detector.get_current_target())


func get_current_interactable() -> Interactable3D:
	if is_instance_valid(detector):
		return detector.get_current_target()
	return null


func get_actor_role() -> String:
	if is_instance_valid(detector):
		return detector.get_role()
	if get_tree().root.has_node("PuzzleManager"):
		var pm = get_tree().root.get_node("PuzzleManager")
		if pm.has_method("get_local_role"):
			return pm.get_local_role()
	return ""
