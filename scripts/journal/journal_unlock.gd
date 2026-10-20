class_name JournalUnlock
extends Node
## Drop-in adapter: when the sibling/parent Interactable3D is used, unlock journal entries.
## Add it as a child of the interactable (or of a device that owns one) and list entry IDs.
## Entries belonging to the other timeline are ignored, so one adapter can serve both players.

@export var entry_ids: PackedStringArray = PackedStringArray()
## Leave empty to use the parent, or the first Interactable3D below it.
@export var source: Node


func _ready() -> void:
	var target := source if source != null else _find_source()
	if target != null and not target.interacted.is_connected(_on_interacted):
		target.interacted.connect(_on_interacted)


func _find_source() -> Node:
	var owner_node := get_parent()
	if owner_node == null:
		return null
	if owner_node.has_signal("interacted"):
		return owner_node
	for candidate in owner_node.find_children("*", "Area3D", true, false):
		if candidate.has_signal("interacted"):
			return candidate
	return null


func _on_interacted(_actor: Node, _role: String) -> void:
	for id in entry_ids:
		JournalManager.unlock_entry(id)
