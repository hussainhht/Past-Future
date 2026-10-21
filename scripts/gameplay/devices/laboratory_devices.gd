extends Node
## Connects the physical transmitter dials and Future receiver to shared puzzle state.
const Inspector = preload("res://scripts/gameplay/devices/device_inspector_3d.gd")
const Rules = preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
var game: Node
var inspector: Node
var mode := ""
var log_text := ""
var last_result: Dictionary = {}


func configure(composition: Node) -> void:
	game = composition
	inspector = Inspector.new()
	add_child(inspector)
	game.room.lab.get_node("FrequencyScreens").visible = false
	game.computer.set("physical_handler", self)
	game.clue.set("physical_handler", self)
	game.computer.get_parent().set_meta("occlusion_body", game.room.get_node("Actors/Console"))
	inspector.install_frequency_dial(game.computer.get_parent())
	inspector.dial_changed.connect(_on_dial_changed)
	inspector.active_changed.connect(_on_active_changed)
	game.terminal.modal_changed.connect(_on_modal_changed)
	game.reader.modal_changed.connect(_on_modal_changed)
	PuzzleManager.puzzle_state_changed.connect(func(id: String, _state: Dictionary, _revision: int):
		if id == Rules.ID:
			apply_timeline()
			if inspector.active: _update_record())


func apply_timeline() -> void:
	var state := PuzzleManager.get_state(Rules.ID)
	var unit: Node3D = game.computer.get_parent().get_node("MountedFrequencyDial")
	unit.visible = game.room.timeline == "Past"
	var frequency: int = state.get("current_frequency", Rules.INITIAL_FREQUENCY)
	var amplitude: int = state.get("current_amplitude", Rules.INITIAL_AMPLITUDE)
	unit.get_node("EntryReadout").text = "%03d MHz" % frequency
	unit.get_node("AmplitudeReadout").text = "%02d%%" % amplitude
	unit.get_node("TuningKnob").rotation.z = -deg_to_rad((frequency - 1) * inspector.DIAL_DEGREES_PER_MHZ)
	unit.get_node("AmplitudeKnob").rotation.z = -deg_to_rad((amplitude - 1) * inspector.DIAL_DEGREES_PER_MHZ)
	if inspector.active and mode == "frequency":
		inspector.set_signal_values(frequency, amplitude, Rules.radios_ready(state) and not Rules.link_established(state))


func open_frequency(actor: Node, role: String) -> void:
	if not game.terminal.open_for(actor, role): return
	mode = "frequency"
	var state := PuzzleManager.get_state(Rules.ID)
	inspector.entry = str(state.get("current_frequency", Rules.INITIAL_FREQUENCY))
	inspector.amplitude = state.get("current_amplitude", Rules.INITIAL_AMPLITUDE)
	refresh()
	game.room.lab.ui.observe("Student", "Two dials: frequency and amplitude. The Professor can see the changes on the receiver.")


func open_log(text: String, actor: Node, role: String) -> void:
	if not game.reader.show_document(text, actor, role): return
	mode = "log"
	log_text = text
	refresh()
	game.room.lab.ui.observe("Professor", "The green trace is coming from the Past. The grey trace is the signal we need.")


func _record_text() -> String:
	if mode == "frequency":
		return "SIGNAL ARRAY\n" + game.terminal.status_label.text + "\n\n" + game.terminal.feedback_label.text + "\n\nFREQUENCY / changes cycle spacing.\nAMPLITUDE / changes wave height.\n\nAsk the Professor to guide both settings. The link locks when both waveforms match."
	return "LIVE RECEIVER\n\nGREEN / current signal from the Past.\nGREY / target signal.\n\nWatch the screen while the Student turns the frequency and amplitude dials. Guide them until both traces overlap.\n\nBoth handheld radios must be collected before tuning." + "\n\n" + log_text


func _update_record() -> void:
	inspector._record_body.text = _record_text()


func refresh() -> void:
	if not is_instance_valid(game) or not game.configured: return
	var state := PuzzleManager.get_state(Rules.ID)
	var options := [{"disabled": not Rules.radios_ready(state) or Rules.link_established(state)}]
	inspector.open_device(game.computer.get_parent(), game.room.camera, game.room.player,
		"PAST / LIVE TRANSMITTER" if mode == "frequency" else "FUTURE / LIVE RECEIVER",
		_record_text(), options if mode == "frequency" else [], {}, "frequency_dial" if mode == "frequency" else "", game.room.timeline == "Future")
	apply_timeline()
	game.room.lab.ui.set_control_hint("Drag either dial clockwise to increase; counterclockwise to decrease. Wheel / arrows: fine tune. Tab: switch dial. Shift: 10 steps. Esc / F: step back." if mode == "frequency" else "Green: current signal. Grey: target. Guide the Student until frequency and amplitude match. Esc / F: step back.")


func _on_dial_changed(parameter: String, value: int) -> void:
	if mode != "frequency": return
	last_result = game.terminal.submit_amplitude(value) if parameter == "amplitude" else game.terminal.submit_frequency(value)
	if last_result.status == 0: apply_timeline()


func _on_active_changed(open: bool) -> void:
	if not open:
		game.terminal.close()
		game.reader.close()
		game.room.lab.ui.set_control_hint("")
	game.sync_controls()


func _on_modal_changed(open: bool) -> void:
	if not open and inspector.active: inspector.close()
