extends RefCounted
const ID := "puzzle_02_maintenance"
static func repair(puzzles: Node) -> void:
	if preload("res://scripts/gameplay/storage/storage_rules.gd").repaired(puzzles.get_state(ID)): return
	puzzles.submit_action(ID, "read_manifest", {}, "future")
	var items := ["r17", "k04", "m22"]
	var parts := ["reader", "regulator", "memory"]
	for index in 3:
		puzzles.submit_action(ID, "pickup_storage_item", {"item": items[index]}, "past")
		puzzles.submit_action(ID, "place_storage_item", {"bay": index}, "past")
		puzzles.submit_action(ID, "seal_bay", {"bay": index}, "past")
		puzzles.submit_action(ID, "raise_storage_tray", {"bay": index}, "future")
		puzzles.submit_action(ID, "retrieve_storage_item", {"bay": index}, "future")
		puzzles.submit_action(ID, "install_component", {"part": parts[index]}, "future")
