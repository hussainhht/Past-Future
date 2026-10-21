class_name ObjectiveIcon
extends Control
## A small line-art glyph drawn in code, so objectives need no art files. `kind` picks the glyph:
## objective glyphs (radio, terminal, dial, power, tools, door, core, document, link, vault, key)
## and status glyphs (check, lock, current, upcoming, book). Everything is drawn inside the control's
## square and scales with it.

@export var kind: StringName = &"document":
	set(value):
		kind = value
		queue_redraw()
@export var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func _init(icon_kind: StringName = &"document", icon_color: Color = Color.WHITE, icon_size: float = 28.0) -> void:
	kind = icon_kind
	color = icon_color
	custom_minimum_size = Vector2(icon_size, icon_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 0.0:
		return
	var origin := (size - Vector2(side, side)) * 0.5
	var w := maxf(1.5, side / 15.0)
	var fine := Color(color, color.a * 0.55)
	# p() maps a 0..1 point into the square.
	var p := func(x: float, y: float) -> Vector2: return origin + Vector2(x, y) * side
	var line := func(a: Vector2, b: Vector2, c: Color = color, width: float = w) -> void:
		draw_line(a, b, c, width, true)
	match kind:
		&"radio":
			draw_rect(Rect2(p.call(0.18, 0.34), Vector2(0.64, 0.5) * side), color, false, w)
			line.call(p.call(0.62, 0.34), p.call(0.82, 0.08))
			draw_arc(p.call(0.4, 0.59), side * 0.13, 0.0, TAU, 20, color, w, true)
			line.call(p.call(0.64, 0.5), p.call(0.74, 0.5), fine)
			line.call(p.call(0.64, 0.62), p.call(0.74, 0.62), fine)
		&"terminal":
			draw_rect(Rect2(p.call(0.1, 0.16), Vector2(0.8, 0.54) * side), color, false, w)
			line.call(p.call(0.2, 0.3), p.call(0.32, 0.4))
			line.call(p.call(0.32, 0.4), p.call(0.2, 0.5))
			line.call(p.call(0.4, 0.52), p.call(0.58, 0.52), fine)
			line.call(p.call(0.38, 0.88), p.call(0.62, 0.88))
			line.call(p.call(0.5, 0.7), p.call(0.5, 0.88))
		&"dial":
			draw_arc(p.call(0.5, 0.5), side * 0.38, 0.0, TAU, 32, color, w, true)
			line.call(p.call(0.5, 0.5), p.call(0.72, 0.3))
			for tick in 5:
				var angle := deg_to_rad(-210.0 + tick * 60.0)
				var direction := Vector2(cos(angle), sin(angle))
				line.call(p.call(0.5, 0.5) + direction * side * 0.3, p.call(0.5, 0.5) + direction * side * 0.38, fine, w * 0.8)
		&"power":
			draw_polyline(PackedVector2Array([p.call(0.58, 0.06), p.call(0.28, 0.54), p.call(0.5, 0.54), p.call(0.42, 0.94), p.call(0.74, 0.4), p.call(0.52, 0.4), p.call(0.58, 0.06)]), color, w, true)
		&"tools":
			draw_arc(p.call(0.5, 0.5), side * 0.22, 0.0, TAU, 24, color, w, true)
			for tooth in 8:
				var angle := tooth * TAU / 8.0
				var direction := Vector2(cos(angle), sin(angle))
				line.call(p.call(0.5, 0.5) + direction * side * 0.22, p.call(0.5, 0.5) + direction * side * 0.38)
			draw_circle(p.call(0.5, 0.5), side * 0.06, fine)
		&"door":
			draw_rect(Rect2(p.call(0.24, 0.1), Vector2(0.52, 0.8) * side), color, false, w)
			draw_circle(p.call(0.64, 0.52), side * 0.04, color)
			line.call(p.call(0.1, 0.9), p.call(0.9, 0.9), fine)
		&"core":
			draw_arc(p.call(0.5, 0.5), side * 0.4, 0.0, TAU, 32, color, w, true)
			draw_arc(p.call(0.5, 0.5), side * 0.24, 0.0, TAU, 24, fine, w, true)
			draw_circle(p.call(0.5, 0.5), side * 0.08, color)
		&"document":
			draw_polyline(PackedVector2Array([p.call(0.22, 0.08), p.call(0.62, 0.08), p.call(0.8, 0.26), p.call(0.8, 0.92), p.call(0.22, 0.92), p.call(0.22, 0.08)]), color, w, true)
			for row in 3:
				line.call(p.call(0.34, 0.4 + row * 0.16), p.call(0.68, 0.4 + row * 0.16), fine)
		&"link":
			draw_arc(p.call(0.34, 0.5), side * 0.24, 0.0, TAU, 24, color, w, true)
			draw_arc(p.call(0.66, 0.5), side * 0.24, 0.0, TAU, 24, color, w, true)
		&"vault":
			draw_rect(Rect2(p.call(0.12, 0.14), Vector2(0.76, 0.72) * side), color, false, w)
			line.call(p.call(0.12, 0.38), p.call(0.88, 0.38), fine)
			line.call(p.call(0.5, 0.5), p.call(0.5, 0.76))
			line.call(p.call(0.38, 0.64), p.call(0.5, 0.76))
			line.call(p.call(0.62, 0.64), p.call(0.5, 0.76))
		&"key":
			draw_arc(p.call(0.3, 0.5), side * 0.17, 0.0, TAU, 20, color, w, true)
			line.call(p.call(0.47, 0.5), p.call(0.92, 0.5))
			line.call(p.call(0.74, 0.5), p.call(0.74, 0.66))
			line.call(p.call(0.88, 0.5), p.call(0.88, 0.62))
		&"check":
			draw_polyline(PackedVector2Array([p.call(0.2, 0.54), p.call(0.42, 0.74), p.call(0.82, 0.28)]), color, w * 1.5, true)
		&"lock":
			draw_rect(Rect2(p.call(0.22, 0.46), Vector2(0.56, 0.42) * side), color, false, w)
			draw_arc(p.call(0.5, 0.46), side * 0.17, PI, TAU, 14, color, w, true)
			draw_circle(p.call(0.5, 0.66), side * 0.05, color)
		&"current":
			draw_arc(p.call(0.5, 0.5), side * 0.38, 0.0, TAU, 32, color, w, true)
			draw_circle(p.call(0.5, 0.5), side * 0.17, color)
		&"upcoming":
			draw_arc(p.call(0.5, 0.5), side * 0.3, 0.0, TAU, 28, color, w, true)
		&"book":
			draw_polyline(PackedVector2Array([p.call(0.1, 0.22), p.call(0.46, 0.3), p.call(0.46, 0.84), p.call(0.1, 0.76), p.call(0.1, 0.22)]), color, w, true)
			draw_polyline(PackedVector2Array([p.call(0.9, 0.22), p.call(0.54, 0.3), p.call(0.54, 0.84), p.call(0.9, 0.76), p.call(0.9, 0.22)]), color, w, true)
		_:
			draw_arc(p.call(0.5, 0.5), side * 0.3, 0.0, TAU, 28, color, w, true)
