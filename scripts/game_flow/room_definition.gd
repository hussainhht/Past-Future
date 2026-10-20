class_name RoomDefinition
extends Resource
## Data for one playable location. GameFlowManager never hardcodes a room: adding a level means
## adding a RoomDefinition (.tres) and its scene(s). Scene paths are Strings on purpose, so a
## definition does not load the other timeline's scene just by being registered.

const PAST := "past"
const FUTURE := "future"

## Unique, stable ID such as "room_01". This is the only thing sent over the network.
@export var room_id: String = ""
@export var display_name: String = ""
@export_group("Scenes")
## Used for a timeline whose own scene is empty. Set it alone when both timelines share one
## scene that switches presentation by role, as the Signal Laboratory does.
@export_file("*.tscn") var shared_scene: String = ""
@export_file("*.tscn") var past_scene: String = ""
@export_file("*.tscn") var future_scene: String = ""
@export_group("Entry")
## Marker3D the Student (Past) starts at, found by name in the loaded room.
@export var past_spawn_id: StringName = &"past_entry"
## Marker3D the Professor (Future) starts at.
@export var future_spawn_id: StringName = &"future_entry"
@export_group("Departure")
## The room reached by this room's main exit.
@export var next_room_id: String = ""
## Other rooms reachable from here without conditions, such as a way back.
@export var allowed_exits: PackedStringArray = PackedStringArray()
## Puzzles that must be solved before the players may leave through next_room_id.
@export var required_puzzles: PackedStringArray = PackedStringArray()
## Shown when required_puzzles are not solved yet. Falls back to a generic line when empty.
@export var locked_message: String = ""
## When true (the default) both players must confirm before leaving this room.
## Offline games only ever wait for the one local player.
@export var require_both_ready: bool = true


## Scene to load for a timeline: its own scene, otherwise the shared one. Empty if neither is set.
func get_scene_path(role: String) -> String:
	var own := past_scene if role == PAST else future_scene
	return own if not own.is_empty() else shared_scene


func get_spawn_id(role: String) -> StringName:
	return past_spawn_id if role == PAST else future_spawn_id


## Every room that can be requested from here: the main exit first, then allowed_exits.
func get_destinations() -> PackedStringArray:
	var destinations := PackedStringArray()
	if not next_room_id.is_empty():
		destinations.append(next_room_id)
	for exit_id in allowed_exits:
		if not exit_id.is_empty() and not destinations.has(exit_id):
			destinations.append(exit_id)
	return destinations


## Puzzles that gate the given exit. Only the main exit is gated; return links never are.
func get_required_puzzles(destination: String) -> PackedStringArray:
	return required_puzzles if destination == next_room_id else PackedStringArray()


## Problems that make this definition unusable. Empty means it can be registered.
## File existence is not checked here, so a missing scene is reported when the room loads.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if room_id.is_empty():
		problems.append("room_id is empty")
	elif room_id != room_id.strip_edges() or room_id.length() > 64:
		problems.append("room_id '%s' must be at most 64 characters with no surrounding spaces" % room_id)
	for role in [PAST, FUTURE]:
		var path := get_scene_path(role)
		if path.is_empty():
			problems.append("no scene for the %s timeline (set shared_scene or %s_scene)" % [role, role])
		elif not path.begins_with("res://") or not (path.ends_with(".tscn") or path.ends_with(".scn")):
			problems.append("%s scene '%s' must be a res:// .tscn or .scn path" % [role, path])
	if next_room_id == room_id and not room_id.is_empty():
		problems.append("next_room_id points back at this room")
	for puzzle_id in required_puzzles:
		if puzzle_id.is_empty():
			problems.append("required_puzzles contains an empty ID")
	if not required_puzzles.is_empty() and next_room_id.is_empty():
		problems.append("required_puzzles needs a next_room_id to gate")
	return problems


## Scene files that do not exist, for editor checks and tests.
func missing_scenes() -> PackedStringArray:
	var missing := PackedStringArray()
	for role in [PAST, FUTURE]:
		var path := get_scene_path(role)
		if not path.is_empty() and not ResourceLoader.exists(path) and not missing.has(path):
			missing.append(path)
	return missing
