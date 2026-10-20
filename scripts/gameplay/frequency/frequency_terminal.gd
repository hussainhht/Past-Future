extends "res://scripts/gameplay/frequency/frequency_modal.gd"
## Local terminal view. Only PuzzleManager can accept calibration or establish a link.

const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const Status := preload("res://scripts/puzzles/puzzle_base.gd").Status

@export_range(1, 999, 1) var display_frequency: int = Rules.DEFAULT_FREQUENCY

var frequency_input: LineEdit
var calibrate_button: Button
var status_label: Label
var feedback_label: Label
var _role: String = "past"
var _feedback_tween: Tween


func _ready() -> void:
	super._ready()
	content.add_child(UI.label("TEMPORAL COMMUNICATION ARRAY", 24))
	content.add_child(UI.label("MAIN LABORATORY COMPUTER  /  CALIBRATION", 14, Color("8295a9")))
	content.add_child(HSeparator.new())
	status_label = UI.label("SIGNAL UNSTABLE", 22, UI.CYAN)
	content.add_child(status_label)
	content.add_child(UI.label("CALIBRATION FREQUENCY", 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	frequency_input = LineEdit.new()
	frequency_input.name = "FrequencyInput"
	frequency_input.placeholder_text = "000"
	frequency_input.max_length = 3
	frequency_input.custom_minimum_size = Vector2(220, 48)
	frequency_input.add_theme_font_size_override("font_size", 26)
	frequency_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	frequency_input.text_changed.connect(_validate_text)
	frequency_input.text_submitted.connect(func(_text: String): submit_frequency())
	row.add_child(frequency_input)
	row.add_child(UI.label("MHz", 24))
	calibrate_button = UI.button("CALIBRATE SIGNAL")
	calibrate_button.pressed.connect(submit_frequency)
	content.add_child(calibrate_button)
	feedback_label = UI.label("Awaiting frequency calibration...", 17, Color("c5d1da"))
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.custom_minimum_size = Vector2(510, 58)
	content.add_child(feedback_label)
	var close_button := UI.button("CLOSE  [ESC]")
	close_button.pressed.connect(close)
	content.add_child(close_button)
	PuzzleManager.puzzle_state_changed.connect(_on_state_changed)
	refresh()


func open_for(actor: Node, role: String = "") -> bool:
	_role = role if NetworkManager.state == NetworkManager.State.IDLE and not role.is_empty() else PuzzleManager.get_local_role()
	if _role != "past" or not super.open_for(actor, _role):
		return false
	refresh()
	frequency_input.grab_focus()
	return true


func _valid_frequency() -> bool:
	var value := frequency_input.text
	if value.is_empty():
		return false
	for character in value:
		if character < "0" or character > "9":
			return false
	return value.to_int() >= Rules.MIN_FREQUENCY and value.to_int() <= Rules.MAX_FREQUENCY


func _validate_text(_text: String) -> void:
	# Keep invalid pasted input visible for correction; it can never be submitted.
	calibrate_button.disabled = not _valid_frequency() or PuzzleManager.get_state(Rules.ID).get("frequency_calibrated", false)


func submit_frequency() -> Dictionary:
	if not _valid_frequency():
		feedback_label.text = "Enter a whole-number frequency from 1 to 999 MHz."
		return {"status": Status.REJECTED, "reason": "invalid_frequency"}
	audio_cue_requested.emit(&"attempt")
	var result := PuzzleManager.submit_action(Rules.ID, "tune_frequency", {"frequency": frequency_input.text.to_int()}, _role)
	if result.status == Status.REJECTED:
		feedback_label.text = "Acquire your handheld radio first." if result.reason == "student_radio_required" else "Calibration unavailable: " + str(result.reason)
	elif result.status == Status.NO_CHANGE and result.get("message") == "SIGNAL NOT FOUND":
		feedback_label.text = "SIGNAL NOT FOUND - Check the research log and retry."
		audio_cue_requested.emit(&"static")
		if _feedback_tween != null:
			_feedback_tween.kill()
		feedback_label.modulate = Color("ed9a80")
		_feedback_tween = create_tween()
		_feedback_tween.tween_property(feedback_label, "modulate", Color.WHITE, 0.6)
	else:
		refresh()
	return result


func refresh() -> void:
	var state := PuzzleManager.get_state(Rules.ID)
	var calibrated: bool = state.get("frequency_calibrated", false) == true
	var connected := Rules.link_established(state)
	status_label.text = "TEMPORAL RADIO LINK ESTABLISHED" if connected else ("SIGNAL LOCKED" if calibrated else "SIGNAL UNSTABLE")
	status_label.add_theme_font_size_override("font_size", 20 if connected else 22)
	frequency_input.editable = not calibrated
	if calibrated:
		frequency_input.text = str(display_frequency)
		feedback_label.text = "CONNECTION STABLE - %s MHz" % frequency_input.text if connected else "Frequency calibrated. Awaiting both handheld radios."
	else:
		feedback_label.text = "Awaiting frequency calibration..."
		if not visible:
			frequency_input.clear()
	_validate_text(frequency_input.text)


func _on_state_changed(puzzle_id: String, _state: Dictionary, _revision: int) -> void:
	if puzzle_id == Rules.ID:
		refresh()
