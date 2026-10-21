extends "res://scripts/gameplay/frequency/frequency_modal.gd"
## Both dials submit live changes through PuzzleManager; the Future observes confirmed state.
const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const Status := preload("res://scripts/puzzles/puzzle_base.gd").Status
const InputManager := preload("res://scripts/input/input_manager.gd")

var frequency_dial: HSlider
var amplitude_dial: HSlider
var frequency_label: Label
var amplitude_label: Label
var close_button: Button
var status_label: Label
var feedback_label: Label
var _role := "past"


func _ready() -> void:
	super._ready()
	content.add_child(UI.label("TEMPORAL COMMUNICATION ARRAY", 24))
	content.add_child(UI.label("PAST TRANSMITTER / LIVE TUNING", 14, UI.CYAN))
	status_label = UI.label("WAITING FOR BOTH RADIOS", 20, UI.CYAN)
	content.add_child(status_label)
	frequency_label = UI.label("")
	content.add_child(frequency_label)
	frequency_dial = _slider(Rules.MAX_FREQUENCY)
	frequency_dial.value_changed.connect(func(value: float): submit_frequency(roundi(value)))
	amplitude_label = UI.label("")
	content.add_child(amplitude_label)
	amplitude_dial = _slider(Rules.MAX_AMPLITUDE)
	amplitude_dial.value_changed.connect(func(value: float): submit_amplitude(roundi(value)))
	feedback_label = UI.label("", 17, Color("c5d1da"))
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.custom_minimum_size = Vector2(510, 58)
	content.add_child(feedback_label)
	close_button = UI.button("CLOSE  [ESC / ○]")
	close_button.pressed.connect(close)
	content.add_child(close_button)
	PuzzleManager.puzzle_state_changed.connect(func(id: String, _state: Dictionary, _revision: int):
		if id == Rules.ID: refresh())
	refresh()


func _slider(maximum: int) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 1
	slider.max_value = maximum
	slider.step = 1
	slider.custom_minimum_size = Vector2(510, 40)
	content.add_child(slider)
	return slider


func open_for(actor: Node, role: String = "") -> bool:
	_role = role if NetworkManager.state == NetworkManager.State.IDLE and not role.is_empty() else PuzzleManager.get_local_role()
	if _role != "past" or not super.open_for(actor, _role): return false
	refresh()
	frequency_dial.grab_focus()
	return true


func submit_frequency(value: int = -1) -> Dictionary:
	return _tune("frequency", roundi(frequency_dial.value) if value == -1 else value)


func submit_amplitude(value: int = -1) -> Dictionary:
	return _tune("amplitude", roundi(amplitude_dial.value) if value == -1 else value)


func _tune(parameter: String, value: int) -> Dictionary:
	var result := PuzzleManager.submit_action(Rules.ID, "tune_" + parameter, {parameter: value}, _role)
	if result.status == Status.REJECTED:
		refresh()
		feedback_label.text = "Both players must pick up their handheld radios before tuning." if result.reason.ends_with("radio_required") else "Tuning unavailable: " + str(result.reason)
	elif result.status in [Status.CHANGED, Status.COMPLETED, Status.PENDING]:
		audio_cue_requested.emit(&"tune")
		if result.status == Status.COMPLETED: InputManager.trigger_haptic(&"radio_connect")
	return result


func refresh() -> void:
	var state := PuzzleManager.get_state(Rules.ID)
	var connected := Rules.link_established(state)
	var ready := Rules.radios_ready(state)
	var frequency: int = state.get("current_frequency", Rules.INITIAL_FREQUENCY)
	var amplitude: int = state.get("current_amplitude", Rules.INITIAL_AMPLITUDE)
	status_label.text = "TEMPORAL RADIO LINK ESTABLISHED" if connected else ("LIVE SIGNAL / TUNING" if ready else "WAITING FOR BOTH RADIOS")
	frequency_dial.set_value_no_signal(frequency)
	amplitude_dial.set_value_no_signal(amplitude)
	frequency_dial.editable = ready and not connected
	amplitude_dial.editable = ready and not connected
	frequency_label.text = "FREQUENCY  %03d MHz" % frequency
	amplitude_label.text = "AMPLITUDE  %02d%%" % amplitude
	feedback_label.text = "Waveforms matched. Connection stable." if connected else ("Turn both dials. The Future sees every change. Match the grey target to establish the link." if ready else "Both players must pick up their handheld radios before tuning.")
