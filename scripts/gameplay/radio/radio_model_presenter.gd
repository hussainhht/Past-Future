extends Node3D
## Attach under any hand/socket. Replace model independently from TemporalRadio logic.

@export var radio: TemporalRadio
@export var model: Node3D


func _ready() -> void:
	if radio != null:
		radio.status_changed.connect(_on_status_changed)
		_on_status_changed(radio.signal_state, radio.owns_radio, radio.presentation_active)


func _on_status_changed(_status: int, owned: bool, active: bool) -> void:
	if is_instance_valid(model):
		model.visible = owned and active
