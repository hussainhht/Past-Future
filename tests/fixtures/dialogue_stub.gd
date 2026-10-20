extends Node
## Fixture: stands in for a DialogueDirector that is in the middle of a conversation.

var active: bool = true


func _ready() -> void:
	add_to_group(&"dialogue_director")


func is_dialogue_active() -> bool:
	return active
