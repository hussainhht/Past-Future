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
		if not await wait_for(func() -> bool: return network.guest_ready, "Client did not become ready"): return finish()
		network.start_game()
	else:
		check(network.join_game("127.0.0.1", port) == OK, "Client must start joining")
		if not await wait_for(func() -> bool: return network.state == network.State.CONNECTED, "Client did not connect"): return finish()
		network.set_ready(true)
	if not await wait_for(func() -> bool: return is_instance_valid(current_scene) and current_scene.has_node("SignalLab") and current_scene.is_node_ready() and puzzles.has_state(Frequency.ID), "The real laboratory never loaded"): return finish()
	current_scene.pause_when_unfocused = false
	current_scene.gameplay.close_overlays()
	current_scene._set_paused(false)
	var role: String = "past" if who == "host" else "future"
	puzzles.submit_action(Frequency.ID, "acquire_radio", {"radio_role": role})
	if who == "host": puzzles.submit_action(Frequency.ID, "tune_frequency", {"frequency":67})
	if not await wait_for(func() -> bool: return puzzles.is_solved(Frequency.ID), "Radio prerequisite never completed"): return finish()
	current_scene.gameplay.close_overlays()
	current_scene.gameplay.get_node("StudentDiscovery").enabled = false
	current_scene.gameplay.get_node("FutureDiscovery").enabled = false
	var session: int = puzzles.get_session_id()
	if who == "client":
		if not await wait_for(func() -> bool: return state().get("arrived_past", false), "Host did not reach the gallery entrance"): return finish()
		check(not is_corridor(), "One arrival must not move the client into Level 02")
	current_scene._on_laboratory_exit(current_scene.player)
	if not await wait_for(is_corridor, "Both arrivals did not transition to Level 02"): return finish()
	if not await wait_for(func() -> bool: return not root.get_node("GameFlowManager").is_transitioning(), "Gallery transition did not finish"): return finish()
	var room = current_scene
	room.pause_when_unfocused = false
	check(room.role == role and room.radio.owns_radio, "Correct character and radio must survive LAN travel")
	check(puzzles.get_session_id() == session and puzzles.is_solved(Frequency.ID), "Travel cannot restart the network/puzzle session")
	if who == "host":
		act("isolate_service")
		if not await wait_for(func() -> bool: return state().priority == "future" and state().bypass_future, "Future did not reserve power and repair their lead"): return finish()
		check(not Rules.has_power(state(), "past"), "Future's private reserve must interrupt the host's feed")
		act("repair_bypass")
		for support in {"circle":3,"triangle":2,"square":1}:
			act("set_support", {"support":support,"stage":{"circle":3,"triangle":2,"square":1}[support]})
		act("apply_supports")
		if not await wait_for(func() -> bool: return state().recording == "erased" and state().future_release_open, "The recorder/early release branch never arrived"): return finish()
		act("authorize_core", {"code":"3142"})
		act("arm_anchor")
	else:
		if not await wait_for(func() -> bool: return state().service_isolated, "Service isolation was not replicated"): return finish()
		var before: int = puzzles.get_revision(Rules.ID)
		var result: Dictionary = puzzles.submit_action(Rules.ID, "set_support", {"support":"circle","stage":3}, "past")
		check(result.status == puzzles.Status.PENDING and puzzles.get_revision(Rules.ID) == before, "Client requests must not mutate optimistically, even with a forged Past role")
		if not await wait_for(func() -> bool: return "role_not_allowed" in rejected, "Host did not refuse forged client role"): return finish()
		check(state().supports.circle == 1, "Forged request must leave supports unchanged")
		act("read_reserve_note")
		if not await wait_for(func() -> bool: return state().briefed_future, "Private briefing was not confirmed"): return finish()
		act("reserve_power")
		act("repair_bypass")
		if not await wait_for(func() -> bool: return state().supports_secured, "Support plan was not replicated"): return finish()
		act("read_archive")
		if not await wait_for(func() -> bool: return state().archive_read, "Archive was not confirmed"): return finish()
		act("extract_cell")
		if not await wait_for(func() -> bool: return state().recording == "erased", "Cell extraction was not confirmed"): return finish()
		act("release_door")
		if not await wait_for(func() -> bool: return state().core_authorized, "Host did not authorize the Core"): return finish()
		act("arm_anchor")
	if not await wait_for(func() -> bool: return puzzles.is_solved(Rules.ID), "Chapter did not complete on both peers"): return finish()
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
		check(is_corridor() and state() == final_state and current_scene._bridge_ready, "Client room reload must restore the secured layout and evidence branch")
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
