extends "res://scripts/gameplay/frequency/frequency_modal.gd"

var document_label: Label


func _ready() -> void:
	super._ready()
	content.add_child(UI.label("RECOVERED RESEARCH LOG", 24, UI.CYAN))
	content.add_child(HSeparator.new())
	document_label = UI.label("", 20, Color("d4e1e4"))
	document_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	document_label.custom_minimum_size.x = 510
	content.add_child(document_label)
	var close_button := UI.button("CLOSE  [ESC]")
	close_button.pressed.connect(close)
	content.add_child(close_button)


func show_document(text: String, actor: Node, role: String) -> bool:
	var actual_role := role if NetworkManager.state == NetworkManager.State.IDLE else PuzzleManager.get_local_role()
	if actual_role != "future":
		return false
	document_label.text = text
	return open_for(actor, role)
