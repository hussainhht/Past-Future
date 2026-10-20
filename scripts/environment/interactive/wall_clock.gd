extends TimelineProp
## North-wall clock. In the Past it keeps the local time; in the Future it stopped at 23:44, the
## minute the core containment failed, and the cracked face hangs slightly crooked.

const STOPPED := Vector3i(23, 44, 12)

@onready var hour_hand: Node3D = find_child("HourHand", true, false)
@onready var minute_hand: Node3D = find_child("MinuteHand", true, false)
@onready var second_hand: Node3D = find_child("SecondHand", true, false)


func _process(_delta: float) -> void:
	if future:
		_set_time(STOPPED.x, STOPPED.y, float(STOPPED.z))
	else:
		var now := Time.get_time_dict_from_system()
		_set_time(now.hour, now.minute, float(now.second))


func _set_time(hours: int, minutes: int, seconds: float) -> void:
	if hour_hand == null:
		return
	# Hands are drawn pointing up (+Y); rotating about -Z turns them clockwise on the dial.
	hour_hand.rotation.z = -TAU * (fmod(hours, 12.0) + minutes / 60.0) / 12.0
	minute_hand.rotation.z = -TAU * (minutes + seconds / 60.0) / 60.0
	second_hand.rotation.z = -TAU * floorf(seconds) / 60.0
