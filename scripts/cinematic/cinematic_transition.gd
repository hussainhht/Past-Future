class_name CinematicTransition
extends CanvasLayer
## One room introduction: chapter label, room title, accent line and timeline markers, styled by a
## RoomIntroStyle and animated with a single Tween. Purely visual and local to this client: it never
## takes input, never touches gameplay and frees itself through `finished`.
## Create it through CinematicTransitionManager rather than directly.

## The sequence ended. completed is false when it was dismissed early.
signal finished(completed: bool)
## An optional audio moment was reached. Empty cues are never emitted.
signal audio_cue(cue: StringName)

const REDUCED_FADE_IN := 0.35
const REDUCED_FADE_OUT := 0.5
const REDUCED_MIN_HOLD := 1.8
const DISMISS_SECONDS := 0.25

var _style: RoomIntroStyle
var _data: RoomIntroData
var _timeline: String = "past"
var _reduced: bool = false
var _speed: float = 1.0
var _tween: Tween
var _ambient: Tween
var _pulse: Tween
var _title_font: FontVariation
var _viewport_size: Vector2 = Vector2.ZERO
var _ended: bool = false

@onready var stage: Control = %Stage
@onready var vignette: TextureRect = %Vignette
@onready var scrim: TextureRect = %Scrim
@onready var grain: TextureRect = %Grain
@onready var sweep: TextureRect = %Sweep
@onready var scan: TextureRect = %Scan
@onready var bar_top: ColorRect = %BarTop
@onready var bar_bottom: ColorRect = %BarBottom
@onready var block: Control = %Block
@onready var vline: ColorRect = %VLine
@onready var chapter: Label = %Chapter
@onready var title_clip: Control = %TitleClip
@onready var ghost_a: Label = %GhostA
@onready var ghost_b: Label = %GhostB
@onready var title: Label = %Title
@onready var line: ColorRect = %Line
@onready var line_tick: ColorRect = %LineTick
@onready var role: Label = %Role
@onready var detail: Label = %Detail
@onready var footer: Control = %Footer
@onready var coordinates: Label = %Coordinates
@onready var marker: TimelineMarker = %Marker

# Layout results the animation needs.
var _line_width: float = 0.0
var _clip_width: float = 0.0
var _clip_pad: float = 0.0
var _unit: float = 1.0
var _block_top: float = 0.0
var _block_height: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_on_viewport_resized)


func _exit_tree() -> void:
	_kill_tweens()


## Start the sequence. speed > 1 plays faster; reduced swaps motion for plain fades.
func play(data: RoomIntroData, style: RoomIntroStyle, timeline: String, reduced: bool = false, speed: float = 1.0) -> void:
	_data = data
	_style = style
	_timeline = "future" if timeline == "future" else "past"
	_reduced = reduced
	_speed = maxf(speed, 0.1)
	_ended = false
	_build()
	_layout()
	if _reduced:
		_play_reduced()
	else:
		_play_full()


## Stop early with a short fade. Safe at any time; does nothing once ended.
func dismiss() -> void:
	if _ended:
		return
	_kill_tweens()
	_tween = create_tween()
	_tween.tween_property(stage, "modulate:a", 0.0, DISMISS_SECONDS)
	_tween.finished.connect(_end.bind(false))


func is_ended() -> bool:
	return _ended


# --- Build ---------------------------------------------------------------------------------

