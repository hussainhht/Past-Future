extends SceneTree
## Real ENet session; both processes load the actual room and use its production RPC path.

const Rules := preload("res://scripts/level3/core_rules.gd")
var pm: Node
var net: Node
var room: Node3D
var host: bool = false
var failures: int = 0
var checks: int = 0
var _watchdog: float = 0.0
var barrier: Node


class PeerBarrier extends Node:
	var acknowledged: int = -1

	@rpc("any_peer", "call_remote", "reliable")
	func checkpoint(index: int) -> void:
		if multiplayer.is_server() and multiplayer.get_remote_sender_id() > 1:
			acknowledged = index


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("LEVEL3 PEER FAILED: " + message)


func wait_for(predicate: Callable, message: String, seconds: float = 20.0) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call():
		if Time.get_ticks_msec() > until:
			check(false, message)
			quit(1)
			return false
		await process_frame
	return true


func _tick(frames: int = 3) -> void:
	for i in range(frames): await physics_frame
	await process_frame


func host_at(station: String) -> void:
	room.player.position = Rules.STATIONS[station] + Vector3(0, 0, 1.1)
	room.player.velocity = Vector3.ZERO
	await _tick()


func use_device(station: String, caption: String, confirm: bool = false) -> void:
	room._close()
	room.operate(station)
	check(room.devices.inspector.active, "networked physical inspection: " + station)
	check(room.devices.inspector.press_control(caption), "networked physical control: " + caption)
	if confirm:
		check(room.ui.visible_modal, "networked operation requires confirmation")
		var buttons: Array[Node] = room.ui.modal_box.find_children("*", "Button", true, false)
		buttons[1].pressed.emit()
	await _tick()
	room._close()


## Future travels with the actual CharacterBody collision and a legal speed envelope.
func walk(at: Vector3) -> void:
	var target: Vector3 = room.worlds.future.global_position + at
	var until := Time.get_ticks_msec() + 12000
	while room.player.position.distance_to(target) > 0.05:
		await physics_frame
		if Time.get_ticks_msec() > until:
			check(false, "Future path blocked at " + str(room.local_position()) + " toward " + str(at))
			quit(1)
			return
		var step: Vector3 = (target - room.player.position).limit_length(3.9 / 60.0)
		room.player.move_and_collide(step)
	await create_timer(0.18).timeout


