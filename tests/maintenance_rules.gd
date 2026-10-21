extends SceneTree
const Rules = preload("res://scripts/puzzles/implementations/maintenance_corridor_puzzle.gd")
const Frequency = preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
var puzzles: Node
var failures := 0
var checks := 0
var completions := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func state() -> Dictionary: return puzzles.get_state(Rules.ID)
func act(action: String, role: String, payload: Dictionary = {}) -> Dictionary:
	return puzzles.submit_action(Rules.ID, action, payload, role)
func fresh() -> void:
	puzzles.begin_session()
	puzzles.submit_action(Frequency.ID, "acquire_radio", {"radio_role": "past"}, "past")
	puzzles.submit_action(Frequency.ID, "acquire_radio", {"radio_role": "future"}, "future")
	puzzles.submit_action(Frequency.ID, "tune_frequency", {"frequency": 67}, "past")
func fix_bypass() -> void:
	act("repair_bypass", "past")
	act("repair_bypass", "future")
func run() -> void:
	puzzles = root.get_node("PuzzleManager")
	puzzles.log_rejections = false
	puzzles.register_puzzle(Frequency.ID, Frequency.new())
	puzzles.register_puzzle(Rules.ID, Rules.new())
	check(act("arrive", "past").status == puzzles.Status.REJECTED, "Travel requires the actual radio link")
	puzzles.puzzle_completed.connect(func(id: String) -> void:
		if id == Rules.ID: completions += 1)
	for priority in ["shared", "past", "future"]:
		for recording in ["preserved", "erased"]:
			fresh()
			var frequency: Dictionary = puzzles.get_state(Frequency.ID)
			act("arrive", "past")
			check(not Rules.both_arrived(state()), "One arrival cannot claim both peers")
			act("arrive", "future")
			check(Rules.both_arrived(state()), "Both authenticated arrivals persist")
			check(act("isolate_service", "future").status == puzzles.Status.REJECTED, "Future cannot operate Past isolator")
			check(act("arrive", "future", {"role": "past"}).status == puzzles.Status.REJECTED, "Forged arrival fields are refused")
			act("isolate_service", "past")
			check(act("reserve_power", "past").status == puzzles.Status.REJECTED, "Reserve cost must be disclosed before allocation")
			if priority != "shared":
				act("read_reserve_note", priority)
				act("reserve_power", priority)
				var other: String = "past" if priority == "future" else "future"
				check(Rules.has_power(state(), priority) and not Rules.has_power(state(), other), "Reserve benefits the claimant and interrupts the remote feed")
				act("read_reserve_note", other)
				check(act("reserve_power", other).status == puzzles.Status.REJECTED, "A concurrent second claimant cannot overwrite the allocation")
			else: act("charge_battery", "future")
			check(act("set_support", "future", {"support": "circle", "stage": 3}).status == puzzles.Status.REJECTED, "Client role cannot stage supports")
			check(act("set_support", "past", {"support": "circle", "stage": true}).status == puzzles.Status.REJECTED, "Boolean stages are refused")
			check(act("set_support", "past", {"support": "square", "stage": 9}).status == puzzles.Status.REJECTED, "Out-of-range stages are refused")
			if not Rules.has_power(state(), "past"): fix_bypass()
			var revision: int = puzzles.get_revision(Rules.ID)
			check(act("apply_supports", "past").status == puzzles.Status.NO_CHANGE, "Unsafe plan does not move the slab")
			check(puzzles.get_revision(Rules.ID) == revision and not state().supports_secured, "Unsafe plan does not commit progression")
			for support in {"circle": 3, "triangle": 2, "square": 1}:
				act("set_support", "past", {"support": support, "stage": {"circle": 3, "triangle": 2, "square": 1}[support]})
			act("apply_supports", "past")
			check(state().supports_secured, "A valid plan secures the crossing")
			check(act("set_support", "past", {"support": "circle", "stage": 1}).status == puzzles.Status.REJECTED, "Secured bridge cannot be retracted under the Professor")
			if not Rules.has_power(state(), "future"): fix_bypass()
			act("read_archive", "future")
			if recording == "preserved":
				if not Rules.bypass_ready(state()):
					check(act("preserve_recording", "future").status == puzzles.Status.REJECTED, "Preservation needs the isolated supply")
				fix_bypass()
				act("preserve_recording", "future")
			else:
				act("extract_cell", "future")
				check(state().recording == "erased", "Cell extraction permanently resolves evidence")
				act("release_door", "future")
				check(state().future_release_open and not state().core_authorized, "Extracted cell opens the Future door independently")
				check(act("preserve_recording", "future").status == puzzles.Status.REJECTED, "Erased evidence cannot be recreated")
			fix_bypass()
			check(Rules.has_power(state(), "past") and Rules.has_power(state(), "future"), "Both sides can recover after either private choice")
			check(state().priority == priority and state().recording == recording, "Repairs do not erase the history of choices")
			revision = puzzles.get_revision(Rules.ID)
			check(act("authorize_core", "past", {"code": "0000"}).status == puzzles.Status.NO_CHANGE and puzzles.get_revision(Rules.ID) == revision, "Wrong access code cannot advance state")
			act("authorize_core", "past", {"code": "3142"})
			act("release_door", "future")
			act("arm_anchor", "future")
			check(not puzzles.is_solved(Rules.ID), "One anchor cannot finish the chapter")
			act("arm_anchor", "past")
			check(puzzles.is_solved(Rules.ID), "Both roles finish every branch")
			var completed_before := completions
			act("arm_anchor", "past")
			check(completions == completed_before, "Repeated actions cannot repeat completion")
			check(puzzles.get_state(Frequency.ID) == frequency, "Level 01 link and radio ownership are untouched")
	print("MAINTENANCE RULES: %s (%d checks; %d failures; six complete branches)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
