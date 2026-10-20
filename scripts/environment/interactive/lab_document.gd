extends LabDevice
## A readable document on a desk: the same paper in both timelines, read in LabUI's document
## viewer. The Future text is what survived thirty-one years (stains, a second hand in the margins).

@export var title: String = "Document"
@export var future_title: String = ""
@export_multiline var past_text: String = ""
@export_multiline var future_text: String = ""
@export var prompt: String = "Read"


func _show_state(_animate: bool) -> void:
	$Interactable.interaction_name = prompt


func _on_interacted(_actor: Node, _role: String, _interactable: Node) -> void:
	var lab_ui := ui()
	if lab_ui == null:
		return
	if future:
		lab_ui.open_document(future_title if not future_title.is_empty() else title, future_text if not future_text.is_empty() else past_text)
	else:
		lab_ui.open_document(title, past_text)
