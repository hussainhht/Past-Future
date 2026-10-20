class_name DialogueBox
extends CanvasLayer
## Presentation only. Shows one line at a time, reveals it with a typewriter and fades in and out.
## It never decides what comes next: DialogueDirector says what to show and listens for
## typewriter_finished. Names, text, portraits and colours all come from the DialogueLine it is
## given, so nothing about a character is hardcoded here.

## The line is fully visible, whether it finished typing or was revealed early. Emitted once per line
## that completes. A line that is replaced or closed before it completes never emits it.
signal typewriter_finished
## The player clicked the dialogue panel.
signal advance_requested

## Lines that would finish typing faster than this are shown at once.
const MIN_TYPING_TIME := 0.02
const INDICATOR_PULSE_TIME := 0.7
const INDICATOR_DIM_ALPHA := 0.25

@export_group("Accent colours")
## Lines spoken in the Past: warm amber.
@export var past_accent: Color = Color("e4bf7f")
## Lines spoken in the Future: cold cyan.
@export var future_accent: Color = Color("86c9d1")
## Voices heard across the rift (timeline BOTH): a subtle blue-violet.
@export var rift_accent: Color = Color("9f96e8")

@export_group("Animation")
@export_range(0.0, 2.0, 0.01, "suffix:s") var fade_in_time: float = 0.18
@export_range(0.0, 2.0, 0.01, "suffix:s") var fade_out_time: float = 0.22
## Pulses gently while a line waits for the player.
@export var continue_symbol: String = "▼"

var _typing: bool = false
var _closing: bool = false
var _show_continue: bool = true
var _accent: Color = past_accent
var _typewriter_tween: Tween
var _fade_tween: Tween
var _indicator_tween: Tween

@onready var _root: Control = %RootControl
@onready var _panel: PanelContainer = %DialoguePanel
@onready var _speaker_row: HBoxContainer = %SpeakerRow
@onready var _portrait: TextureRect = %Portrait
@onready var _speaker_name: Label = %SpeakerName
@onready var _text: RichTextLabel = %DialogueText
@onready var _indicator: Label = %ContinueIndicator
@onready var _voice: AudioStreamPlayer = %VoicePlayer


func _ready() -> void:
	_root.visible = false
	_root.modulate.a = 0.0
	_indicator.text = continue_symbol
	_indicator.modulate.a = 0.0
	_panel.gui_input.connect(_on_panel_gui_input)


func _exit_tree() -> void:
	_stop_line_effects()
	_kill_tween(_fade_tween)
	_fade_tween = null


## Show a line and start revealing it at `characters_per_second`. Whatever was showing is replaced.
## Empty text, or a speed so fast the reveal would take under MIN_TYPING_TIME, completes at once, so
## typewriter_finished may be emitted before this returns. `show_continue` says whether to prompt
## the player once the line is complete.
func present_line(line: DialogueLine, characters_per_second: float, show_continue: bool = true) -> void:
	_stop_line_effects()
	_show_continue = show_continue
	_apply_speaker(line)
	_text.text = line.text
	_text.visible_characters = 0
	_open()
	if line.voice != null:
		_voice.stream = line.voice
		_voice.play()
	_typing = true
	var total := _text.get_total_character_count()
	var duration := total / characters_per_second if characters_per_second > 0.0 else 0.0
	if total <= 0 or duration < MIN_TYPING_TIME or not is_inside_tree():
		_finish_typewriter()
		return
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(_text, "visible_characters", total, duration)
	_typewriter_tween.finished.connect(_finish_typewriter)


## Show the rest of the line immediately. Does nothing unless the line is still typing.
func reveal_all() -> void:
	_finish_typewriter()


## Fade the box out and drop whatever it was showing. Safe to call at any time, any number of times.
## A line still typing fades out complete rather than frozen half-written.
func close(immediately: bool = false) -> void:
	_stop_line_effects()
	_text.visible_characters = -1
	_kill_tween(_fade_tween)
	_fade_tween = null
	if immediately or not _root.visible or fade_out_time <= 0.0 or not is_inside_tree():
		_hide_now()
		return
	_closing = true
	_fade_tween = create_tween()
	_fade_tween.tween_property(_root, "modulate:a", 0.0, fade_out_time)
	_fade_tween.finished.connect(_hide_now)


func is_typing() -> bool:
	return _typing


## Visible and not on its way out.
func is_open() -> bool:
	return _root.visible and not _closing


## The accent colour used for lines of a timeline.
func get_accent_for(timeline: DialogueLine.Timeline) -> Color:
	match timeline:
		DialogueLine.Timeline.PAST:
			return past_accent
		DialogueLine.Timeline.FUTURE:
			return future_accent
	return rift_accent


## The accent of the line currently shown.
func get_current_accent() -> Color:
	return _accent


func get_speaker_text() -> String:
	return _speaker_name.text


## The line as the player reads it, with BBCode tags removed.
func get_line_text() -> String:
	return _text.get_parsed_text()


func is_portrait_visible() -> bool:
	return _portrait.visible


func _apply_speaker(line: DialogueLine) -> void:
	_accent = get_accent_for(line.timeline)
	var has_name := not line.speaker_name.strip_edges().is_empty()
	_speaker_name.text = line.speaker_name
	_speaker_name.visible = has_name
	_portrait.texture = line.portrait
	_portrait.visible = line.portrait != null
	_speaker_row.visible = has_name or line.portrait != null
	_speaker_name.add_theme_color_override("font_color", _accent)
	_indicator.add_theme_color_override("font_color", _accent)
	var style := _panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.border_color = Color(_accent, 0.85)


func _finish_typewriter() -> void:
	if not _typing:
		return
	_typing = false
	_kill_tween(_typewriter_tween)
	_typewriter_tween = null
	_text.visible_characters = -1
	_start_indicator()
	typewriter_finished.emit()


func _open() -> void:
	_kill_tween(_fade_tween)
	_fade_tween = null
	_closing = false
	_root.visible = true
	if _root.modulate.a >= 0.999 or fade_in_time <= 0.0 or not is_inside_tree():
		_root.modulate.a = 1.0
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(_root, "modulate:a", 1.0, fade_in_time)


func _hide_now() -> void:
	_closing = false
	_root.visible = false
	_root.modulate.a = 0.0


func _start_indicator() -> void:
	_kill_tween(_indicator_tween)
	_indicator_tween = null
	if not _show_continue or not is_inside_tree():
		return
	_indicator.modulate.a = 1.0
	_indicator_tween = create_tween().set_loops()
	_indicator_tween.tween_property(_indicator, "modulate:a", INDICATOR_DIM_ALPHA, INDICATOR_PULSE_TIME).set_trans(Tween.TRANS_SINE)
	_indicator_tween.tween_property(_indicator, "modulate:a", 1.0, INDICATOR_PULSE_TIME).set_trans(Tween.TRANS_SINE)


## Stop everything tied to the line on screen. A killed Tween never fires its callbacks, so nothing
## from an earlier line can reach the next one.
func _stop_line_effects() -> void:
	_typing = false
	_kill_tween(_typewriter_tween)
	_typewriter_tween = null
	_kill_tween(_indicator_tween)
	_indicator_tween = null
	_indicator.modulate.a = 0.0
	_voice.stop()


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


func _on_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance_requested.emit()
		_panel.accept_event()
