extends "res://scripts/interaction/interactable_3d.gd"

@export var terminal: Control


func _ready() -> void:
	super._ready()
	allowed_timeline = TimelineRestriction.PAST
	interaction_name = "Use Calibration Computer"
	play_interaction_animation = false


func _execute_interaction(actor: Node, role: String) -> void:
	if is_instance_valid(terminal):
		terminal.open_for(actor, role)
