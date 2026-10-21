extends Node
## Adapts the existing frequency rules/model to controls built into the physical console.
const Inspector = preload("res://scripts/gameplay/devices/device_inspector_3d.gd")
var game: Node
var inspector: Node
var mode := ""
var log_text := ""
var last_result: Dictionary = {}
var _staged_frequency := 50


func configure(composition: Node) -> void:
	game = composition
	inspector = Inspector.new()
	add_child(inspector)
	game.room.lab.get_node("FrequencyScreens").visible = false
	game.computer.set("physical_handler", self)
	game.clue.set("physical_handler", self)
	game.computer.get_parent().set_meta("occlusion_body", game.room.get_node("Actors/Console"))
	inspector.install_frequency_dial(game.computer.get_parent())
	inspector.action_requested.connect(_on_action)
	inspector.entry_changed.connect(func(text: String) -> void:
		_staged_frequency = text.to_int()
		game.terminal.frequency_input.text = text)
	inspector.active_changed.connect(_on_active_changed)
	game.terminal.modal_changed.connect(_on_modal_changed)
	game.reader.modal_changed.connect(_on_modal_changed)
	PuzzleManager.puzzle_state_changed.connect(func(id: String, _state: Dictionary, _revision: int) -> void:
		if id == "puzzle_01_frequency":
			if not _state.get("student_radio", false) and not _state.get("professor_radio", false): _staged_frequency = 50
			if inspector.active: refresh.call_deferred()
			else: apply_timeline())


func apply_timeline() -> void:
	var unit: Node3D = game.computer.get_parent().get_node("MountedFrequencyDial")
	var display: Label3D = unit.get_node("EntryReadout")
	var calibrated: bool = PuzzleManager.get_state("puzzle_01_frequency").get("frequency_calibrated", false)
	var value: int = game.terminal.display_frequency if calibrated else _staged_frequency
	display.text = ("%03d MHz" % value) if calibrated or game.room.timeline == "Past" else "LOG"
	unit.get_node("TuningKnob").rotation.z = -deg_to_rad((value - 1) * inspector.DIAL_DEGREES_PER_MHZ)


func open_frequency(actor: Node, role: String) -> void:
	if not game.terminal.open_for(actor, role): return
	mode = "frequency"
	inspector.entry = str(game.terminal.display_frequency if PuzzleManager.get_state("puzzle_01_frequency").get("frequency_calibrated", false) else _staged_frequency)
	refresh()
	game.room.lab.ui.observe("Student", "The carrier light is holding at this setting." if PuzzleManager.get_state("puzzle_01_frequency").get("frequency_calibrated", false) else "A tuning dial. The frequency changes when I turn it.")


func open_log(text: String, actor: Node, role: String) -> void:
	if not game.reader.show_document(text, actor, role): return
	mode = "log"
	log_text = text
	refresh()
	game.room.lab.ui.observe("Professor", "The emergency cell is still holding. I can make out the last calibration.")


func refresh() -> void:
	if not is_instance_valid(game) or not game.configured: return
	var options: Array = []
	var title := "RECEIVER BANK B / RECORD 01"
	var body := log_text
	if mode == "frequency":
		title = "ARRAY CARRIER / CALIBRATION"
		var feedback: String = game.terminal.feedback_label.text
		if "Acquire" in feedback: feedback = "RECEIVER NOT REGISTERED / CONTROL LOCKED"
		elif "SIGNAL NOT FOUND" in feedback: feedback = "NO CARRIER RESPONSE / VERIFY SETPOINT"
		elif "whole-number" in feedback: feedback = "SETPOINT OUT OF RANGE / 001-999 MHz"
		elif "Awaiting frequency" in feedback: feedback = "SET CARRIER / CALIBRATION REQUIRED"
		body = "SIGNAL ARRAY\n" + game.terminal.status_label.text + "\n\n" + feedback + "\n\nOperating range: 001-999 MHz.\nRotate tuning dial to set carrier.\nPress CALIBRATE to lock the signal.\n\nDOOR INTERLOCK\nRelease requires a stable carrier and two registered handheld receivers."
		options = [{"label": "Calibrate signal", "action": "tune_frequency", "disabled": PuzzleManager.get_state("puzzle_01_frequency").get("frequency_calibrated", false)}]
	var console: Node3D = game.computer.get_parent()
	inspector.open_device(console, game.room.camera, game.room.player, title, body, options, {}, "frequency_dial" if mode == "frequency" else "")
	game.room.lab.ui.set_control_hint("Drag the dial clockwise to increase frequency; counterclockwise to decrease. Wheel / arrows: fine tune. Shift: 10 MHz steps. Click CALIBRATE or press Enter. Esc / F: step back." if mode == "frequency" else "Read the recovered record on the console. Esc / F: step back.")


func _on_action(_action: String, payload: Dictionary) -> void:
	if mode != "frequency": return
	game.terminal.frequency_input.text = str(payload.frequency)
	last_result = game.terminal.submit_frequency()
	refresh()


func _on_active_changed(open: bool) -> void:
	if not open:
		game.terminal.close()
		game.reader.close()
		game.room.lab.ui.set_control_hint("")
	game.sync_controls()


func _on_modal_changed(open: bool) -> void:
	if not open and inspector.active: inspector.close()
