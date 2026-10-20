extends LabDevice
## Auxiliary breaker for receiver bank B, on the north wall left of the console. Not part of the
## puzzle: in the Past the breaker is stable; in the Future it tripped long ago and still sparks, and
## the console runs on its emergency cell, which is just enough to read the recovered log.

const LEVER_UP := 0.0
const LEVER_DOWN := 1.9

@onready var lever: Node3D = find_child("Lever", true, false)
@onready var sparks: CPUParticles3D = $Sparks


func _show_state(_animate: bool) -> void:
	paint(find_mesh("LedPower"), "led_off" if future else "led_go")
	paint(find_mesh("LedFault"), "led_red" if future else "led_off")
	if lever != null:
		lever.rotation.x = LEVER_DOWN if future else LEVER_UP
	sparks.emitting = future


func _on_interacted(_actor: Node, _role: String, _interactable: Node) -> void:
	if future:
		toast("Breaker B tripped years ago and the lever is fused. The console still runs on its emergency cell.")
		sfx(&"interaction_denied", Vector3(0, 0.6, 0.25))
	else:
		toast("Breaker B: stable. Someone labelled it \"RECEIVER  ·  DO NOT CUT\".")
		sfx(&"switch_toggle", Vector3(0, 0.6, 0.25))
