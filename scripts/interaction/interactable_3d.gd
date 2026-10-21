class_name Interactable3D
extends Area3D
## Base component defining an interactive 3D object.
##
## Manages interaction eligibility, contextual prompt text, timeline restrictions,
## proximity distance, facing requirements, and lifecycle signals.

enum TimelineRestriction { BOTH = 0, PAST = 1, FUTURE = 2 }
enum Timing { IMMEDIATE = 0, AFTER_ANIMATION = 1 }

## Contextual action name displayed to the player, e.g. "Use Computer" or "Inspect Door".
@export var interaction_name: String = "Interact":
	set(value):
		if interaction_name != value:
			interaction_name = value
			prompt_changed.emit(interaction_name)

## Whether this object can currently be interacted with.
@export var interaction_enabled: bool = true:
	set(value):
		if interaction_enabled != value:
			interaction_enabled = value
			availability_changed.emit(interaction_enabled)
			if not interaction_enabled and _is_highlighted:
				set_highlighted(false)

## Maximum distance from the player to this interactable's anchor.
@export var interaction_distance: float = 1.5

## Tie-breaker priority when multiple objects are at similar distances. Higher wins.
@export var interaction_priority: int = 0

## Timeline restriction: 0 = Both, 1 = Past only, 2 = Future only.
@export_enum("Both", "Past", "Future") var allowed_timeline: int = TimelineRestriction.BOTH

## If true, the player must be roughly facing this object to interact.
@export var requires_facing: bool = false

## Minimum dot-product threshold between player forward heading and vector to object.
@export var facing_dot_threshold: float = 0.3

## Whether to trigger the character's action animation upon interaction.
@export var play_interaction_animation: bool = true

## The action name passed to the character controller (e.g. "interact", "inspect", "pick_up").
@export var animation_action_name: String = "interact"

## When to execute the interaction behavior:
## IMMEDIATE (0): Trigger interaction immediately (e.g. opening UI while animation plays).
## AFTER_ANIMATION (1): Wait until character action animation completes before executing.
@export_enum("Immediate", "After Animation") var timing: int = Timing.AFTER_ANIMATION

## If true, automatically disables interaction after the first successful use.
@export var one_shot: bool = false

## Optional 3D node used as the target center point instead of this Area3D's origin.
@export var interaction_anchor: Node3D = null

## Optional visual attachment for the interaction prompt, independent of interaction range.
@export var prompt_anchor: Node3D = null

## Optional node to receive highlight toggles (e.g. an outline mesh or indicator node).
@export var highlight_target: Node3D = null

## Emitted when interaction input is received and validated.
signal interaction_requested(actor: Node, role: String)
## Emitted when interaction execution begins.
signal interaction_started(actor: Node, role: String)
## Emitted when interaction execution completes.
signal interaction_finished(actor: Node, role: String)
## Convenient signal for simple decoupled room scripts.
signal interacted(actor: Node, role: String)
## Emitted whenever the contextual prompt text changes.
signal prompt_changed(new_prompt: String)
## Emitted when the interactable is enabled or disabled.
signal availability_changed(is_available: bool)
## Emitted when this object becomes or ceases to be the active selection.
signal highlight_changed(is_highlighted: bool)

var _is_highlighted: bool = false


func _ready() -> void:
	# Configure dedicated interaction physics layer (Layer 4 = bit 8) by default
	# if collision layer hasn't been custom-configured.
	if collision_layer == 1:
		collision_layer = 8
		collision_mask = 0
	monitorable = true


## Returns the global anchor position used for proximity and facing calculations.
func get_interaction_position() -> Vector3:
	if is_instance_valid(interaction_anchor):
		return interaction_anchor.global_position
	return global_position


func get_prompt_position() -> Vector3:
	if is_instance_valid(prompt_anchor):
		return prompt_anchor.global_position
	for child in get_children():
		if child is CollisionShape3D:
			return child.global_position
	return global_position


## Checks if the given timeline role is permitted to interact with this object.
func is_timeline_allowed(role: String) -> bool:
	if allowed_timeline == TimelineRestriction.BOTH or role.is_empty():
		return true
	var r := role.to_lower()
	if allowed_timeline == TimelineRestriction.PAST:
		return r == "past"
	elif allowed_timeline == TimelineRestriction.FUTURE:
		return r == "future"
	return false


## Validates whether the given actor is eligible to interact right now.
func can_interact(actor: Node, role: String = "") -> bool:
	if not interaction_enabled:
		return false
	if not is_instance_valid(actor):
		return false
	if not is_timeline_allowed(role):
		return false
	
	if actor is Node3D:
		var actor_pos: Vector3 = (actor as Node3D).global_position
		var target_pos := get_interaction_position()
		# Check distance on 3D plane
		var dist := actor_pos.distance_to(target_pos)
		if dist > interaction_distance:
			return false
		
		# Optional facing check
		if requires_facing:
			if not _is_actor_facing(actor as Node3D):
				return false
	
	return true


func _is_actor_facing(actor: Node3D) -> bool:
	var facing: Vector3
	if actor.has_node("Visual"):
		facing = -actor.get_node("Visual").global_transform.basis.z
	else:
		facing = -actor.global_transform.basis.z
	facing.y = 0.0
	if facing.is_zero_approx():
		return true
	facing = facing.normalized()
	
	var to_target: Vector3 = get_interaction_position() - actor.global_position
	to_target.y = 0.0
	if to_target.is_zero_approx():
		return true
	to_target = to_target.normalized()
	
	return facing.dot(to_target) >= facing_dot_threshold


## Returns the contextual prompt string displayed on screen.
func get_interaction_prompt(_actor: Node = null) -> String:
	return interaction_name


func set_interaction_name(value: String) -> void:
	interaction_name = value


func set_interaction_enabled(value: bool) -> void:
	interaction_enabled = value


## Main interaction entry point called by InteractionController.
func interact(actor: Node, role: String = "") -> void:
	if not can_interact(actor, role):
		return
	
	interaction_requested.emit(actor, role)
	interaction_started.emit(actor, role)
	_execute_interaction(actor, role)
	interacted.emit(actor, role)
	
	if one_shot:
		set_interaction_enabled(false)
	
	interaction_finished.emit(actor, role)


## Override in subclasses to execute custom interaction logic.
func _execute_interaction(_actor: Node, _role: String) -> void:
	pass


## Toggles visual emphasis when selected by the interaction detector.
func set_highlighted(highlighted: bool) -> void:
	if _is_highlighted == highlighted:
		return
	_is_highlighted = highlighted
	highlight_changed.emit(highlighted)
	
	if is_instance_valid(highlight_target):
		if highlight_target.has_method("set_highlighted"):
			highlight_target.call("set_highlighted", highlighted)
		else:
			highlight_target.visible = highlighted
