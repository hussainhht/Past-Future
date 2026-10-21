extends "res://scripts/gameplay/frequency/frequency_modal.gd"

const InputManager := preload("res://scripts/input/input_manager.gd")

const Waveform := preload("res://scripts/gameplay/frequency/frequency_waveform.gd")
const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
var waveform: Control
var document_label: Label
var close_button: Button


func _ready() -> void:
	super._ready()
	content.add_child(UI.label("LIVE SIGNAL RECEIVER", 24, UI.CYAN))
	content.add_child(HSeparator.new())
	waveform = Waveform.new()
	waveform.custom_minimum_size = Vector2(640, 420)
	content.add_child(waveform)
	PuzzleManager.puzzle_state_changed.connect(func(id: String, state: Dictionary, _revision: int):
		if id == Rules.ID: waveform.set_signal(state, true))
	waveform.set_signal(PuzzleManager.get_state(Rules.ID), true)
	document_label = UI.label("", 20, Color("d4e1e4"))
	document_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	document_label.custom_minimum_size.x = 640
	document_label.hide()
	content.add_child(document_label)
	close_button = UI.button("CLOSE  [ESC / ○]")
	close_button.set_meta("audio_event", &"")
	close_button.pressed.connect(close)
	content.add_child(close_button)

	InputManager.get_instance().device_changed_signal.connect(_on_device_changed)


func _on_device_changed(device_type: int, _controller_type: int) -> void:
	if not is_instance_valid(close_button):
		return
	if device_type == InputManager.DeviceType.CONTROLLER:
		close_button.text = "CLOSE  [○]"
	else:
		close_button.text = "CLOSE  [ESC]"


func show_document(text: String, actor: Node, role: String) -> bool:
	var actual_role := role if NetworkManager.state == NetworkManager.State.IDLE else PuzzleManager.get_local_role()
	if actual_role != "future":
		return false
	document_label.text = text
	var opened := open_for(actor, role)
	if opened and is_instance_valid(close_button):
		close_button.grab_focus()
	return opened
