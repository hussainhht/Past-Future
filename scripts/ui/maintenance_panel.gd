extends "res://scripts/ui/lab_ui.gd"
## Device controls belong to the equipment; the overlay supplies clearly separated player help.

const Inspector = preload("res://scripts/gameplay/devices/device_inspector_3d.gd")
signal action_selected(action: String, payload: Dictionary)
var code_text := ""
var inspector: Node
var device_mount: Node3D
var device_bindings: Dictionary = {}
var camera: Camera3D
var actor: Node3D


func _ready() -> void:
	super._ready()
	inspector = Inspector.new()
	inspector.name = "DeviceInspector"
	add_child(inspector)
	inspector.action_requested.connect(func(action: String, payload: Dictionary) -> void: action_selected.emit(action, payload))
	inspector.active_changed.connect(func(open: bool) -> void:
		if not open: set_control_hint("")
		modal_changed.emit(open))
	inspector.entry_changed.connect(func(text: String) -> void: code_text = text)


func open_device(title: String, body: String, actions: Array, code_entry: bool = false) -> void:
	if code_entry: inspector.entry = code_text
	inspector.open_device(device_mount, camera, actor, title, body, actions, device_bindings, "code" if code_entry else "", future)
	var controls := "Click a physical control. "
	if code_entry: controls += "Number keys also press the keypad; Enter submits."
	else:
		for index in actions.size(): controls += "%d: %s. " % [index + 1, actions[index].label]
	set_control_hint(controls + "\nEsc / F: step back.")


func is_modal_open() -> bool:
	return (inspector != null and inspector.active) or super.is_modal_open()


func modal_kind() -> String:
	return "physical_device" if inspector != null and inspector.active else super.modal_kind()


func close_modal() -> void:
	if inspector != null: inspector.close()
	super.close_modal()
	set_control_hint("")