func _build() -> void:
	var s := _style
	# Chapter cards use the shared Oxanium UI family.
	_title_font = _make_font(Typography.font(&"heading"))
	var label_font := _make_font(Typography.font(&"ui_label"))

	chapter.text = "%s  /  %s" % [_data.chapter_label, _data.chapter_title] if not _data.chapter_title.is_empty() else _data.chapter_label
	title.text = _data.room_title
	ghost_a.text = _data.room_title
	ghost_b.text = _data.room_title
	role.text = s.role_line
	detail.text = s.timeline_line
	coordinates.text = "TEMPORAL COORDINATES  /  %02d" % _data.location_index

	for label: Label in [title, ghost_a, ghost_b]:
		label.add_theme_font_override("font", _title_font)
	for label: Label in [chapter, role, detail, coordinates]:
		label.add_theme_font_override("font", label_font)
	for label: Label in [chapter, title, role, detail, coordinates]:
		label.add_theme_color_override("font_shadow_color", Color(s.shade_color, 0.85))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
	title.add_theme_color_override("font_color", s.text_color)
	chapter.add_theme_color_override("font_color", s.accent_color.lerp(s.text_color, 0.35))
	role.add_theme_color_override("font_color", s.text_color)
	detail.add_theme_color_override("font_color", Color(s.text_color, 0.62))
	coordinates.add_theme_color_override("font_color", Color(s.text_color, 0.6))
	ghost_a.add_theme_color_override("font_color", s.accent_color)
	ghost_b.add_theme_color_override("font_color", s.secondary_color)

	vignette.modulate = Color(s.shade_color, s.vignette_alpha)
	scrim.modulate = Color(s.shade_color, s.scrim_alpha)
	grain.modulate = Color(s.accent_color, 0.07)
	grain.visible = s.film_grain and not _reduced
	sweep.modulate = Color(s.accent_color, 0.0)
	sweep.visible = s.light_sweep and not _reduced
	scan.modulate = Color(s.secondary_color, 0.0)
	scan.visible = s.scanline and not _reduced
	for bar: ColorRect in [bar_top, bar_bottom]:
		bar.color = Color(s.shade_color.darkened(0.6), 1.0)
		bar.visible = s.letterbox > 0.0 and not _reduced
	line.color = s.secondary_color if s.light_sweep else s.accent_color
	line_tick.color = s.secondary_color
	vline.color = Color(s.accent_color, 0.55)
	line_tick.visible = s.interface_lines
	vline.visible = s.interface_lines
	ghost_a.visible = s.glitch and not _reduced
	ghost_b.visible = s.glitch and not _reduced

	marker.font = label_font
	marker.text_color = s.text_color
	marker.dim_color = Color(s.text_color, 0.45)
	marker.line_color = s.accent_color
	marker.active_index = 1 if _timeline == "future" else 0
	marker.visible = not s.timeline_numeral.is_empty()

	stage.modulate = Color(1, 1, 1, 0)


func _make_font(base: Font) -> FontVariation:
	# Own instance per card: the tracking tween changes spacing_glyph.
	var variation := FontVariation.new()
	variation.base_font = base
	return variation


# --- Layout --------------------------------------------------------------------------------

func _on_viewport_resized() -> void:
	if _ended or _style == null:
		return
	_layout()


