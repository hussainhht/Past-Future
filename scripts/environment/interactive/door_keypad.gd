extends LabDevice
## Keypad beside the security door. It cannot open the door itself (the lock is slaved to the
## signal array and releases on Puzzle 01's temporal link), but it reports the lock state, presses
## its buttons, and goes green on release.

@onready var display: Label3D = $Display

var _pressing: bool = false


func _show_state(_animate: bool) -> void:
	var unlocked := linked()
	paint(find_mesh("StatusLed"), "led_go" if unlocked else "led_red")
	if unlocked:
		display.text = "OPEN"
		display.modulate = Color("8dffb8")
	elif future:
		display.text = "LOCK  ERR"
		display.modulate = Color("ff7a5c")
	else:
		display.text = "SEALED"
		display.modulate = Color("ffcf7a")
	$Interactable.interaction_name = "Check keypad"


func _on_interacted(_actor: Node, _role: String, _interactable: Node) -> void:
	_press_sequence()
	if linked():
		toast("OPEN. I heard the seal release when the carrier settled.")
		sfx(&"computer_beep", Vector3(0, 0.4, 0.1))
	elif future:
		toast("LOCK ERR. The little plate says the array has to hold a stable link before this seal releases.")
		sfx(&"interaction_denied", Vector3(0, 0.4, 0.1))
	else:
		toast("ACCESS DENIED. This plate says the seal is wired to the array. A code won't do it.")
		sfx(&"interaction_denied", Vector3(0, 0.4, 0.1))


func _press_sequence() -> void:
	if _pressing:
		return
	_pressing = true
	var tween := create_tween()
	for index in [1, 4, 2, 8, 11]:
		var button := find_child("Button_%d" % index, true, false) as Node3D
		if button == null:
			continue
		var rest := button.position
		tween.tween_callback(sfx.bind(&"keypad_button", Vector3(0, 0.4, 0.1)))
		tween.tween_property(button, "position:z", rest.z - 0.018, 0.05)
		tween.tween_property(button, "position:z", rest.z, 0.07)
	tween.tween_callback(func() -> void: _pressing = false)
