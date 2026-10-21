class_name RoomIntroData
extends Resource
## What a room introduction says. One resource per room in resources/cinematic/rooms/.
## Presentation (colours, motion) comes from the RoomIntroStyle chosen for the viewer's timeline.

## The GameFlowManager room ID this introduction belongs to ("room_01").
@export var room_id: String = ""
@export var chapter_label: String = "CHAPTER 0"
@export var chapter_title: String = ""
@export var room_title: String = ""
## Shown as "TEMPORAL COORDINATES / 01".
@export var location_index: int = 1
## Preset for each timeline. `finale` is the heavier preset meant for the last room.
@export var past_preset: StringName = &"past_memory"
@export var future_preset: StringName = &"future_signal"


func get_preset(timeline: String) -> StringName:
	return future_preset if timeline == "future" else past_preset


func validate() -> String:
	if room_id.strip_edges().is_empty() or room_id != room_id.strip_edges():
		return "room_id must be a non-empty ID without padding."
	if room_title.strip_edges().is_empty():
		return "room_title must not be empty."
	return ""
