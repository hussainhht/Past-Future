extends "res://scripts/interaction/interactable_3d.gd"
## Independent paper clue; the reader can later be replaced by the Document System.

@export var reader: Control
@export_multiline var research_text: String = "TEMPORAL COMMUNICATION ARRAY\nCalibration Record #01\n\nPrimary synchronization frequency: 67 MHz\n\nA stable carrier is required to maintain handheld radio communication across the temporal fracture.\n\nStatus: Calibration pending."


func _ready() -> void:
	super._ready()
	allowed_timeline = TimelineRestriction.FUTURE
	interaction_name = "Read Research Log"
	play_interaction_animation = false


func _execute_interaction(actor: Node, role: String) -> void:
	if is_instance_valid(reader):
		reader.show_document(research_text, actor, role)
