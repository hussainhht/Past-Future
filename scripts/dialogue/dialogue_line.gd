class_name DialogueLine
extends Resource
## One line of dialogue. Pure data: DialogueDirector decides when it plays and DialogueBox decides
## how it looks, so a whole conversation can be written in the Inspector without touching code.
##
## The text is BBCode, so [i]emphasis[/i] works. Use [lb] for a literal "[".

## Where a speaker, or a whole conversation, lives in time. BOTH is for voices heard across the rift.
enum Timeline { PAST, FUTURE, BOTH }

## Optional and unique within its sequence. Lets notes and other systems point at this exact line.
@export var line_id: String = ""
## Stable identifier of who speaks, such as "student" or "professor". Never shown to the player.
@export var speaker_id: String = ""
## The name the player sees. It may hide the real identity, for example "Unknown Voice".
@export var speaker_name: String = ""
@export_multiline var text: String = ""
## The speaker's timeline. It chooses the accent colour of the dialogue box.
@export var timeline: Timeline = Timeline.PAST
## Optional. Without a portrait the portrait area is hidden and takes no space.
@export var portrait: Texture2D
## Characters per second for this line. 0 uses the sequence's speed.
@export_range(0.0, 300.0, 1.0, "or_greater") var typing_speed: float = 0.0
## Optional narrative event, announced through DialogueDirector.narrative_event_requested when the line starts.
@export var event_id: String = ""
## Optional voice clip, played when the line starts. Reserved for future voice acting.
@export var voice: AudioStream


## Lines without text are never shown. Whitespace alone does not count as text.
func has_text() -> bool:
	return not text.strip_edges().is_empty()


## Lowercase name of a timeline: "past", "future" or "both".
static func timeline_name(value: Timeline) -> String:
	match value:
		Timeline.PAST:
			return "past"
		Timeline.FUTURE:
			return "future"
	return "both"


## Problems that would make this line misbehave, as readable sentences. Empty when it is fine.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if not has_text():
		problems.append("has no text, so it will be skipped")
	if typing_speed < 0.0:
		problems.append("typing_speed must not be negative")
	return problems
