extends RefCounted
## Stable Room B completion adapter. Room B must declare room_03 as its next room.

static func enter_temporal_core() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null: return "no_session"
	var puzzles := tree.root.get_node("PuzzleManager")
	var flow := tree.root.get_node("GameFlowManager")
	if not puzzles.is_authority(): return "not_authority"
	if flow.get_current_room_id() != "room_02": return "not_adjacent"
	return flow.begin_transition("room_03")
