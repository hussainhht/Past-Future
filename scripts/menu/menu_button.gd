extends Button
## Menu button with a restrained "temporal instrument" feel.
##
## Every colour, font and metric comes from the menu theme (resources/ui/menu_theme.tres) through the
## PrimaryButton / SecondaryButton / TertiaryButton type variations, so set `theme_type_variation` and
## the look follows. This script only does two things the theme cannot: it eases between the rest and
## lit looks (hover or keyboard focus), and it draws the hairline details on top (dial ticks, index
## mark, arrow, focus brackets). Nothing runs between interactions: no _process, only short tweens.

## Mirrors the hover chevron so a Back button points the way it will go.
@export var points_back := false

const LIT_IN := 0.18
const LIT_OUT := 0.24
const PRESS_OUT := 0.12
const FONT_ITEMS: Array[StringName] = [
	&"font_color", &"font_hover_color", &"font_focus_color", &"font_hover_pressed_color",
]

var _hover := 0.0: set = _set_hover
var _focus := 0.0: set = _set_focus
var _press := 0.0: set = _set_press
var _hovering := false
var _focused := false
var _was_disabled := false
var _tween: Tween

var _rest: StyleBoxFlat
var _lit: StyleBoxFlat
var _down: StyleBoxFlat
var _live: StyleBoxFlat
var _live_down: StyleBoxFlat
var _font_rest: Color
var _font_lit: Color
var _nudge := 0.0


func _init() -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT


func _ready() -> void:
	_capture_theme()
	mouse_entered.connect(func() -> void: _set_lit(true, _focused))
	mouse_exited.connect(func() -> void: _set_lit(false, _focused))
	focus_entered.connect(func() -> void: _set_lit(_hovering, true))
	focus_exited.connect(func() -> void: _set_lit(_hovering, false))
	button_down.connect(func() -> void: _press = 1.0)
	button_up.connect(_release)
	_was_disabled = disabled
	_apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW:
		_draw_details()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready():
		_resync()


func _type() -> StringName:
	return theme_type_variation if theme_type_variation != &"" else &"Button"


## Reads the variation's rest/lit/pressed looks once and installs per-button copies of the styleboxes
## that the tween can recolour. Explicitly passing the type keeps overrides we installed out of the lookup.
func _capture_theme() -> void:
	var type := _type()
	_rest = _flat(&"normal", type)
	_lit = _flat(&"hover", type)
	_down = _flat(&"pressed", type)
	_font_rest = get_theme_color(&"font_color", type)
	_font_lit = get_theme_color(&"font_hover_color", type)
	_nudge = float(get_theme_constant(&"nudge", type)) if alignment == HORIZONTAL_ALIGNMENT_LEFT else 0.0
	_live = _rest.duplicate()
	_live_down = _down.duplicate()
	add_theme_stylebox_override(&"normal", _live)
	add_theme_stylebox_override(&"hover", _live)
	add_theme_stylebox_override(&"pressed", _live_down)
	if toggle_mode:
		# A toggle's "pressed" is its on-state, not a click: the plate stays the same either way.
		add_theme_stylebox_override(&"pressed", _live)
		add_theme_stylebox_override(&"hover_pressed", _live)


func _flat(item: StringName, type: StringName) -> StyleBoxFlat:
	var box := get_theme_stylebox(item, type) as StyleBoxFlat
	return box if box != null else StyleBoxFlat.new()


func _set_hover(value: float) -> void:
	_hover = value
	_apply()


func _set_focus(value: float) -> void:
	_focus = value
	_apply()


func _set_press(value: float) -> void:
	_press = value
	queue_redraw()


func _set_lit(hovering: bool, focused: bool) -> void:
	_hovering = hovering and not disabled
	_focused = focused and not disabled
	var to_hover := 1.0 if _hovering else 0.0
	var to_focus := 1.0 if _focused else 0.0
	if is_equal_approx(to_hover, _hover) and is_equal_approx(to_focus, _focus):
		return
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_hover", to_hover, LIT_IN if _hovering else LIT_OUT)
	_tween.tween_property(self, "_focus", to_focus, LIT_IN if _focused else LIT_OUT)


func _release() -> void:
	if _press > 0.0:
		create_tween().tween_property(self, "_press", 0.0, PRESS_OUT)


## Disabled or hidden buttons do not get exit events, so re-read the real state when that changes.
func _resync() -> void:
	_hovering = is_hovered() and not disabled and is_visible_in_tree()
	_focused = has_focus() and not disabled and is_visible_in_tree()
	if _tween:
		_tween.kill()
	_hover = 1.0 if _hovering else 0.0
	_focus = 1.0 if _focused else 0.0
	_press = 0.0


func _apply() -> void:
	if _live == null:
		return
	var t := maxf(_hover, _focus)
	_live.bg_color = _rest.bg_color.lerp(_lit.bg_color, t)
	_live.border_color = _rest.border_color.lerp(_lit.border_color, t)
	_live.shadow_color = _rest.shadow_color.lerp(_lit.shadow_color, t)
	# Left margin grows while the right shrinks, so the text slides without changing the minimum size.
	_live.content_margin_left = _rest.content_margin_left + _nudge * t
	_live.content_margin_right = _rest.content_margin_right - _nudge * t
	_live_down.content_margin_left = _down.content_margin_left + _nudge
	_live_down.content_margin_right = _down.content_margin_right - _nudge
	var ink := _font_rest.lerp(_font_lit, t)
	for item in FONT_ITEMS:
		add_theme_color_override(item, ink)
	queue_redraw()