## Positions everything for the current viewport. Safe to call again mid-sequence.
func _layout() -> void:
	var s := _style
	_viewport_size = get_viewport().get_visible_rect().size
	var view := _viewport_size
	_unit = clampf(minf(view.x / 1600.0, view.y / 900.0), 0.55, 1.3)
	var margin := clampf(view.x * 0.08, 36.0, 180.0)
	var max_width := minf(view.x - margin * 2.0, 1100.0 * maxf(_unit, 1.0))
	var label_px := maxi(int(round(s.label_size * _unit)), 11)
	var detail_px := maxi(int(round(s.detail_size * _unit)), 12)
	var gap := 16.0 * _unit

	# Label tracking is a fixed fraction of the size; the title tracks from wide to settled.
	var label_font := chapter.get_theme_font("font") as FontVariation
	label_font.spacing_glyph = int(round(label_px * 0.22))
	var wide := _title_font
	var title_px := _fit_title(wide, int(round(s.title_size * _unit)), max_width, s.tracking_start)
	wide.spacing_glyph = int(round(title_px * s.tracking_start))

	var chapter_h := label_font.get_height(label_px)
	var title_h := wide.get_height(title_px)
	var detail_h := label_font.get_height(detail_px)
	var small_h := label_font.get_height(label_px)

	block.position = Vector2(margin, 0.0)
	_block_top = clampf(view.y * 0.29, 80.0 * _unit, view.y * 0.4)
	block.position.y = _block_top

	_clip_pad = 28.0 * _unit
	var y := 0.0
	chapter.add_theme_font_size_override("font_size", label_px)
	chapter.position = Vector2(0.0, y)
	chapter.size = Vector2(max_width, chapter_h)
	y += chapter_h + gap

	for label: Label in [title, ghost_a, ghost_b]:
		label.add_theme_font_size_override("font_size", title_px)
		label.size = Vector2(max_width + _clip_pad, title_h)
		label.position = Vector2(_clip_pad, 0.0)
	title.add_theme_constant_override("shadow_offset_y", int(round(3.0 * _unit)))
	title_clip.position = Vector2(-_clip_pad, y)
	_clip_width = max_width + _clip_pad * 2.0
	title_clip.size = Vector2(_clip_width, title_h)
	y += title_h + gap * 0.9

	# The settled title width decides how long the accent line is.
	wide.spacing_glyph = int(round(title_px * s.tracking_end))
	_line_width = clampf(wide.get_string_size(_data.room_title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x + 8.0 * _unit, 120.0 * _unit, max_width)
	wide.spacing_glyph = int(round(title_px * s.tracking_start))
	var thickness := maxf(2.0 * _unit, 1.0)
	line.position = Vector2(0.0, y)
	line.size = Vector2(_line_width, thickness)
	line.pivot_offset = Vector2.ZERO
	line_tick.size = Vector2(maxf(thickness, 1.0), 16.0 * _unit)
	line_tick.position = Vector2(_line_width - line_tick.size.x, y - 8.0 * _unit + thickness * 0.5)
	y += thickness + gap * 1.1

	role.add_theme_font_size_override("font_size", detail_px)
	role.position = Vector2(0.0, y)
	role.size = Vector2(max_width, detail_h)
	y += detail_h + 6.0 * _unit
	detail.add_theme_font_size_override("font_size", label_px)
	detail.position = Vector2(0.0, y)
	detail.size = Vector2(max_width, small_h)
	y += small_h
	_block_height = y

	vline.position = Vector2(-22.0 * _unit, 2.0 * _unit)
	vline.size = Vector2(maxf(1.0, _unit), _block_height)
	vline.pivot_offset = Vector2.ZERO

	# Footer: sits above the game's own bottom hint strip.
	var marker_px := maxi(int(round(13.0 * _unit)), 10)
	marker.font_size = marker_px
	var marker_text_width := 0.0
	for text: String in [marker.left_text, marker.center_text, marker.right_text]:
		marker_text_width += label_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, marker_px).x
	var footer_width := clampf(maxf(marker_text_width + 64.0 * _unit, 380.0 * _unit), 260.0, max_width)
	coordinates.add_theme_font_size_override("font_size", marker_px)
	coordinates.size = Vector2(footer_width, label_font.get_height(marker_px))
	marker.size = Vector2(footer_width, label_font.get_height(marker_px) + 16.0)
	marker.position = Vector2(0.0, coordinates.size.y + 10.0 * _unit)
	var footer_height := marker.position.y + marker.size.y
	footer.position = Vector2(margin, view.y - footer_height - 108.0 * _unit)
	footer.size = Vector2(footer_width, footer_height)

	# Effects that depend on the screen size.
	sweep.size = Vector2(view.x * 0.34, view.y)
	scan.size = Vector2(view.x, 128.0 * _unit)
	var bar_h := view.y * s.letterbox
	bar_top.size = Vector2(view.x, bar_h)
	bar_bottom.size = Vector2(view.x, bar_h)
	bar_top.position = Vector2(0.0, -bar_h)
	bar_bottom.position = Vector2(0.0, view.y)


