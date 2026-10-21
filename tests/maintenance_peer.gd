extends SceneTree
const Rules = preload("res://scripts/puzzles/implementations/maintenance_corridor_puzzle.gd")
const Frequency = preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
var puzzles: Node
var network: Node
var failures := 0
var who := ""
var rejected: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func wait_for(predicate: Callable, message: String, seconds: float = 18) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call():
		if Time.get_ticks_msec() > deadline:
			check(false, message)
			return false
		await process_frame
	return true
func state() -> Dictionary: return puzzles.get_state(Rules.ID)
func is_corridor() -> bool: return is_instance_valid(current_scene) and current_scene.scene_file_path == Rules.DESTINATION and current_scene.is_node_ready()
func act(action: String, payload: Dictionary = {}) -> Dictionary: return puzzles.submit_action(Rules.ID, action, payload)
func run() -> void:
	network = root.get_node("NetworkManager")
	puzzles = root.get_node("PuzzleManager")
	puzzles.log_rejections = false
	var args := OS.get_cmdline_user_args()
	who = args[0]
	var port := int(args[1])
	puzzles.action_rejected.connect(func(id: String, _action: String, reason: String, _role: String) -> void:
		if id == Rules.ID: rejected.append(reason))
	network.game_started.connect(func() -> void: change_scene_to_file.call_deferred("res://scenes/world/spawn_area.tscn"))
	if who == "host":
		check(network.host_game(port) == OK, "Host must bind the LAN port")
		if not await wait_for(func() -> bool: return network.guest_ready, "Client did not become ready"):
			await finish()
			return
		network.start_game()
	else:
		check(network.join_game("127.0.0.1", port) == OK, "Client must start joining")
		if not await wait_for(func() -> bool: return network.state == network.State.CONNECTED, "Client did not connect"):
			await finish()
			return
		network.set_ready(true)
	if not await wait_for(func() -> bool: return is_instance_valid(current_scene) and current_scene.has_node("SignalLab") and current_scene.is_node_ready() and puzzles.has_state(Frequency.ID), "The real laboratory never loaded"):
		await finish()
		return
	current_scene.pause_when_unfocused = false
	current_scene.gameplay.close_overlays()
	current_scene._set_paused(false)
	var role: String = "past" if who == "host" else "future"
	puzzles.submit_action(Frequency.ID, "acquire_radio", {"radio_role": role})
	if who == "host":
		if not await wait_for(func() -> bool: return Frequency.radios_ready(puzzles.get_state(Frequency.ID)), "Both radio acquisitions must arrive before tuning"):
			await finish()
			return
		puzzles.submit_action(Frequency.ID, "tune_frequency", {"frequency":67})
		puzzles.submit_action(Frequency.ID, "tune_amplitude", {"amplitude":70})
	if not await wait_for(func() -> bool: return puzzles.is_solved(Frequency.ID), "Radio prerequisite never completed"):
		await finish()
		return
	current_scene.gameplay.close_overlays()
	current_scene.gameplay.get_node("StudentDiscovery").enabled = false
	current_scene.gameplay.get_node("FutureDiscovery").enabled = false
	var session: int = puzzles.get_session_id()
	if who == "client":
		if not await wait_for(func() -> bool: return state().get("arrived_past", false), "Host did not reach the gallery entrance"):
			await finish()
			return
		check(not is_corridor(), "One arrival must not move the client into Level 02")
	current_scene._on_laboratory_exit(current_scene.player)
	if not await wait_for(is_corridor, "Both arrivals did not transition to Level 02"):
		await finish()
		return
	if not await wait_for(func() -> bool: return not root.get_node("GameFlowManager").is_transitioning(), "Gallery transition did not finish"):
		await finish()
		return
	var room = current_scene
	room.pause_when_unfocused = false
	check(room.role == role and room.radio.owns_radio, "Correct character and radio must survive LAN travel")
	check(puzzles.get_session_id() == session and puzzles.is_solved(Frequency.ID), "Travel cannot restart the network/puzzle session")
	if who == "host":
		act("isolate_service")
		if not await wait_for(func() -> bool: return state().priority == "future" and state().bypass_future, "Future did not reserve power and repair their lead"):
			await finish()
			return
		check(not Rules.has_power(state(), "past"), "Future's private reserve must interrupt the host's feed")
		act("repair_bypass")
		act("pickup_storage_item", {"item": "v09"})
		act("place_storage_item", {"bay": 0})
		act("seal_bay", {"bay": 0})
		if not await wait_for(func() -> bool: return state().storage.future_hand == "v09", "Future never retrieved the wrong equipment"):
			await finish()
			return
		act("seal_bay", {"bay": 1}) # Empty-bay seal acknowledges the retrieval without test-only state.
		if not await wait_for(func() -> bool: return state().storage.future_hand.is_empty(), "Future did not return the wrong equipment"):
			await finish()
			return
		act("unseal_bay", {"bay": 0})
		act("remove_storage_item", {"bay": 0})
		act("drop_storage_item", {"position": Rules.Storage.ITEMS.v09.home})
		act("unseal_bay", {"bay": 1})
		for index in 3:
			act("pickup_storage_item", {"item": ["r17", "k04", "m22"][index]})
			act("place_storage_item", {"bay": index})
			act("seal_bay", {"bay": index})
		if not await wait_for(func() -> bool: return state().recording == "erased" and state().future_release_open, "The recorder/early release branch never arrived"):
			await finish()
			return
		act("authorize_core", {"code":"3142"})
		act("arm_anchor")
	else:
		if not await wait_for(func() -> bool: return state().service_isolated, "Service isolation was not replicated"):
			await finish()
			return
		var before: int = puzzles.get_revision(Rules.ID)
		var result: Dictionary = puzzles.submit_action(Rules.ID, "pickup_storage_item", {"item":"r17"}, "past")
		check(result.status == puzzles.Status.PENDING and puzzles.get_revision(Rules.ID) == before, "Client requests must not mutate optimistically, even with a forged Past role")
		if not await wait_for(func() -> bool: return "role_not_allowed" in rejected, "Host did not refuse forged client role"):
			await finish()
			return
		check(state().storage.past_hand.is_empty(), "Forged request must leave the Student inventory unchanged")
		act("read_reserve_note")
		if not await wait_for(func() -> bool: return state().briefed_future, "Private briefing was not confirmed"):
			await finish()
			return
		act("reserve_power")
		act("repair_bypass")
		if not await wait_for(func() -> bool: return state().battery_ready, "Restored power was not replicated"):
			await finish()
			return
		act("read_manifest")
		if not await wait_for(func() -> bool: return state().storage.manifest_read, "Manifest was not confirmed"):
			await finish()
			return
		if not await wait_for(func() -> bool: return state().storage.bays[0].sealed, "Wrong case never reached Future"):
			await finish()
			return
		act("raise_storage_tray", {"bay": 0})
		if not await wait_for(func() -> bool: return state().storage.bays[0].raised, "Computer recall was not confirmed"):
			await finish()
			return
		puzzles.request_sync()
		await create_timer(.1).timeout
		check(state().storage.bays[0].raised, "A full network snapshot retains the recalled tray position")
		act("retrieve_storage_item", {"bay": 0})
		if not await wait_for(func() -> bool: return state().storage.future_hand == "v09" and state().storage.bays[1].sealed, "Host did not acknowledge wrong-case retrieval"):
			await finish()
			return
		act("install_component", {"part": "reader"})
		act("return_storage_item", {"bay": 0})
		if not await wait_for(func() -> bool: return state().storage.bays[0].item == "r17", "Past did not replace the wrong case"):
			await finish()
			return
		check(state().storage.installed.reader.is_empty(), "Wrong equipment cannot repair a terminal socket")
		for index in 3:
			if not await wait_for(func() -> bool: return state().storage.bays[index].sealed, "Independent storage bay was not sealed"):
				await finish()
				return
			act("raise_storage_tray", {"bay": index})
			if not await wait_for(func() -> bool: return state().storage.bays[index].raised, "Independent lift recall was not confirmed"):
				await finish()
				return
			var storage_revision: int = puzzles.get_revision(Rules.ID)
			var retrieval := act("retrieve_storage_item", {"bay": index})
			check(retrieval.status == puzzles.Status.PENDING and puzzles.get_revision(Rules.ID) == storage_revision, "Retrieval waits for host confirmation")
			if not await wait_for(func() -> bool: return not state().storage.future_hand.is_empty(), "Preserved item did not arrive"):
				await finish()
				return
			var part: String = ["reader", "regulator", "memory"][index]
			act("install_component", {"part": part})
			if not await wait_for(func() -> bool: return not state().storage.installed[part].is_empty(), "Component installation was not replicated"):
				await finish()
				return
		act("read_archive")
		if not await wait_for(func() -> bool: return state().archive_read, "Archive was not confirmed"):
			await finish()
			return
		act("extract_cell")
		if not await wait_for(func() -> bool: return state().recording == "erased", "Cell extraction was not confirmed"):
			await finish()
			return
		act("release_door")
		if not await wait_for(func() -> bool: return state().core_authorized, "Host did not authorize the Core"):
			await finish()
			return
		act("arm_anchor")
	if not await wait_for(func() -> bool: return puzzles.is_solved(Rules.ID), "Chapter did not complete on both peers"):
		await finish()
		return
	var final_state := state()
	if who == "client":
		puzzles.request_sync()
		await create_timer(.3).timeout
		check(state() == final_state, "Full snapshot must preserve choices and completion")
		room.queue_free()
		await process_frame
		change_scene_to_file(Rules.DESTINATION)
		await process_frame
		await process_frame
		check(is_corridor() and state() == final_state, "Client room reload must restore the storage progress and evidence branch")
	else:
		await create_timer(1.4).timeout
	finish()
func finish() -> void:
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
		await process_frame
	network.leave_game()
	await create_timer(.2).timeout
	print("MAINTENANCE LAN %s: %s (%d failures)" % [who, "PASS" if failures==0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
