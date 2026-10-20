extends LabDevice
## The signal array console, dressed for both timelines around the frequency puzzle's own parts:
##   Past   - its FrequencyComputer opens the calibration terminal (FrequencyTerminal).
##   Future - its FrequencyClue opens the recovered research log (FrequencyLogReader), which holds
##            the frequency the Past player must enter. The console runs on its emergency cell.
## SignalLab binds both to the room's screens. The screen, readout, lamp and sparks follow the
## confirmed state of puzzle_01_frequency; nothing here submits a puzzle action.

@onready var screen: MeshInstance3D = $Screen
@onready var readout: Label3D = $Readout
@onready var status_lamp: MeshInstance3D = $StatusLamp
@onready var glow: OmniLight3D = $ScreenGlow
@onready var sparks: CPUParticles3D = $Sparks
@onready var computer: Interactable3D = $Computer
@onready var recovered_log: Interactable3D = $RecoveredLog


func _ready() -> void:
	# The frequency components ship with placeholder meshes; the console itself is their body here.
	for part in [computer, recovered_log]:
		var placeholder := part.get_node_or_null("Placeholder") as Node3D
		if placeholder != null:
			placeholder.visible = false
	super()


## Hand the calibration terminal and the research-log reader to the console's components.
func bind_screens(terminal: Control, reader: Control) -> void:
	computer.set("terminal", terminal)
	recovered_log.set("reader", reader)


func _state_changed(previous: Dictionary) -> void:
	if previous.is_empty():
		return
	if linked() and not Rules.link_established(previous):
		sfx(&"interaction_success", Vector3(0, 1.7, 0.5))
	elif state.get("frequency_calibrated", false) and not previous.get("frequency_calibrated", false):
		sfx(&"computer_beep", Vector3(0, 1.7, 0.5))


func _show_state(_animate: bool) -> void:
	var calibrated: bool = state.get("frequency_calibrated", false)
	var link := linked()
	paint(screen, "tex_console_live" if not future or link else "tex_console_dead")
	paint(status_lamp, "led_go" if link or (calibrated and not future) else ("led_amber" if not future else "led_off"))
	glow.light_color = Color("8dffb8") if link else (Color("86c9d1") if future else Color("ffd59a"))
	glow.light_energy = 0.9 if link or not future else 0.35
	sparks.emitting = future and not link
	if link:
		readout.text = "TEMPORAL LINK"
		readout.modulate = Color("8dffb8")
	elif future:
		readout.text = "EMERGENCY CELL  ·  LOG"
		readout.modulate = Color("9fe8f0")
	elif calibrated:
		readout.text = "SIGNAL LOCKED"
		readout.modulate = Color("ffd59a")
	else:
		readout.text = "SIGNAL UNSTABLE"
		readout.modulate = Color("ffb36b")


func _on_interacted(_actor: Node, _role: String, _interactable: Node) -> void:
	sfx(&"computer_beep", Vector3(0, 1.0, 0.5))
