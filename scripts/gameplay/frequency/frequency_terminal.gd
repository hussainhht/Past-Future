extends "res://scripts/gameplay/frequency/frequency_modal.gd"
## Local terminal view. Only PuzzleManager can accept calibration or establish a link.

const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const Status := preload("res://scripts/puzzles/puzzle_base.gd").Status
const InputManager := preload("res://scripts/input/input_manager.gd")

@export_range(1, 999, 1) var display_frequency: int = Rules.DEFAULT_FREQUENCY

var frequency_input: LineEdit
var calibrate_button: Button
var close_button: Button
var keypad_container: GridContainer
var keypad_buttons: Array[Button] = []
var status_label: Label
var feedback_label: Label
var _role: String = "past"
var _feedback_tween: Tween
var _last_tune_text: String = ""


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

	_build_keypad()

	calibrate_button = UI.button("CALIBRATE SIGNAL")
	calibrate_button.set_meta("audio_event", &"")
	calibrate_button.pressed.connect(submit_frequency)
	content.add_child(calibrate_button)
	feedback_label = UI.label("Awaiting frequency calibration...", 17, Color("c5d1da"))
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.custom_minimum_size = Vector2(510, 58)
	content.add_child(feedback_label)
	close_button = UI.button("CLOSE  [ESC / ○]")
	close_button.set_meta("audio_event", &"")
	close_button.pressed.connect(close)
	content.add_child(close_button)

	_setup_focus_navigation()

	InputManager.get_instance().device_changed_signal.connect(_on_device_changed)

	PuzzleManager.puzzle_state_changed.connect(_on_state_changed)
	refresh()


func _build_keypad() -> void:
	keypad_container = GridContainer.new()
	keypad_container.name = "KeypadGrid"
	keypad_container.columns = 3
	keypad_container.add_theme_constant_override("h_separation", 8)
	keypad_container.add_theme_constant_override("v_separation", 8)

	var keys: Array[String] = [
		"1", "2", "3",
		"4", "5", "6",
		"7", "8", "9",
		"⌫", "0", "CLR"
	]

	for key in keys:
		var btn := Button.new()
		btn.name = "Keypad_" + ("BACKSPACE" if key == "⌫" else key)
		btn.text = key
		btn.custom_minimum_size = Vector2(64, 40)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_stylebox_override("normal", UI.panel(UI.AMBER))
		btn.add_theme_stylebox_override("hover", UI.panel(UI.CYAN))
		btn.add_theme_stylebox_override("focus", UI.panel(UI.CYAN))
		btn.focus_mode = Control.FOCUS_ALL
		btn.pressed.connect(_on_keypad_button_pressed.bind(key))
		keypad_container.add_child(btn)
		keypad_buttons.append(btn)
	content.add_child(keypad_container)


func _setup_focus_navigation() -> void:
	if keypad_buttons.size() < 12:
		return
	frequency_input.focus_neighbor_bottom = keypad_buttons[0].get_path()
	for i in range(3):
		keypad_buttons[i].focus_neighbor_top = frequency_input.get_path()
	for i in range(9, 12):
		keypad_buttons[i].focus_neighbor_bottom = calibrate_button.get_path()
	calibrate_button.focus_neighbor_top = keypad_buttons[10].get_path()
	calibrate_button.focus_neighbor_bottom = close_button.get_path()
	close_button.focus_neighbor_top = calibrate_button.get_path()


func _on_keypad_button_pressed(key: String) -> void:
	if not frequency_input.editable:
		return
	if key == "⌫":
		if not frequency_input.text.is_empty():
			frequency_input.text = frequency_input.text.left(-1)
			_validate_text(frequency_input.text)
	elif key == "CLR":
		frequency_input.text = ""
		_validate_text(frequency_input.text)
	else:
		if frequency_input.text.length() < 3:
			frequency_input.text += key
			_validate_text(frequency_input.text)


func _on_device_changed(device_type: int, _controller_type: int) -> void:
	if not is_instance_valid(close_button):
		return
	if device_type == InputManager.DeviceType.CONTROLLER:
		close_button.text = "CLOSE  [○]"
	else:
		close_button.text = "CLOSE  [ESC]"


func open_for(actor: Node, role: String = "") -> bool:
	_role = role if NetworkManager.state == NetworkManager.State.IDLE and not role.is_empty() else PuzzleManager.get_local_role()
	if _role != "past" or not super.open_for(actor, _role):
		return false
	refresh()
	var is_controller: bool = InputManager.active_device_type == InputManager.DeviceType.CONTROLLER
	if is_controller and not keypad_buttons.is_empty():
		keypad_buttons[0].grab_focus()
	else:
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
	if visible and frequency_input.editable and frequency_input.text != _last_tune_text:
		_last_tune_text = frequency_input.text
		audio_cue_requested.emit(&"tune")
	# Keep invalid pasted input visible for correction; it can never be submitted.
	calibrate_button.disabled = not _valid_frequency() or PuzzleManager.get_state(Rules.ID).get("frequency_calibrated", false)


func submit_frequency() -> Dictionary:
	if not _valid_frequency():
		feedback_label.text = "Enter a whole-number frequency from 1 to 999 MHz."
		audio_cue_requested.emit(&"failed")
		return {"status": Status.REJECTED, "reason": "invalid_frequency"}
	audio_cue_requested.emit(&"attempt")
	var result := PuzzleManager.submit_action(Rules.ID, "tune_frequency", {"frequency": frequency_input.text.to_int()}, _role)
	if result.status == Status.REJECTED:
		feedback_label.text = "Acquire your handheld radio first." if result.reason == "student_radio_required" else "Calibration unavailable: " + str(result.reason)
	elif result.status == Status.NO_CHANGE and result.get("message") == "SIGNAL NOT FOUND":
		feedback_label.text = "SIGNAL NOT FOUND - Check the research log and retry."
		audio_cue_requested.emit(&"failed")
		if _feedback_tween != null:
			_feedback_tween.kill()
		feedback_label.modulate = Color("ed9a80")
		_feedback_tween = create_tween()
		_feedback_tween.tween_property(feedback_label, "modulate", Color.WHITE, 0.6)
	else:
		InputManager.trigger_haptic(&"radio_connect")
		refresh()
	return result


func refresh() -> void:
	var state := PuzzleManager.get_state(Rules.ID)
	var calibrated: bool = state.get("frequency_calibrated", false) == true
	var connected := Rules.link_established(state)
	status_label.text = "TEMPORAL RADIO LINK ESTABLISHED" if connected else ("SIGNAL LOCKED" if calibrated else "SIGNAL UNSTABLE")
	status_label.add_theme_font_size_override("font_size", 20 if connected else 22)
	frequency_input.editable = not calibrated
	for btn in keypad_buttons:
		btn.disabled = calibrated
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
