extends LabDevice
## The north security door, the room's exit. Its lock is slaved to the signal array: it stays sealed
## until Puzzle 01 establishes the temporal radio link, then the leaf slides into the wall pocket in
## both timelines, smoothly in the Past and in grinding jerks in the Future, where the servo is
## thirty years older. The door only presents confirmed state; the puzzle itself has no door rule.
## The leaf's collision moves with it, and the corridor's ExitZone reports a player leaving the room.

signal player_exited(body: Node3D)

const SLIDE := 2.08
const PAST_TIME := 1.6
const FUTURE_TIME := 2.6

var is_open: bool = false
var opening: bool = false

@onready var leaf: Node3D = $Leaf
@onready var inspect: Interactable3D = $Inspect
@onready var exit_zone: Area3D = $ExitZone

var _leaf_closed: Vector3
var _tween: Tween


func _ready() -> void:
	_leaf_closed = $Leaf.position
	super()
	exit_zone.body_entered.connect(_on_exit_body_entered)


func _state_changed(previous: Dictionary) -> void:
	if linked() and not Rules.link_established(previous) and not previous.is_empty():
		open(true)


func _show_state(_animate: bool) -> void:
	var unlocked := linked()
	if unlocked and not is_open and not opening:
		open(false)
	elif not unlocked and (is_open or opening):
		close()
	paint(find_mesh("StatusLight"), "led_go" if unlocked else "led_red")
	inspect.interaction_name = "Inspect open door" if unlocked else "Inspect sealed door"
	var lamp := $Corridor.find_child("Lamp", true, false) as Node3D
	if lamp:
		lamp.visible = unlocked or not future
	# The corridor light only spills into the room once the leaf is out of the way.
	$CorridorLight.visible = unlocked
	$FutureOnly/FrameSparks.emitting = future and not unlocked


## Slide the leaf open. animate = false snaps it (state loaded after the door already opened).
func open(animate: bool) -> void:
	if is_open or opening:
		return
	if _tween:
		_tween.kill()
	var target := _leaf_closed + Vector3(SLIDE, 0, 0)
	if not animate:
		leaf.position = target
		is_open = true
		return
	opening = true
	sfx(&"door_open", Vector3(0, 1.5, 0.3))
	_tween = create_tween()
	if future:
		# Three stuck-and-released jerks with a shudder between them.
		for step in [0.3, 0.62, 1.0]:
			_tween.tween_property(leaf, "position", _leaf_closed + Vector3(SLIDE * step, 0, 0), FUTURE_TIME / 3.0 * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.tween_property(leaf, "position:y", 0.03, 0.06)
			_tween.tween_property(leaf, "position:y", _leaf_closed.y, 0.08)
			_tween.tween_interval(FUTURE_TIME / 3.0 * 0.25)
	else:
		_tween.tween_property(leaf, "position", target, PAST_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func() -> void:
		opening = false
		is_open = true
	)


## Back to sealed, for puzzle resets.
func close() -> void:
	if is_open or opening:
		sfx(&"door_close", Vector3(0, 1.5, 0.3))
	if _tween:
		_tween.kill()
	leaf.position = _leaf_closed
	is_open = false
	opening = false


func _on_interacted(_actor: Node, _role: String, _interactable: Node) -> void:
	if linked():
		toast("The seal is released. The corridor beyond leads out of the laboratory.")
		sfx(&"computer_beep", Vector3(0, 1.5, 0.3))
		return
	if future:
		toast("SEALED. Scorched hinges, but the lock still holds. It answers only to the signal array.")
	else:
		toast("SEALED. A note on the frame: \"Lock slaved to the array. Releases on a stable temporal link.\"")
	sfx(&"door_locked", Vector3(0, 1.5, 0.3))


func _on_exit_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and is_open:
		player_exited.emit(body)
