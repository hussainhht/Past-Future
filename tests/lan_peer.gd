extends SceneTree
## Run through run_lan_smoke.py: real ENet peers in separate processes.

const Fixtures := preload("res://tests/puzzle_fixtures.gd")

var network: Node
var failures: int = 0
var port: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func wait_for(predicate: Callable, message: String, timeout: float = 8.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not predicate.call():
		if Time.get_ticks_msec() > deadline:
			check(false, message)
			return false
		await process_frame
	return true


func _run() -> void:
	network = root.get_node("NetworkManager")
	root.get_node("PuzzleManager").register_puzzle("lan_scene_ready", Fixtures.CheckpointPuzzle.new())
	var arguments := OS.get_cmdline_user_args()
	port = int(arguments[1])
	match arguments[0]:
		"host":
			await _host()
		"client":
			await _client()
		"busy":
			check(network.host_game(port) != OK, "A second host must fail on an occupied port")
			check(network.state == network.State.IDLE, "Failed host must remain idle")
			check(network.role.is_empty(), "Failed host must not retain a role")
	network.leave_game()
	print("LAN ", arguments[0], ": ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func _host() -> void:
	check(network.host_game(port) == OK, "Host should bind a UDP port")
	check(network.role == "past", "Host must be assigned Past")
	check(not network.start_game(), "Host cannot start without a guest")
	print("HOST_LISTENING")
	if not await wait_for(func() -> bool: return network.state == network.State.CONNECTED, "Guest never connected", 15.0):
		return
	check(network.guest_id > 1, "Guest must have its own peer ID")
	check(not network.guest_ready, "New guests must start unready")
	network._request_ready(true)
	check(not network.guest_ready, "A request without the guest's sender ID must be rejected")
	if not await wait_for(func() -> bool: return network.guest_ready, "Guest's ready request did not reach host"):
		return
	if not await wait_for(func() -> bool: return not network.guest_ready, "Guest's unready request did not reach host"):
		return
	if not await wait_for(func() -> bool: return network.state == network.State.HOSTING, "Host did not recover after guest left"):
		return
	check(network.guest_id == 0, "Departed guest's ID must be cleared")
	if not await wait_for(func() -> bool: return network.state == network.State.CONNECTED, "Guest could not rejoin"):
		return
	check(not network.guest_ready, "Rejoining must reset ready state")
	check(not network.start_game(), "Host cannot start before the guest is ready")
	_load_menu()
	if not await wait_for(func() -> bool: return network.guest_ready, "Rejoined guest never became ready"):
		return
	check(network.start_game(), "Ready host should start both timeline scenes")
	if not await wait_for(_is_in_spawn_area, "Host did not enter the spawn scene"):
		return
	check(current_scene.timeline == "Past", "Host must spawn in the Past")
	check(not current_scene.get_node("%TimelineButton").visible, "LAN role must not be switchable locally")
	# The finished Professor model can load later than the Student. Wait for the
	# guest's real scene acknowledgement rather than racing a fixed loading delay.
	if not await wait_for(func() -> bool: return root.get_node("PuzzleManager").get_state("lan_scene_ready").get("step", 0) == 1, "Guest did not finish loading its gameplay scene"):
		return
	network.leave_game()
	await create_timer(0.2).timeout


func _client() -> void:
	check(network.join_game("not-an-ip", port) == ERR_INVALID_PARAMETER, "Invalid IP must be rejected")
	check(network.state == network.State.IDLE, "Invalid IP must leave client idle")
	check(network.join_game("127.0.0.1", port) == OK, "Join should initialize")
	if not await wait_for(func() -> bool: return network.state == network.State.CONNECTED, "Client never received lobby snapshot"):
		return
	check(network.role == "future", "Client must be assigned Future")
	check(network.guest_id == network.multiplayer.get_unique_id(), "Host must confirm client's assigned ID")
	network.set_ready(true)
	check(not network.guest_ready, "Ready state must wait for host confirmation")
	if not await wait_for(func() -> bool: return network.guest_ready, "Host never confirmed ready"):
		return
	await create_timer(0.2).timeout
	network.set_ready(false)
	if not await wait_for(func() -> bool: return not network.guest_ready, "Host never confirmed unready"):
		return
	await create_timer(0.2).timeout
	network.leave_game()
	await create_timer(0.4).timeout
	check(network.join_game("127.0.0.1", port) == OK, "Reconnect should initialize")
	if not await wait_for(func() -> bool: return network.state == network.State.CONNECTED, "Client could not rejoin"):
		return
	check(not network.guest_ready, "Client should receive a clean snapshot after reconnecting")
	check(not network.start_game(), "Client must not be able to start the session")
	_load_menu()
	network.set_ready(true)
	if not await wait_for(_is_in_spawn_area, "Client did not enter the spawn scene"):
		return
	check(network.in_game, "Client must receive the host's start confirmation")
	check(current_scene.timeline == "Future", "Client must spawn in the Future")
	if not await wait_for(func() -> bool: return root.get_node("PuzzleManager").is_session_active(), "Guest did not receive initial puzzle snapshot"):
		return
	root.get_node("PuzzleManager").submit_action("lan_scene_ready", "reached", {"step": 1})
	if not await wait_for(func() -> bool: return network.state == network.State.IDLE, "Client did not handle host leaving"):
		return
	check("host closed" in network.status, "Host departure should have a useful message")
	check(current_scene.get_node("%PausePanel").visible, "Disconnect should block gameplay and offer recovery")
	check(not current_scene.player.controls_enabled, "Player must not keep moving after disconnect")
	current_scene._return_to_menu()
	if not await wait_for(func() -> bool: return current_scene.scene_file_path == "res://scenes/menu/main_menu.tscn", "Could not return to menu after disconnect"):
		return
	network.connect_timeout_seconds = 0.5
	network.join_game("127.0.0.1", port)
	if await wait_for(func() -> bool: return network.state == network.State.IDLE, "Failed connection did not time out", 3.0):
		check("timed out" in network.status, "Timeout should give recovery instructions")


func _load_menu() -> void:
	var menu = load("res://scenes/menu/main_menu.tscn").instantiate()
	menu.settings_path = "/tmp/past-future-lan-test-%d.cfg" % OS.get_process_id()
	root.add_child(menu)
	current_scene = menu


func _is_in_spawn_area() -> bool:
	return is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/world/spawn_area.tscn"
