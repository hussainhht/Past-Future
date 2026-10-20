class_name JournalEntry
extends Resource
## One page of the shared journal. Author these as .tres files under resources/journal/<role>/;
## JournalManager picks them up by folder scan, so a new document never needs a code change.

enum Category { NOTES, DOCUMENTS, CLUES }
enum Timeline { BOTH, PAST, FUTURE }

## Unique across every entry, e.g. "future_frequency_log".
@export var entry_id: String = ""
@export var title: String = "Untitled"
## Optional short line under the title (a date, a source).
@export var subtitle: String = ""
## Page text. BBCode is allowed ([b], [i], [color=...]).
@export_multiline var body: String = ""
@export var category: Category = Category.NOTES
## Whose journal this belongs to. Only the matching local player can unlock it.
@export var timeline: Timeline = Timeline.PAST
@export var image: Texture2D
## Lower numbers come first inside a category.
@export var sort_order: int = 0
## Optional: unlocked automatically when this puzzle is completed (a confirmed shared event).
@export var unlock_on_puzzle: String = ""


func allows_role(role: String) -> bool:
	match timeline:
		Timeline.PAST:
			return role == "past"
		Timeline.FUTURE:
			return role == "future"
	return true