## Largest title size at or below wanted whose tracked width fits max_width.
func _fit_title(font: FontVariation, wanted: int, max_width: float, tracking: float) -> int:
	var size_px := maxi(wanted, 16)
	while size_px > 16:
		font.spacing_glyph = int(round(size_px * tracking))
		if font.get_string_size(_data.room_title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x <= max_width:
			break
		size_px -= 2
	return size_px


# --- Animation -----------------------------------------------------------------------------

func _kill_tweens() -> void:
	for t in [_tween, _ambient, _pulse]:
		if t != null and t.is_valid():
			t.kill()
	_tween = null
	_ambient = null
	_pulse = null


## Schedules one property tween at `at` seconds (scaled by speed) on the parallel timeline.
func _at(at: float, object: Object, property: NodePath, to: Variant, duration: float, trans: Tween.TransitionType = Tween.TRANS_CUBIC, ease_mode: Tween.EaseType = Tween.EASE_OUT) -> void:
	_tween.tween_property(object, property, to, duration / _speed).set_delay(at / _speed).set_trans(trans).set_ease(ease_mode)


func _call_at(at: float, callable: Callable) -> void:
	_tween.tween_callback(callable).set_delay(at / _speed)


func _hide_content() -> void:
	for node: CanvasItem in [chapter, title, role, detail, coordinates, line, line_tick, vline, marker]:
		node.modulate.a = 0.0
	ghost_a.modulate.a = 0.0
	ghost_b.modulate.a = 0.0


func _play_full() -> void:
	var s := _style
	var future := _timeline == "future"
	_kill_tweens()
	_hide_content()
	_tween = create_tween().set_parallel(true)

	# Whole-overlay presence.
	_at(0.0, stage, "modulate:a", 1.0, s.overlay_in, Tween.TRANS_SINE, Tween.EASE_OUT)
	_at(s.out_start, stage, "modulate:a", 0.0, s.out_duration, Tween.TRANS_SINE, Tween.EASE_IN_OUT)

	# Chapter label.
	var c := s.chapter_start
	_at(c, chapter, "modulate:a", 1.0, s.chapter_duration, Tween.TRANS_SINE)
	if future:
		chapter.visible_ratio = 0.0
		_at(c, chapter, "visible_ratio", 1.0, s.chapter_duration * 1.4, Tween.TRANS_LINEAR)
	else:
		chapter.position.x = -14.0 * _unit
		_at(c, chapter, "position:x", 0.0, s.chapter_duration * 1.5, Tween.TRANS_CUBIC)

	# Room title.
	var t := s.title_start
	_at(t, title, "modulate:a", 1.0, s.title_duration * 0.6, Tween.TRANS_SINE)
	_at(t, _title_font, "spacing_glyph", int(round(title.get_theme_font_size("font_size") * s.tracking_end)), s.title_duration * 1.3, Tween.TRANS_QUINT)
	if future:
		title_clip.size.x = 0.0
		_at(t, title_clip, "size:x", _clip_width, s.title_duration, Tween.TRANS_QUART)
		_schedule_glitch(t, 0.0)
	else:
		title.position.y = title.size.y * 0.85
		_at(t, title, "position:y", 0.0, s.title_duration * 1.1, Tween.TRANS_QUART)

	# Accent line, decorations, timeline details.
	var a := s.accent_start
	line.scale = Vector2(0.0, 1.0)
	line.modulate.a = 1.0
	_at(a, line, "scale:x", 1.0, s.accent_duration, Tween.TRANS_EXPO)
	if s.interface_lines:
		vline.scale = Vector2(1.0, 0.0)
		vline.modulate.a = 1.0
		_at(a - 0.1, vline, "scale:y", 1.0, s.accent_duration * 1.4, Tween.TRANS_CUBIC)
		_at(a + s.accent_duration * 0.7, line_tick, "modulate:a", 1.0, 0.2, Tween.TRANS_SINE)
	var d := s.detail_start
	role.position.x = -10.0 * _unit
	detail.position.x = -10.0 * _unit
	_at(d, role, "modulate:a", 1.0, s.detail_duration, Tween.TRANS_SINE)
	_at(d, role, "position:x", 0.0, s.detail_duration * 1.4, Tween.TRANS_CUBIC)
	_at(d + 0.12, detail, "modulate:a", 1.0, s.detail_duration, Tween.TRANS_SINE)
	_at(d + 0.12, detail, "position:x", 0.0, s.detail_duration * 1.4, Tween.TRANS_CUBIC)
	_at(d + 0.05, coordinates, "modulate:a", 1.0, s.detail_duration, Tween.TRANS_SINE)
	marker.progress = 0.0
	_at(d + 0.05, marker, "modulate:a", 1.0, s.detail_duration, Tween.TRANS_SINE)
	_at(d + 0.1, marker, "progress", 1.0, s.detail_duration * 2.0, Tween.TRANS_CUBIC)

	# Preset ambience.
	if s.light_sweep:
		sweep.position = Vector2(-sweep.size.x, 0.0)
		_at(0.0, sweep, "modulate:a", 0.22, 0.45, Tween.TRANS_SINE)
		_at(0.0, sweep, "position:x", _viewport_size.x, 1.6, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		_at(1.1, sweep, "modulate:a", 0.0, 0.5, Tween.TRANS_SINE)
	if s.scanline:
		_schedule_scan(0.0, 1.0, 0.9)
		_schedule_scan(s.out_start - 0.1, -1.0, s.out_duration)
	if s.letterbox > 0.0:
		var bar_h := bar_top.size.y
		_at(0.0, bar_top, "position:y", 0.0, s.overlay_in + 0.3, Tween.TRANS_CUBIC)
		_at(0.0, bar_bottom, "position:y", _viewport_size.y - bar_h, s.overlay_in + 0.3, Tween.TRANS_CUBIC)
		_at(s.out_start, bar_top, "position:y", -bar_h, s.out_duration, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
		_at(s.out_start, bar_bottom, "position:y", _viewport_size.y, s.out_duration, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)

	# Audio hooks.
	if s.audio_start != &"":
		_call_at(0.0, audio_cue.emit.bind(s.audio_start))
	if s.audio_title != &"":
		_call_at(t, audio_cue.emit.bind(s.audio_title))
	if s.audio_end != &"":
		_call_at(s.out_start, audio_cue.emit.bind(s.audio_end))

	_call_at(s.total_duration(), _end.bind(true))

	# Secondary motion while the title is readable: a slow drift and a breathing active node.
	_ambient = create_tween()
	_ambient.tween_property(block, "position:x", block.position.x + 10.0 * _unit, s.total_duration() / _speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse = create_tween().set_loops()
	_pulse.tween_property(marker, "pulse", 1.0, 1.1).from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Three decaying offsets, then a clean title. Deterministic and low-contrast: no flashing.
func _schedule_glitch(start: float, _unused: float) -> void:
	var u := _unit
	var steps := [
		[0.0, Vector2(-8.0, 0.0) * u, Vector2(6.0, 1.0) * u, 0.3],
		[0.13, Vector2(5.0, 0.0) * u, Vector2(-3.0, -1.0) * u, 0.24],
		[0.24, Vector2(-2.0, 0.0) * u, Vector2(1.0, 0.0) * u, 0.16],
	]
	for step: Array in steps:
		var at: float = start + step[0]
		_call_at(at, _set_ghosts.bind(step[1], step[2], step[3]))
	_call_at(start + 0.36, _set_ghosts.bind(Vector2.ZERO, Vector2.ZERO, 0.0))


func _set_ghosts(offset_a: Vector2, offset_b: Vector2, alpha: float) -> void:
	ghost_a.position = Vector2(_clip_pad, 0.0) + offset_a
	ghost_b.position = Vector2(_clip_pad, 0.0) + offset_b
	ghost_a.modulate.a = alpha
	ghost_b.modulate.a = alpha * 0.8


## A thin band travelling down (direction 1) or up (-1) the screen.
func _schedule_scan(at: float, direction: float, duration: float) -> void:
	var height := scan.size.y
	var from_y := -height if direction > 0.0 else _viewport_size.y
	var to_y := _viewport_size.y if direction > 0.0 else -height
	_call_at(at, _start_scan.bind(from_y, direction))
	_at(at, scan, "position:y", to_y, duration, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_at(at, scan, "modulate:a", 0.38, duration * 0.3, Tween.TRANS_SINE)
	_at(at + duration * 0.7, scan, "modulate:a", 0.0, duration * 0.3, Tween.TRANS_SINE)


func _start_scan(from_y: float, direction: float) -> void:
	scan.position = Vector2(0.0, from_y)
	scan.flip_v = direction < 0.0


## Reduced motion: the final layout fades in and out. No slides, sweeps, glitches or drift.
func _play_reduced() -> void:
	_kill_tweens()
	_tween = create_tween()
	var hold := maxf(_style.out_start - _style.overlay_in, REDUCED_MIN_HOLD) / _speed
	for node: CanvasItem in [chapter, title, role, detail, coordinates, line, marker]:
		node.modulate.a = 1.0
	line.scale = Vector2.ONE
	marker.progress = 1.0
	marker.pulse = 0.0
	_title_font.spacing_glyph = int(round(title.get_theme_font_size("font_size") * _style.tracking_end))
	_tween.tween_property(stage, "modulate:a", 1.0, REDUCED_FADE_IN / _speed).set_trans(Tween.TRANS_SINE)
	if _style.audio_start != &"":
		_tween.tween_callback(audio_cue.emit.bind(_style.audio_start))
	_tween.tween_interval(hold)
	_tween.tween_property(stage, "modulate:a", 0.0, REDUCED_FADE_OUT / _speed).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(_end.bind(true))


func _end(completed: bool) -> void:
	if _ended:
		return
	_ended = true
	_kill_tweens()
	stage.modulate.a = 0.0
	finished.emit(completed)