func _run() -> void:
	pm = root.get_node("PuzzleManager")
	net = root.get_node("NetworkManager")
	pm.log_rejections = false
	var args := OS.get_cmdline_user_args()
	host = args[0] == "host"
	var port := int(args[1])
	var flow: Node = root.get_node("GameFlowManager")
	barrier = PeerBarrier.new()
	barrier.name = "Level3TestBarrier"
	root.add_child(barrier)
	net.game_started.connect(func() -> void: flow.start_room.call_deferred("room_03"))
	if host:
		check(net.host_game(port) == OK, "host opens ENet")
		print("CORE_HOST_LISTENING")
		await wait_for(func() -> bool: return net.guest_ready, "guest ready")
		check(net.start_game(), "host authorizes level launch")
	else:
		check(net.join_game("127.0.0.1", port) == OK, "client connects")
		await wait_for(func() -> bool: return net.state == net.State.CONNECTED, "lobby connected")
		net.set_ready(true)
	await wait_for(func() -> bool: return current_scene != null and current_scene.name == "TemporalCore" and current_scene.is_game_flow_ready(), "both load actual core")
	room = current_scene
	room.player.set_physics_process(false)
	await wait_for(func() -> bool: return room.remote_ready, "role handshake")
	check(room.networked and room.role == ("past" if host else "future"), "correct locked timeline")
	check(room.player.get_node("Visual/Student").scene_file_path.contains("student_3d/student.glb" if host else "professor_3d/professor.glb"), "correct role avatar")
	room.switch_debug_role()
	check(room.role == ("past" if host else "future"), "debug switch cannot bypass live role")
	if host:
		check(not room.accept_future_pose(Vector3(7, 0, -5)), "host refuses remote teleport")
	else:
		pm.submit_action(Rules.ID, "coil", {"attempt": room.state.attempt, "seq": 700, "index": 0}, "past")
		pm.submit_action(Rules.ID, "start", {"attempt": room.state.attempt, "seq": 701, "role": "past"})
		await create_timer(0.25).timeout
		check(room.state.stage == "DISCOVERY", "spoofed role and malformed start do not progress state")
	var matrix := [["GROUND THE CORE", "RELEASE THE ECHO", "trust"], ["CLAIM ORIGIN", "RELEASE THE ECHO", "student_override"], ["GROUND THE CORE", "PRESERVE ECHO", "professor_override"], ["CLAIM ORIGIN", "PRESERVE ECHO", "paradox"]]
	for case_index in range(matrix.size()):
		var row: Array = matrix[case_index]
		var attempt: int = room.state.attempt
		if host:
			await create_timer(0.5).timeout
			await host_at("start")
			await use_device("start", "ARM REACTOR...", true)
			await host_at("coil_0")
			await use_device("coil_0", "SET POSITION 2")
			await wait_for(func() -> bool: return room.state.coils[0] == 2, "physical coil selector reaches confirmed stop 2")
			await host_at("coil_2")
			await use_device("coil_2", "SET POSITION 1")
		else:
			await wait_for(func() -> bool: return room.state.stage == "STAGE_A", "reactor starts on client")
			await walk(Vector3(6, 0, 4.1))
			await use_device("receiver", "RECONNECT BATTERY")
		await wait_for(func() -> bool: return room.state.stage == "STAGE_B", "both see Stage B")
		check(room.state.remaining > 100 and room.state.remaining <= 150, "host timer resyncs on both peers")
		if not host:
			await walk(Vector3(4.8, 0, 4.1))
			await walk(Vector3(4.8, 0, -1.9))
			await walk(Vector3(6, 0, -1.9))
			await use_device("anchor", "CALIBRATE SIGNAL ANCHOR")
		else:
			await wait_for(func() -> bool: return room.state.anchor, "Future calibrates anchor")
			await host_at("origin")
			await use_device("origin", "STABILIZE ORIGIN CORE")
		await wait_for(func() -> bool: return room.state.origin, "Past stabilizes Origin")
		if not host:
			await walk(Vector3(4.8, 0, -1.9))
			await walk(Vector3(4.8, 0, 1))
			await walk(Vector3(2.5, 0, 1))
			await use_device("sync_future", "ENGAGE PHASE SWITCH")
		else:
			await wait_for(func() -> bool: return room.state.sync_future, "Future presses its physical switch")
			check(room.state.stage == "STAGE_B", "one peer cannot synchronize alone")
			await host_at("sync_past")
			await use_device("sync_past", "ENGAGE PHASE SWITCH")
		await wait_for(func() -> bool: return room.state.stage == "STAGE_C", "both see identity lock")
		if host:
			await host_at("terminal_past")
			await use_device("terminal_past", row[0], true)
			check(not str(room.state).contains(row[0]), "host public state excludes private choice")
		else:
			await walk(Vector3(4.8, 0, 1))
			await walk(Vector3(4.8, 0, 4.1))
			await walk(Vector3(3.5, 0, 4.1))
			check(room.state.locked_past and not str(room.state).contains(row[0]), "client sees neutral partner lock only")
			var old_coils: Array = room.state.coils.duplicate()
			pm.submit_action(Rules.ID, "choose", {"attempt": attempt, "seq": 500, "command": "CLAIM ORIGIN"}, "past")
			pm.submit_action(Rules.ID, "choose", {"attempt": attempt, "seq": 501, "command": row[1], "role": "past"})
			await create_timer(0.15).timeout
			check(room.state.stage == "STAGE_C" and room.state.coils == old_coils, "spoofed and malformed votes refused")
			await use_device("terminal_future", row[1], true)
		await wait_for(func() -> bool: return room.state.stage == "ENDING", "both reach ending")
		check(room.state.ending == row[2], "matching shared ending " + row[2])
		check(pm.is_solved(Rules.ID), "ending marks canonical puzzle solved")
		var revision: int = pm.get_revision(Rules.ID)
		var immutable: Dictionary = room.state.duplicate(true)
		if host:
			check(not pm._receive_update(pm.get_session_id() - 1, Rules.ID, {}, false, revision + 1000, 0), "foreign-session state refused")
		else:
			check(not pm._receive_update(pm.get_session_id(), Rules.ID, {}, false, revision - 1, 0), "stale state revision refused")
			pm.submit_action(Rules.ID, "choose", {"attempt": attempt, "seq": 900, "command": row[1]})
		await create_timer(0.25).timeout
		check(room.state == immutable, "repeated final input cannot alter resolved result")
		print("CORE_CASE %s %s revision=%d" % ["host" if host else "client", row[2], revision])
		if host:
			await wait_for(func() -> bool: return barrier.acknowledged == case_index, "client verified ending before replay")
			room.request_action("replay")
		else:
			barrier.checkpoint.rpc_id(1, case_index)
		await wait_for(func() -> bool: return room.state.stage == "DISCOVERY" and room.state.attempt > attempt, "replay on both peers")
		check(room.state.remaining == 150.0, "replay timer resets to 150")
		if not host:
			pm.submit_action(Rules.ID, "start", {"attempt": attempt, "seq": 1000})
	if host:
		await create_timer(0.5).timeout
		net.leave_game("Level3 disconnect check")
	else:
		await wait_for(func() -> bool: return room.disconnected, "host disconnect suspends client")
		check(room.ui.visible_modal and not room.player.controls_enabled, "client gets usable disconnect recovery")
	print("LEVEL3 %s: %s (%d checks, %d failures)" % ["host" if host else "client", "PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
