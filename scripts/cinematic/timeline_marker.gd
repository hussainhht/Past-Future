class_name TimelineMarker
extends Control
## "I / PAST ---- 31 YEARS APART ---- II / FUTURE": two nodes on a thin line, the viewer's
## timeline lit. `progress` draws the line in, `pulse` breathes the active node's ring.
## Pure drawing; the overlay owns every value.

var font: Font
var font_size: int = 14
var text_color: Color = Color.WHITE
var dim_color: Color = Color(1, 1, 1, 0.5)
var line_color: Color = Color.WHITE
var active_index: int = 0
var left_text: String = "I / PAST"
var center_text: String = "31 YEARS APART"
var right_text: String = "II / FUTURE"

var progress: float = 1.0:
	set(value):
		progress = value
		queue_redraw()
var pulse: float = 0.0:
	set(value):
		pulse = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if font == null:
		return
	var w := size.x
	var row := font.get_ascent(font_size)
	var y := row + font.get_descent(font_size) + 10.0
	var left_color := text_color if active_index == 0 else dim_color
	var right_color := text_color if active_index == 1 else dim_color
	draw_string(font, Vector2(0, row), left_text, HORIZONTAL_ALIGNMENT_LEFT, w, font_size, left_color)
	# The centre label sits in the gap between the two end labels, whatever their widths.
	var left_end := font.get_string_size(left_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var right_start := w - font.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var gap_width := right_start - left_end
	draw_string(font, Vector2(left_end, row), center_text, HORIZONTAL_ALIGNMENT_CENTER, gap_width, font_size, dim_color)
	draw_string(font, Vector2(0, row), right_text, HORIZONTAL_ALIGNMENT_RIGHT, w, font_size, right_color)
	var a := Vector2(4.0, y)
	var b := Vector2(w - 4.0, y)
	var faint := Color(line_color, line_color.a * 0.5)
	draw_line(a, a.lerp(b, progress), faint, 1.0)
	for i in range(2):
		var p := a if i == 0 else b
		var lit := i == active_index
		var radius := 3.5 if lit else 2.5
		draw_circle(p, radius, line_color if lit else Color(line_color, 0.45))
		if lit:
			draw_arc(p, 6.0 + 4.0 * pulse, 0.0, TAU, 28, Color(line_color, 0.55 * (1.0 - pulse)), 1.0, true)
