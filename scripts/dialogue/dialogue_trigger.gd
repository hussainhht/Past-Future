class_name DialogueTrigger
extends Node
## Turns "something happened" into a dialogue request, so gameplay scripts never need to know about
## dialogue. Point it at any signal (a puzzle completing, an interaction, a cutscene ending) or call
## trigger() from code. It only asks: the DialogueDirector decides whether the conversation plays,
## using the local timeline, the play-once history and its queue.
##
## Example: a sequence that follows PuzzleManager's confirmed completion of "power_switch":
##   sequence = res://resources/dialogue/samples/puzzle_completed.tres
##   source = /root/PuzzleManager, source_signal = puzzle_completed,
##   argument_index = 0, argument_value = power_switch

## Largest number of arguments a watched signal may declare.
const MAX_SIGNAL_ARGUMENTS := 8

## The conversation to request.
@export var sequence: DialogueSequence
## Node that owns the signal, relative to this node or absolute. An autoload is /root/PuzzleManager.
@export var source: NodePath
## Signal to listen for, for example puzzle_completed.
@export var source_signal: StringName
## Only react when this argument of the signal equals `argument_value`. -1 reacts to every emission.
@export var argument_index: int = -1
## The expected argument, compared as text. For puzzle_completed(puzzle_id), the puzzle's ID.
@export var argument_value: String = ""
## Director to ask. Left empty, the first one in the "dialogue_director" group is used.
@export var director: NodePath
## Request the sequence as soon as this node is ready, once the whole scene has loaded.
@export var trigger_on_ready: bool = false
## A disabled trigger ignores signals and trigger() calls.
@export var enabled: bool = true

## Warn about misconfiguration (no director, unknown signal). On in debug builds only.
var log_problems: bool = OS.is_debug_build()

var _source_node: Node
var _source_arity: int = 0


func _ready() -> void:
	if not source_signal.is_empty():
		connect_source()
	if trigger_on_ready:
		trigger.call_deferred()


## Ask the director to play the sequence. Returns whether it was accepted, playing or queued.
## `context` is passed on to DialogueDirector.play_dialogue().
func trigger(context: Dictionary = {}) -> bool:
	if not enabled or sequence == null:
		return false
	var target := get_director()
	if target == null:
		_warn("No DialogueDirector to play '%s'. Add dialogue_system.tscn to the scene." % sequence.sequence_id)
		return false
	return target.play_dialogue(sequence, context)


func get_director() -> DialogueDirector:
	if not director.is_empty():
		return get_node_or_null(director) as DialogueDirector
	if is_inside_tree():
		return get_tree().get_first_node_in_group(DialogueDirector.GROUP) as DialogueDirector
	return null


## Start listening to `source_signal`. Called for you from _ready(); call it again after changing the
## source in code. Returns false, with a warning, when the node or signal cannot be used.
func connect_source() -> bool:
	disconnect_source()
	_source_node = get_node_or_null(source)
	if _source_node == null:
		_warn("Source '%s' was not found." % source)
		return false
	var declared := _find_signal(_source_node, source_signal)
	if declared.is_empty():
		_warn("'%s' has no signal '%s'." % [_source_node.name, source_signal])
		_source_node = null
		return false
	_source_arity = declared.args.size()
	if _source_arity > MAX_SIGNAL_ARGUMENTS:
		_warn("Signal '%s' has %d arguments; at most %d are supported." % [source_signal, _source_arity, MAX_SIGNAL_ARGUMENTS])
		_source_node = null
		return false
	if argument_index >= _source_arity:
		_warn("Signal '%s' has no argument %d to filter on." % [source_signal, argument_index])
	_source_node.connect(source_signal, _on_source_signal)
	return true


func disconnect_source() -> void:
	if is_instance_valid(_source_node) and _source_node.is_connected(source_signal, _on_source_signal):
		_source_node.disconnect(source_signal, _on_source_signal)
	_source_node = null


func is_listening() -> bool:
	return is_instance_valid(_source_node)


## Optional parameters let one handler serve a signal with any number of arguments.
func _on_source_signal(a0: Variant = null, a1: Variant = null, a2: Variant = null, a3: Variant = null, a4: Variant = null, a5: Variant = null, a6: Variant = null, a7: Variant = null) -> void:
	if argument_index >= 0:
		var arguments := [a0, a1, a2, a3, a4, a5, a6, a7]
		if argument_index >= _source_arity or str(arguments[argument_index]) != argument_value:
			return
	trigger()


func _find_signal(node: Object, signal_name: StringName) -> Dictionary:
	for declared in node.get_signal_list():
		if declared.name == signal_name:
			return declared
	return {}


func _warn(message: String) -> void:
	if log_problems:
		push_warning("[DialogueTrigger] " + message)
