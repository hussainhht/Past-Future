extends Node
## Two-player LAN lobby. The host owns role assignment and ready state.

signal state_changed

const PORT: int = 7000
const PROTOCOL_VERSION: int = 1
enum State { IDLE, HOSTING, CONNECTING, CONNECTED }

var state: State = State.IDLE
var role: String = ""
var guest_id: int = 0
var guest_ready: bool = false
var status: String = ""
var connect_timeout_seconds: float = 10.0
var _connection_deadline: float = 0.0
var _session_generation: int = 0


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	set_process(false)


func host_game(port: int = PORT) -> Error:
	leave_game()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, 1)
	if error != OK:
		peer.close()
		status = "Could not host on UDP %d. Another game may already be using this port." % port
		state_changed.emit()
		return error
	multiplayer.multiplayer_peer = peer
	role = "past"
	state = State.HOSTING
	status = "Waiting for the Professor to join…"
	state_changed.emit()
	return OK


func join_game(address: String, port: int = PORT) -> Error:
	leave_game()
	var clean_address := address.strip_edges()
	if not clean_address.is_valid_ip_address():
		status = "Enter the host's IP address, for example 192.168.1.10."
		state_changed.emit()
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(clean_address, port)
	if error != OK:
		peer.close()
		status = "Could not open a connection: %s." % error_string(error)
		state_changed.emit()
		return error
	multiplayer.multiplayer_peer = peer
	role = "future"
	state = State.CONNECTING
	status = "Connecting to %s…" % clean_address
	_connection_deadline = Time.get_ticks_msec() / 1000.0 + connect_timeout_seconds
	set_process(true)
	state_changed.emit()
	return OK


func leave_game(message: String = "") -> void:
	_session_generation += 1
	set_process(false)
	var peer := multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if peer is ENetMultiplayerPeer:
		peer.close()
	state = State.IDLE
	role = ""
	guest_id = 0
	guest_ready = false
	status = message
	state_changed.emit()


func local_addresses() -> PackedStringArray:
	var addresses := PackedStringArray()
	for address in IP.get_local_addresses():
		if ":" in address or address.begins_with("127.") or address.begins_with("169.254.") or address == "0.0.0.0":
			continue
		addresses.append(address)
	addresses.sort()
	return addresses


func set_ready(ready: bool) -> void:
	if state == State.CONNECTED and role == "future":
		_request_ready.rpc_id(1, ready)


func _process(_delta: float) -> void:
	if state == State.CONNECTING and Time.get_ticks_msec() / 1000.0 >= _connection_deadline:
		leave_game("Connection timed out. Check the address, use the same Wi-Fi, and allow UDP 7000 through the host's firewall. Guest Wi-Fi may block connections between devices.")


func _on_connected_to_server() -> void:
	if state == State.CONNECTING:
		_register_client.rpc_id(1, PROTOCOL_VERSION)


@rpc("any_peer", "call_remote", "reliable")
func _register_client(version: int) -> void:
	if not multiplayer.is_server() or role != "past" or state != State.HOSTING:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1 or not multiplayer.get_peers().has(sender):
		return
	if version != PROTOCOL_VERSION:
		_reject_client.rpc_id(sender, "The two game builds are incompatible. Use the same build on both computers.")
		_disconnect_rejected_peer(sender, _session_generation)
		return
	guest_id = sender
	guest_ready = false
	state = State.CONNECTED
	status = "The Professor has joined. Both timelines are connected."
	_apply_lobby.rpc_id(guest_id, guest_id, guest_ready)
	state_changed.emit()


func _disconnect_rejected_peer(peer_id: int, generation: int) -> void:
	await get_tree().create_timer(0.5).timeout
	if generation == _session_generation and multiplayer.is_server() and multiplayer.get_peers().has(peer_id):
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


@rpc("authority", "call_remote", "reliable")
func _reject_client(message: String) -> void:
	if multiplayer.get_remote_sender_id() == 1 and role == "future":
		leave_game(message)


@rpc("any_peer", "call_remote", "reliable")
func _request_ready(ready: bool) -> void:
	if not multiplayer.is_server() or role != "past" or state != State.CONNECTED:
		return
	if multiplayer.get_remote_sender_id() != guest_id:
		return
	guest_ready = ready
	status = "Both players are ready." if ready else "The Professor has joined. Both timelines are connected."
	_apply_lobby.rpc_id(guest_id, guest_id, guest_ready)
	state_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _apply_lobby(assigned_guest_id: int, ready: bool) -> void:
	if multiplayer.get_remote_sender_id() != 1 or role != "future":
		return
	if assigned_guest_id != multiplayer.get_unique_id():
		return
	set_process(false)
	guest_id = assigned_guest_id
	guest_ready = ready
	state = State.CONNECTED
	status = "Both players are ready." if ready else "Connected to the Student. You are the Professor."
	state_changed.emit()


func _on_peer_disconnected(peer_id: int) -> void:
	if role == "past" and peer_id == guest_id:
		guest_id = 0
		guest_ready = false
		state = State.HOSTING
		status = "The Professor left. Waiting for another connection…"
		state_changed.emit()


func _on_connection_failed() -> void:
	if role == "future":
		leave_game("Could not reach the host. Check the IP address, Wi-Fi network, and host firewall, then try again.")


func _on_server_disconnected() -> void:
	if role == "future":
		leave_game("The host closed the session. You can join again or return to the menu.")
