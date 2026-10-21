extends Control
## Live oscilloscope used by the physical console and the standalone Future reader.
const Rules := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const CURRENT := Color("7dffad")
const TARGET := Color("929b9f")
var state: Dictionary = {}
var show_target := true
var target_frequency := Rules.DEFAULT_FREQUENCY
var target_amplitude := Rules.DEFAULT_AMPLITUDE


func set_signal(value: Dictionary, future: bool) -> void:
	state = value
	show_target = future
	queue_redraw()


func wave_points(frequency: int, amplitude: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var plot := Rect2(32, 151, size.x - 64, size.y - 243)
	for index in 721:
		var x := float(index) / 720.0
		# Frequency controls cycle spacing; amplitude controls height about the shared zero line.
		var y := sin(x * TAU * (1.0 + float(frequency) / 25.0)) * float(amplitude) / 100.0
		points.append(Vector2(plot.position.x + x * plot.size.x, plot.get_center().y - y * plot.size.y * 0.46))
	return points


func _draw() -> void:
	if size.x < 100 or size.y < 220: return
	var font := ThemeDB.fallback_font
	var frequency: int = state.get("current_frequency", Rules.INITIAL_FREQUENCY)
	var amplitude: int = state.get("current_amplitude", Rules.INITIAL_AMPLITUDE)
	draw_rect(Rect2(Vector2.ZERO, size), Color("081b20"))
	draw_string(font, Vector2(30, 45), "LIVE RECEIVER" if show_target else "PAST TRANSMITTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color("b8d8d6"))
	draw_string(font, Vector2(30, 91), "CURRENT  %03d MHz  /  %02d%%" % [frequency, amplitude], HORIZONTAL_ALIGNMENT_LEFT, -1, 36, CURRENT)
	if show_target:
		draw_string(font, Vector2(30, 134), "TARGET    %03d MHz  /  %02d%%" % [target_frequency, target_amplitude], HORIZONTAL_ALIGNMENT_LEFT, -1, 36, TARGET)
	var plot := Rect2(32, 151, size.x - 64, size.y - 243)
	for index in 13:
		var x := plot.position.x + plot.size.x * float(index) / 12.0
		draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), Color("18383e"), 1)
	for index in 7:
		var y := plot.position.y + plot.size.y * float(index) / 6.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color("29464b") if index == 3 else Color("18383e"), 1)
	if show_target:
		draw_polyline(wave_points(target_frequency, target_amplitude), TARGET, 7.0, true)
	draw_polyline(wave_points(frequency, amplitude), CURRENT, 4.5, true)
	var message := "MATCH FREQUENCY + AMPLITUDE" if show_target else "TWO DIALS / LIVE TRANSMISSION"
	if Rules.link_established(state): message = "MATCHED / LINK ESTABLISHED"
	elif not Rules.radios_ready(state): message = "WAITING FOR BOTH RADIOS"
	draw_string(font, Vector2(30, size.y - 49), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 29, CURRENT if Rules.link_established(state) else Color("b8d8d6"))
	draw_string(font, Vector2(30, size.y - 17), "GREEN: CURRENT    GREY: TARGET" if show_target else "PAST CONTROLS / FUTURE OBSERVES", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, TARGET)
