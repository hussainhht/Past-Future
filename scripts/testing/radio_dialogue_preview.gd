extends Node
## TEMPORARY SANDBOX FIXTURE ONLY. Replace this binding with DialogueDirector when
## its public API arrives. This file is never referenced by the reusable radio scenes.
## Diagnostic text is not approved story dialogue.

const LINES := [
	["Student", "[Signal check] The temporal radio carrier is calibrated."],
	["Professor", "[Signal check] Reception is clear on the Future receiver."],
	["Student", "[Signal check] We can keep using these radios in the next stage."],
	["Professor", "[Signal check] Connection confirmed. End of test transmission."]
]

@export var adapter: Node
@export var presenter: PanelContainer
var _line: int = -1


func _ready() -> void:
	adapter.bind_sequence_player(request_sequence)
	adapter.link_sequence_id = &"sandbox.radio_check"
	presenter.advance_requested.connect(advance)
	adapter.conversation_finished.connect(func(_id: StringName): _line = -1)


func request_sequence(sequence_id: StringName) -> bool:
	if sequence_id != &"sandbox.radio_check":
		return false
	_line = -1
	advance()
	return true


func advance() -> void:
	_line += 1
	if _line >= LINES.size():
		adapter.end_conversation()
	else:
		adapter.present_line(LINES[_line][0], LINES[_line][1])
