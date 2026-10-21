extends Control
## Accelerated clock hands and drifting dust. All artwork uses native 2D rendering.

@export_range(1.0, 120.0, 1.0) var minute_hand_revolution_seconds: float = 30.0

var motion_enabled: bool = true
var elapsed: float = 0.0


func _process(delta: float) -> void:
	if motion_enabled:
		elapsed += delta
		queue_redraw()


func _draw() -> void:
	var center := Vector2(1120, 420)
	for index in range(60):
		var angle := TAU * float(index) / 60.0 - PI / 2.0
		var direction := Vector2.from_angle(angle)
		var major := index % 5 == 0
		var color := Color("bda780") if index < 30 else Color("7bb9bf")
		color.a = 0.50 if major else 0.19
		draw_line(center + direction * (178.0 if major else 185.0), center + direction * 191.0, color, 1.5, true)
	var clock_angle := -elapsed * TAU / minute_hand_revolution_seconds
	var hour_angle := -PI * 0.72 + clock_angle / 12.0
	var minute_angle := -PI * 0.16 + clock_angle
	draw_line(center, center + Vector2.from_angle(hour_angle) * 102.0, Color("c4ad85"), 3.0, true)
	draw_line(center, center + Vector2.from_angle(minute_angle) * 149.0, Color("78b9bf"), 2.0, true)
	draw_circle(center, 6.0, Color("a8b9ae"), false, 1.5, true)
	draw_circle(center, 2.0, Color("d4d1b2"), true, -1.0, true)
	for index in range(38):
		var seed_value := float(index)
		var x := fposmod(seed_value * 173.17 + sin(elapsed * 0.12 + seed_value) * 14.0, 1600.0)
		var y := fposmod(seed_value * 97.73 - elapsed * (2.0 + fmod(seed_value, 4.0)), 900.0)
		var color := Color("d7b583") if x < 800.0 else Color("81c9d1")
		color.a = 0.12 + (sin(elapsed * 0.6 + seed_value) + 1.0) * 0.09
		draw_circle(Vector2(x, y), 1.0 + fmod(seed_value, 2.0) * 0.6, color, true, -1.0, true)
