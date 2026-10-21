class_name ObjectiveConditions
extends RefCounted
## The small, data-driven vocabulary objectives use to say "the game reached this state".
## A condition is a Dictionary with a "kind"; nothing here reads or writes game state except
## through the Context it is given, so rules stay pure and testable.
##
##   flag         {puzzle, path, value?}   state at `path` (dotted) equals value; value defaults to true,
##                                         "*" means any non-empty / true value
##   one_of       {puzzle, path, values}   state at `path` equals any of the listed values
##   at_least     {puzzle, path, order, value}  state at `path` is `value` or any later entry of `order`
##   array_count  {puzzle, path, match, min}    at least `min` entries of the array at `path` contain every
##                                         key of `match` (value "*" = non-empty / true)
##   solved       {puzzle}                 the puzzle is solved
##   journal      {entry}                  this role has discovered the journal entry
##   room         {room}                   the room has been reached this session
##   any          {of}                     any of the nested conditions holds

const KINDS := ["flag", "one_of", "at_least", "array_count", "solved", "journal", "room", "any"]


## What conditions are asked about. ObjectiveManager fills it from the live autoloads; tests may fake it.
class Context:
	extends RefCounted
	var role: String = "past"
	## puzzle_id -> confirmed state Dictionary ({} when the puzzle has none).
	var state_of: Callable = func(_puzzle_id: String) -> Dictionary: return {}
	var solved_of: Callable = func(_puzzle_id: String) -> bool: return false
	## (entry_id, role) -> bool
	var journal_has: Callable = func(_entry_id: String, _role: String) -> bool: return false
	## room_id -> true for every room reached this session.
	var rooms: Dictionary = {}


static func holds(condition: Dictionary, context: Context) -> bool:
	match String(condition.get("kind", "")):
		"flag":
			return _matches(_resolve(_state(condition, context), String(condition.get("path", ""))), condition.get("value", true))
		"one_of":
			var found: Variant = _resolve(_state(condition, context), String(condition.get("path", "")))
			for candidate: Variant in condition.get("values", []):
				if _same(found, candidate):
					return true
			return false
		"at_least":
			var order: Array = condition.get("order", [])
			var have := order.find(_resolve(_state(condition, context), String(condition.get("path", ""))))
			var need := order.find(condition.get("value"))
			return have >= 0 and need >= 0 and have >= need
		"array_count":
			var entries: Variant = _resolve(_state(condition, context), String(condition.get("path", "")))
			if not entries is Array:
				return false
			var count := 0
			for entry: Variant in entries:
				if entry is Dictionary and _contains(entry, condition.get("match", {})):
					count += 1
			return count >= int(condition.get("min", 1))
		"solved":
			return bool(context.solved_of.call(String(condition.get("puzzle", ""))))
		"journal":
			return bool(context.journal_has.call(String(condition.get("entry", "")), context.role))
		"room":
			return context.rooms.has(String(condition.get("room", "")))
		"any":
			for nested: Variant in condition.get("of", []):
				if nested is Dictionary and holds(nested, context):
					return true
			return false
	return false


static func all_hold(conditions: Array, context: Context) -> bool:
	for condition: Dictionary in conditions:
		if not holds(condition, context):
			return false
	return not conditions.is_empty()


static func any_holds(conditions: Array, context: Context) -> bool:
	for condition: Dictionary in conditions:
		if holds(condition, context):
			return true
	return false


## (done, total) over a list of conditions; total is 0 when the list is empty.
static func count(conditions: Array, context: Context) -> Vector2i:
	var done := 0
	for condition: Dictionary in conditions:
		if holds(condition, context):
			done += 1
	return Vector2i(done, conditions.size())


## Problems that make a condition unusable; empty means valid.
static func validate(condition: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	var kind := String(condition.get("kind", ""))
	if not kind in KINDS:
		problems.append("unknown condition kind '%s'" % kind)
		return problems
	var needs: Array = []
	match kind:
		"flag": needs = ["puzzle", "path"]
		"one_of": needs = ["puzzle", "path", "values"]
		"at_least": needs = ["puzzle", "path", "order", "value"]
		"array_count": needs = ["puzzle", "path", "match", "min"]
		"solved": needs = ["puzzle"]
		"journal": needs = ["entry"]
		"room": needs = ["room"]
		"any": needs = ["of"]
	for key: String in needs:
		if not condition.has(key):
			problems.append("%s condition needs '%s'" % [kind, key])
	if kind == "at_least" and condition.has("order") and condition.has("value") and not (condition.order as Array).has(condition.value):
		problems.append("at_least value is not in its order list")
	if kind == "any":
		for nested: Variant in condition.get("of", []):
			if nested is Dictionary:
				problems.append_array(validate(nested))
			else:
				problems.append("any needs condition Dictionaries")
	return problems


## Rooms that can be proven reached from confirmed puzzle state, for a peer that joined or
## reconnected after the players had already moved on. `reached` holds the rooms seen directly.
static func derive_rooms(reached: Dictionary, context: Context) -> Dictionary:
	var rooms := reached.duplicate()
	var corridor: Dictionary = context.state_of.call("puzzle_02_maintenance")
	# Only progress that can happen inside the corridor proves it was reached. Walking into the
	# laboratory door (arrived_*) happens before the players have actually left.
	if corridor.get("service_isolated", false) == true or corridor.get("battery_ready", false) == true:
		rooms["room_02"] = true
	# The reactor's state exists from the moment its rules are registered (and again after every new
	# session), so only a stage beyond the idle one proves the players got there.
	var reactor: Dictionary = context.state_of.call("puzzle_03_final_fracture")
	if reactor.has("stage") and reactor.stage != "DISCOVERY":
		rooms["room_03"] = true
	# Later rooms imply the earlier ones were passed through.
	if rooms.has("room_03"):
		rooms["room_02"] = true
	if rooms.has("room_02"):
		rooms["room_01"] = true
	return rooms


static func _state(condition: Dictionary, context: Context) -> Dictionary:
	return context.state_of.call(String(condition.get("puzzle", "")))


static func _resolve(root: Variant, path: String) -> Variant:
	var current: Variant = root
	if path.is_empty():
		return current
	for key in path.split("."):
		if current is Dictionary and (current as Dictionary).has(key):
			current = current[key]
		elif current is Array and key.is_valid_int() and int(key) >= 0 and int(key) < (current as Array).size():
			current = current[int(key)]
		else:
			return null
	return current


static func _matches(found: Variant, wanted: Variant) -> bool:
	if typeof(wanted) == TYPE_STRING and wanted == "*":
		match typeof(found):
			TYPE_NIL: return false
			TYPE_BOOL: return found
			TYPE_STRING: return not (found as String).is_empty()
			TYPE_ARRAY: return not (found as Array).is_empty()
			TYPE_DICTIONARY: return not (found as Dictionary).is_empty()
			_: return true
	return _same(found, wanted)


static func _same(a: Variant, b: Variant) -> bool:
	if a == null or b == null:
		return a == null and b == null
	# Replicated numbers may arrive as int or float; compare by value, not by type.
	if (typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT) and (typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT):
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b


static func _contains(entry: Dictionary, wanted: Dictionary) -> bool:
	for key: Variant in wanted:
		if not entry.has(key) or not _matches(entry[key], wanted[key]):
			return false
	return true
