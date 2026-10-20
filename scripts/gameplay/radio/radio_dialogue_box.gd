extends "res://scripts/dialogue/dialogue_box.gd"
## A radio skin for the actual DialogueBox. Its typewriter, signals and speaker
## presentation remain owned by the existing Dialogue System.

@export var radio: TemporalRadio
var radio_mode: bool = false
var suspended: bool = false
var channel_label: Label
var _phase: float = 0.0


func _ready() -> void:
	super._ready()
	channel_label = Label.new()
	channel_label.name = "RadioChannel"
	channel_label.add_theme_font_size_override("font_size", 15)
	channel_label.add_theme_color_override("font_color", future_accent)
	var content: VBoxContainer = $RootControl/DialoguePanel/Content
	content.add_child(channel_label)
	content.move_child(channel_label, 0)
	channel_label.hide()
	if radio != null:
		radio.status_changed.connect(_on_radio_status_changed)
	_refresh_channel()


func set_radio_mode(enabled: bool) -> void:
	radio_mode = enabled
	channel_label.visible = enabled
	_refresh_channel()


func present_line(line: DialogueLine, characters_per_second: float, show_continue: bool = true) -> void:
	if radio_mode and radio != null:
		radio.set_transmitting(false)
		radio.set_transmitting(true, DialogueLine.timeline_name(line.timeline) != radio.player_role)
	super.present_line(line, characters_per_second, show_continue)


func close(immediately: bool = false) -> void:
	if radio != null:
		radio.set_transmitting(false)
	super.close(immediately)


func _process(delta: float) -> void:
	if radio_mode and radio != null and radio.transmitting:
		_phase += delta
		channel_label.modulate.a = 0.7 + 0.3 * absf(sin(_phase * 5.0))


func _on_panel_gui_input(event: InputEvent) -> void:
	if suspended or (radio_mode and radio != null and not radio.can_receive()):
		return
	super._on_panel_gui_input(event)


func _on_radio_status_changed(_status: int, _owned: bool, _active: bool) -> void:
	_refresh_channel()
	if radio_mode and is_open() and radio.can_receive():
		radio.set_transmitting(true)


func _refresh_channel() -> void:
	if channel_label == null or radio == null:
		return
	channel_label.text = "%d MHz  /  %s" % [radio.display_frequency, "CONNECTED  ·  RADIO TRANSMISSION" if radio.can_receive() else "SIGNAL INTERFERENCE"]
