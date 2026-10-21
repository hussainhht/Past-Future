class_name TransitionOverlay
extends CanvasLayer
## Fade-to-black cover, loading text, the "who is ready" panel and short notices. Owned by the
## GameFlowManager autoload, so it survives every room change. It knows nothing about rooms or
## networking; GameFlowManager drives it through the methods below.

## A fade reached its end. covering is true when the screen is now fully black.
signal fade_finished(covering: bool)

const PAST_ACCENT := Color("e4bf7f")
const FUTURE_ACCENT := Color("86c9d1")
const WAITING := Color("77868a")

var _fade_tween: Tween
var _notice_tween: Tween

@onready var fade: ColorRect = %Fade
@onready var title_label: Label = %TitleLabel
@onready var status_label: Label = %StatusLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var ready_panel: PanelContainer = %ReadyPanel
@onready var ready_header: Label = %ReadyHeader
@onready var student_label: Label = %StudentLabel
@onready var professor_label: Label = %ProfessorLabel
@onready var notice_panel: PanelContainer = %NoticePanel
@onready var notice_label: Label = %NoticeLabel


func _ready() -> void:
	add_to_group("game_flow_overlay")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	fade.visible = false
	fade.modulate.a = 0.0
	ready_panel.visible = false
	notice_panel.visible = false
	for panel in [ready_panel, notice_panel]:
		panel.add_theme_stylebox_override("panel", _panel_style())
	var background := StyleBoxFlat.new()
	background.bg_color = Color(1, 1, 1, 0.08)
	var fill := StyleBoxFlat.new()
	fill.bg_color = FUTURE_ACCENT
	progress_bar.add_theme_stylebox_override("background", background)
	progress_bar.add_theme_stylebox_override("fill", fill)
	title_label.add_theme_color_override("font_color", PAST_ACCENT)
	status_label.add_theme_color_override("font_color", Color("bac5c2"))
	clear_status()


## Space used by ready/error notices, shared with the room's right-side message rail.
func message_rect() -> Rect2:
	if ready_panel.is_visible_in_tree() or notice_panel.is_visible_in_tree():
		return $Dock.get_global_rect()
	return Rect2()


# --- Fade ----------------------------------------------------------------------------------

## Fade to black, from wherever the cover is now. Emits fade_finished(true).
func fade_out(duration: float) -> void:
	_fade_to(1.0, duration)


## Fade back to the room. Emits fade_finished(false).
func fade_in(duration: float) -> void:
	_fade_to(0.0, duration)


## Black or clear at once, without a signal. Used for recovery.
func snap(black: bool) -> void:
	_kill_fade()
	fade.modulate.a = 1.0 if black else 0.0
	fade.visible = black


## True while any visible part of the cover is up, so gameplay is not fully readable.
func is_covering() -> bool:
	return fade.visible and fade.modulate.a > 0.01


func is_fully_black() -> bool:
	return fade.visible and fade.modulate.a >= 0.999


func _fade_to(alpha: float, duration: float) -> void:
	_kill_fade()
	fade.visible = true
	_fade_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade_tween.tween_property(fade, "modulate:a", alpha, maxf(duration, 0.0))
	_fade_tween.tween_callback(_on_fade_done.bind(alpha >= 1.0))


func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


func _on_fade_done(covering: bool) -> void:
	_fade_tween = null
	fade.visible = covering
	fade_finished.emit(covering)


# --- Loading text --------------------------------------------------------------------------

func set_status(title: String, detail: String) -> void:
	title_label.text = title
	status_label.text = detail
	progress_bar.value = 0.0


## 0..1; shown as a thin bar under the text.
func set_progress(progress: float) -> void:
	progress_bar.value = clampf(progress, 0.0, 1.0) * progress_bar.max_value


func clear_status() -> void:
	title_label.text = ""
	status_label.text = ""
	progress_bar.value = 0.0


# --- Readiness panel -----------------------------------------------------------------------

## Show who has confirmed leaving. Both lines are always shown so the waiting player is visible.
func show_readiness(destination_name: String, past_ready: bool, future_ready: bool) -> void:
	ready_header.text = ("NEXT: " + destination_name.to_upper()) if not destination_name.is_empty() else "READY TO MOVE ON"
	_set_ready_line(student_label, "STUDENT", past_ready, PAST_ACCENT)
	_set_ready_line(professor_label, "PROFESSOR", future_ready, FUTURE_ACCENT)
	ready_panel.visible = true


## Both are ready and the transition is starting.
func show_departing() -> void:
	ready_header.text = "BOTH PLAYERS READY"
	_set_ready_line(student_label, "STUDENT", true, PAST_ACCENT)
	_set_ready_line(professor_label, "PROFESSOR", true, FUTURE_ACCENT)
	ready_panel.visible = true


func hide_readiness() -> void:
	ready_panel.visible = false


func is_readiness_visible() -> bool:
	return ready_panel.visible


func _set_ready_line(label: Label, who: String, is_ready: bool, accent: Color) -> void:
	label.text = "%s   %s" % [who, "READY" if is_ready else "WAITING"]
	label.add_theme_color_override("font_color", accent if is_ready else WAITING)


# --- Notices -------------------------------------------------------------------------------

## A short line in the right-side notice stack, for refused requests.
func show_notice(text: String, seconds: float = 3.0) -> void:
	if text.is_empty():
		return
	if _notice_tween != null and _notice_tween.is_valid():
		_notice_tween.kill()
	notice_label.text = text
	notice_panel.modulate.a = 1.0
	notice_panel.visible = true
	_notice_tween = create_tween()
	_notice_tween.tween_interval(maxf(seconds, 0.1))
	_notice_tween.tween_property(notice_panel, "modulate:a", 0.0, 0.3)
	_notice_tween.tween_callback(func() -> void: notice_panel.visible = false)


func hide_notice() -> void:
	if _notice_tween != null and _notice_tween.is_valid():
		_notice_tween.kill()
	notice_panel.visible = false


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.11, 0.9)
	style.border_color = Color(0.37, 0.48, 0.48, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style
