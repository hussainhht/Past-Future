class_name LevelExitInteractable
extends "res://scripts/interaction/interactable_3d.gd"
## Reusable "go to the next area" interaction. It never loads a scene: it only tells
## GameFlowManager that the local player is ready (or no longer ready) to leave. Place it in a
## room, give it a CollisionShape3D that covers the exit zone, and set destination_room_id.
##
## Pressing the interact key marks the player ready; pressing it again, or walking out of the
## zone, withdraws it. When both players are ready the host starts the transition.

## Emitted with a player-facing sentence when the request was refused.
signal exit_feedback(message: String)

## Room to go to. Leave empty to use the current room's next_room_id.
@export var destination_room_id: String = ""
@export var ready_prompt: String = "Proceed to Next Area"
@export var waiting_prompt: String = "Cancel (waiting for your partner)"
## Withdraw readiness when the player's character leaves this node's collision shape.
@export var cancel_on_leave: bool = true


func _init() -> void:
	# Leaving is a decision, not a character action: no animation lock, answer at once.
	play_interaction_animation = false
	timing = Timing.IMMEDIATE


func _ready() -> void:
	super._ready()
	# The base class listens on layer 8 for detectors; also watch layer 1 for the character leaving.
	collision_mask |= 1
	monitoring = true
	body_exited.connect(_on_body_exited)
	GameFlowManager.readiness_changed.connect(_on_flow_changed.unbind(3))
	GameFlowManager.request_rejected.connect(_on_request_rejected)
	GameFlowManager.room_changed.connect(_on_flow_changed.unbind(1))
	_refresh_prompt()


## The room this exit leads to, resolved when used so one exit scene can serve several rooms.
func get_destination() -> String:
	if not destination_room_id.is_empty():
		return destination_room_id
	var current := GameFlowManager.get_current_room()
	return current.next_room_id if current != null else ""


func can_interact(actor: Node, role: String = "") -> bool:
	return super.can_interact(actor, role) and not GameFlowManager.is_transitioning()


func _execute_interaction(_actor: Node, _role: String) -> void:
	var destination := get_destination()
	if destination.is_empty():
		exit_feedback.emit("There is nowhere to go from here.")
		return
	if GameFlowManager.is_local_ready(destination):
		GameFlowManager.cancel_transition_request()
	else:
		GameFlowManager.request_transition(destination)


func _on_body_exited(body: Node3D) -> void:
	if not cancel_on_leave or GameFlowManager.is_input_locked():
		return
	if body is CharacterBody3D and "controls_enabled" in body and GameFlowManager.is_local_ready(get_destination()):
		GameFlowManager.cancel_transition_request()


func _on_request_rejected(destination: String, _reason: String, message: String) -> void:
	if destination == get_destination():
		exit_feedback.emit(message)


func _on_flow_changed() -> void:
	_refresh_prompt()


func _refresh_prompt() -> void:
	var waiting := GameFlowManager.is_local_ready(get_destination())
	set_interaction_name(waiting_prompt if waiting else ready_prompt)
