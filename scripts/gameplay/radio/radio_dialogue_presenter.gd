extends PanelContainer
## Radio skin for the existing DialogueDirector. This view reveals ONE supplied line;
## it never chooses lines, advances sequences, or owns story content.

const UI := preload("res://scripts/gameplay/frequency/frequency_ui.gd")

signal advance_requested
signal line_revealed

@export var radio: TemporalRadio
@export_range(1.0, 100.0) var characters_per_second: float = 38.0

var speaker_label: Label
var text_label: RichTextLabel
var connection_label: Label
var advance_button: Button
var _reveal: float = 0.0
var _revealed: bool = false
var _has_line: bool = false
var _signal_phase: float = 0.0


func _ready() -> void:
	add_theme_stylebox_override("panel", UI.panel(UI.CYAN))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	connection_label = UI.label("RADIO / DISCONNECTED", 20, UI.CYAN)
	column.add_child(connection_label)
	speaker_label = UI.label("", 22, UI.AMBER, &"dialogue_speaker")
	column.add_child(speaker_label)
	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = false
	text_label.fit_content = true
	text_label.custom_minimum_size = Vector2(0, 65)
	Typography.style_rich(text_label, &"dialogue_body", 24)
	column.add_child(text_label)
	advance_button = UI.button("CONTINUE")
	advance_button.pressed.connect(request_advance)
	column.add_child(advance_button)
	if radio != null:
		radio.status_changed.connect(_on_status_changed)
		_on_status_changed(radio.signal_state, radio.owns_radio, radio.presentation_active)
	hide()


func show_line(speaker_name: String, dialogue_text: String) -> bool:
	if radio == null or not radio.can_receive():
		return false
	speaker_label.text = speaker_name
	text_label.text = dialogue_text
	text_label.visible_characters = 0
	_reveal = 0.0
	_revealed = false
	_has_line = true
	show()
	radio.set_transmitting(false)
	radio.set_transmitting(true)
	return true


func reveal_line() -> void:
	text_label.visible_characters = -1
	if not _revealed:
		_revealed = true
		line_revealed.emit()


func request_advance() -> void:
	if not _has_line or radio == null or not radio.can_receive():
		return
	if not _revealed:
		reveal_line()
	else:
		advance_requested.emit()


func end_transmission() -> void:
	_has_line = false
	hide()
	if radio != null:
		radio.set_transmitting(false)


func _process(delta: float) -> void:
	if not _has_line or radio == null or not radio.can_receive():
		return
	_signal_phase += delta
	connection_label.modulate.a = 0.7 + 0.3 * absf(sin(_signal_phase * 6.0))
	if not _revealed:
		_reveal += delta * characters_per_second
		text_label.visible_characters = int(_reveal)
		if text_label.visible_characters >= text_label.get_total_character_count():
			reveal_line()


func _on_status_changed(status: int, _owned: bool, _active: bool) -> void:
	connection_label.text = "%d MHz / %s" % [radio.display_frequency, ["DISCONNECTED", "SIGNAL INTERFERENCE", "CONNECTED"][status]]
	advance_button.disabled = status != TemporalRadio.SignalState.CONNECTED
	if not radio.has_established_link():
		end_transmission()
	elif _has_line and radio.can_receive():
		radio.set_transmitting(true)
