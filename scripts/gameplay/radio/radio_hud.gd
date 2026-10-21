extends PanelContainer
## A small passive HUD. Never submits puzzle actions.

@export var radio: TemporalRadio
@onready var status_label: Label = %RadioStatus
@onready var frequency_label: Label = %RadioFrequency
@onready var signal_label: Label = %RadioSignal
var _phase: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# DSEG has no usable "M" or "z", so the "MHz" unit stays in the terminal font; seven-segment digits are drawn by the waveform.
	Typography.apply(frequency_label, &"terminal_log", 22)
	Typography.apply(status_label, &"terminal_log", 20)
	Typography.apply(signal_label, &"terminal_log", 22)
	if radio != null:
		radio.status_changed.connect(_on_status_changed)
		_on_status_changed(radio.signal_state, radio.owns_radio, radio.presentation_active)


func _on_status_changed(status: int, owned: bool, active: bool) -> void:
	var frequency := radio.get_calibrated_frequency()
	frequency_label.text = "%d MHz" % frequency if owned and frequency > 0 else "-- MHz"
	status_label.text = ["DISCONNECTED", "SEARCHING", "CONNECTED"][status]
	if not owned:
		status_label.text = "RADIO NOT ACQUIRED"
	elif not active:
		status_label.text = "RADIO STOWED"
	modulate = Color("86c9d1") if status == TemporalRadio.SignalState.CONNECTED else Color("e4bf7f")
	signal_label.text = "||||" if status == TemporalRadio.SignalState.CONNECTED else "|..."


func _process(delta: float) -> void:
	_phase += delta
	if radio != null:
		signal_label.modulate.a = 0.55 + 0.45 * absf(sin(_phase * 5.0)) if radio.transmitting or radio.signal_state == TemporalRadio.SignalState.SEARCHING else 1.0
