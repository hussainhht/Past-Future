class_name ObjectiveDefinition
extends Resource
## One task in a player's mission log. Author these as .tres files under resources/objectives/<role>/;
## ObjectiveManager picks them up by folder scan, so a new objective never needs a code change.
##
## Completion is never scripted per objective. `conditions` describe facts about confirmed game
## state (see ObjectiveConditions for the kinds) and the manager evaluates them whenever that state
## changes, so an objective can only complete because the game really reached that state.

## Unique across every objective, e.g. "student_l1_find_radio".
@export var objective_id: String = ""
## The timeline this objective belongs to: "past" (Student) or "future" (Professor).
@export_enum("past", "future") var role: String = "past"
## Room ID of the chapter the objective belongs to ("room_01"). The chapter name is the room's name.
@export var chapter: String = ""
## Chapters run in this order (1, 2, 3). Objectives inside a chapter run in sort_order.
@export var chapter_order: int = 1
@export var sort_order: int = 0

@export_group("Text")
@export var title: String = ""
## One short sentence for the compact HUD card. Falls back to the description when empty.
@export var summary: String = ""
## What to do, in one or two sentences. Never a solution, a code, or the other player's knowledge.
@export_multiline var description: String = ""
## Optional nudge shown only while the objective is current.
@export_multiline var hint: String = ""
## Glyph from ObjectiveIcon (radio, terminal, dial, power, tools, door, core, document, link, vault, key).
@export var icon: StringName = &"document"
## A secret objective is shown as "Undiscovered Objective" until it becomes the current one.
## Use it for steps that would spoil a hidden story event by their name alone.
@export var secret: bool = false

@export_group("Rules")
## ALL of these must hold for the objective to complete. See ObjectiveConditions.
@export var conditions: Array[Dictionary] = []
## Optional: when ANY of these holds first, the objective is no longer relevant and is dropped
## without being completed (for example, reading a log the puzzle no longer needs).
@export var expires: Array[Dictionary] = []
## Optional: shown as "n / m" while current. Each entry is a condition; progress counts those that hold.
@export var progress: Array[Dictionary] = []
## Optional puzzle ID. When that puzzle starts a new attempt (a reset), this objective is forgotten
## so a repeated attempt is tracked from the beginning.
@export var attempt_puzzle: String = ""


## Problems that make this definition unusable. Empty means it can be registered.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if objective_id.is_empty():
		problems.append("objective_id is empty")
	if not role in ["past", "future"]:
		problems.append("role must be past or future")
	if chapter.is_empty():
		problems.append("chapter is empty")
	if title.is_empty():
		problems.append("title is empty")
	if description.is_empty():
		problems.append("description is empty")
	if conditions.is_empty():
		problems.append("an objective needs at least one completion condition")
	for list: Array in [conditions, expires, progress]:
		for condition: Dictionary in list:
			problems.append_array(ObjectiveConditions.validate(condition))
	return problems
