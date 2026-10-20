extends Control
## Modal lifetime and input lock. Releases the exact actor on close or room unload.

const UI := preload("res://scripts/gameplay/frequency/frequency_ui.gd")

signal modal_changed(open: bool)
signal audio_cue_requested(cue: StringName)

var content: VBoxContainer
var _actor: Node
var _controller: Node
var _was_controls_enabled: bool = true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.05, 0.83)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 580
	panel.add_theme_stylebox_override("panel", UI.panel())
	center.add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)
	PuzzleManager.session_ended.connect(close)
	hide()


func open_for(actor: Node, _role: String = "") -> bool:
	if visible:
		return true
	# Only one frequency modal owns the actor's controls at a time.
	if not get_tree().get_nodes_in_group("frequency_modal_open").is_empty():
		return false
	_actor = actor
	if is_instance_valid(_actor):
		_was_controls_enabled = bool(_actor.get("controls_enabled"))
		_actor.set("controls_enabled", false)
		_controller = _actor.find_child("InteractionController", true, false)
		if is_instance_valid(_controller):
			_controller.set_interaction_blocked(true)
	add_to_group("frequency_modal_open")
	show()
	modal_changed.emit(true)
	return true


func close() -> void:
	if not visible:
		return
	hide()
	_release_actor()
	remove_from_group("frequency_modal_open")
	modal_changed.emit(false)


func _release_actor() -> void:
	if is_instance_valid(_actor):
		_actor.set("controls_enabled", _was_controls_enabled)
	if is_instance_valid(_controller):
		_controller.set_interaction_blocked(false)
	_actor = null
	_controller = null


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_release_actor()
