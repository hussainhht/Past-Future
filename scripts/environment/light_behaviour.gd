extends Light3D
## Gives a light some life: a steady glow, a slow pulse (temporal energy), or a failing flicker
## (emergency lights). Each instance takes its own phase from its position, so a row of broken
## lights never blinks in unison. Energy varies around base_energy, which starts as the energy
## authored on the light; scripts that drive a light's brightness set base_energy instead.

enum Mode { STEADY, PULSE, FLICKER }

@export var mode: Mode = Mode.STEADY:
	set(value):
		mode = value
		if is_node_ready():
			set_process(mode != Mode.STEADY)
			light_energy = base_energy
## Pulse: cycles per second. Flicker: how often the light tries to come back.
@export var speed: float = 1.0
## Fraction of the authored energy that varies (0..1).
@export var depth: float = 0.35

var base_energy: float = 1.0:
	set(value):
		base_energy = value
		if mode == Mode.STEADY:
			light_energy = value
var _phase: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	base_energy = light_energy
	_phase = fposmod(global_position.x * 3.17 + global_position.z * 7.31, 97.0)
	set_process(mode != Mode.STEADY)


func _process(delta: float) -> void:
	_time += delta
	match mode:
		Mode.PULSE:
			light_energy = base_energy * (1.0 - depth * 0.5 + depth * 0.5 * sin((_time + _phase) * TAU * speed))
		Mode.FLICKER:
			var t := (_time + _phase) * speed * 6.0
			var dropout := 1.0 if fmod(t, 7.3) > 0.55 and sin(t * 1.7) > -0.82 else 0.08
			light_energy = base_energy * dropout * (1.0 - depth + depth * (0.5 + 0.5 * sin(t * 23.0)))