func _draw_details() -> void:
	if disabled != _was_disabled:
		_was_disabled = disabled
		_resync.call_deferred()  # restyling is not safe in the middle of a draw
	if disabled:
		return
	var type := _type()
	var lit := maxf(_hover, _focus)
	var w := size.x
	var h := size.y
	var cy := h * 0.5 + _press

	var light := get_theme_color(&"bevel_light_color", type)
	var shade := get_theme_color(&"bevel_shade_color", type)
	if light.a > 0.0:
		draw_line(Vector2(2.0, 1.5), Vector2(w - 2.0, 1.5), light, 1.0)
	if shade.a > 0.0:
		draw_line(Vector2(2.0, h - 1.5), Vector2(w - 2.0, h - 1.5), shade, 1.0)

	var tick_color := get_theme_color(&"tick_color", type)
	if tick_color.a > 0.0:
		_draw_scale(tick_color, lit)

	var index_color := get_theme_color(&"index_color", type)
	var index_rest := float(get_theme_constant(&"index_rest", type))
	var index_lit := float(get_theme_constant(&"index_lit", type))
	var index_h := lerpf(index_rest, index_lit, lit)
	if index_h > 0.0 and index_color.a > 0.0:
		var bar := index_color
		bar.a *= 1.0 if index_rest > 0.0 else lit
		draw_rect(Rect2(0.0, (h - index_h) * 0.5, 3.0, index_h), bar)

	_draw_indicator(type, lit, w, cy)

	if _focus > 0.0:
		_draw_brackets(get_theme_color(&"focus_color", type))


## A fine dial scale along the bottom edge, echoing the clock's minute marks (every fifth is longer).
## It fades out toward the arrow so it reads as a gauge rather than a ruler.
func _draw_scale(color: Color, lit: float) -> void:
	var pad := float(get_theme_constant(&"tick_inset", _type()))
	var span := size.x - pad * 2.0 - 56.0
	if span <= 0.0:
		return
	var x := pad
	var index := 0
	while x <= pad + span:
		var major := index % 5 == 0
		var tint := color
		tint.a *= (1.5 if major else 1.0) * (1.0 - 0.85 * (x - pad) / span) * (1.0 + 0.6 * lit)
		var length := 6.0 if major else 3.5
		draw_line(Vector2(x, size.y - 10.0), Vector2(x, size.y - 10.0 - length), tint, 1.0)
		x += 6.0
		index += 1


func _draw_indicator(type: StringName, lit: float, w: float, cy: float) -> void:
	var color := get_theme_color(&"arrow_color", type)
	match get_theme_constant(&"indicator", type):
		1:  # Long arrow, always visible; reaches forward when lit.
			var tip := w - float(get_theme_constant(&"indicator_inset", type)) + 4.0 * lit
			var shaft := 16.0 + 6.0 * lit
			draw_line(Vector2(tip - shaft, cy), Vector2(tip, cy), color, 1.5, true)
			draw_polyline(PackedVector2Array([Vector2(tip - 5.5, cy - 4.5), Vector2(tip, cy), Vector2(tip - 5.5, cy + 4.5)]), color, 1.5, true)
		2:  # Chevron that slides into place when lit (mirrored for Back buttons).
			color.a *= lit
			var edge := w - float(get_theme_constant(&"indicator_inset", type))
			var slide := 5.0 * (1.0 - lit)
			if points_back:
				var tip := edge - 4.5 + slide
				draw_polyline(PackedVector2Array([Vector2(tip + 4.5, cy - 4.5), Vector2(tip, cy), Vector2(tip + 4.5, cy + 4.5)]), color, 1.5, true)
			else:
				var tip := edge - slide
				draw_polyline(PackedVector2Array([Vector2(tip - 4.5, cy - 4.5), Vector2(tip, cy), Vector2(tip - 4.5, cy + 4.5)]), color, 1.5, true)
		3:  # Short leading dash that draws out in the left gutter.
			color.a *= lit
			var start := float(get_theme_constant(&"indicator_inset", type))
			draw_line(Vector2(start, cy), Vector2(start + 12.0 * lit, cy), color, 1.5, true)


## Four corner brackets that settle in around the button, like a viewfinder locking on.
func _draw_brackets(color: Color) -> void:
	var gap := lerpf(9.0, 4.0, _focus)
	var arm := 8.0
	color.a *= _focus
	var left := -gap
	var top := -gap
	var right := size.x + gap
	var bottom := size.y + gap
	draw_polyline(PackedVector2Array([Vector2(left, top + arm), Vector2(left, top), Vector2(left + arm, top)]), color, 1.5)
	draw_polyline(PackedVector2Array([Vector2(right - arm, top), Vector2(right, top), Vector2(right, top + arm)]), color, 1.5)
	draw_polyline(PackedVector2Array([Vector2(right, bottom - arm), Vector2(right, bottom), Vector2(right - arm, bottom)]), color, 1.5)
	draw_polyline(PackedVector2Array([Vector2(left + arm, bottom), Vector2(left, bottom), Vector2(left, bottom - arm)]), color, 1.5)
