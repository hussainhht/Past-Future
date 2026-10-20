class_name InteractionRig
extends Node3D
## Reusable interaction rig combining detector and controller into one drop-in component.

const InteractionDetector := preload("res://scripts/interaction/interaction_detector.gd")
const InteractionController := preload("res://scripts/interaction/interaction_controller.gd")

@onready var detector: InteractionDetector = $InteractionDetector
@onready var controller: InteractionController = $InteractionController


func _ready() -> void:
	if controller.detector == null:
		controller.detector = detector
	
	var parent := get_parent()
	if parent is CharacterBody3D and controller.actor == null:
		controller.actor = parent
	if parent is Node3D and detector.actor == null:
		detector.actor = parent
