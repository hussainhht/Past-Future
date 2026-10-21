extends Node3D
## The playable maintenance gallery. PuzzleManager remains the only progression authority.

const Rules := preload("res://scripts/puzzles/implementations/maintenance_corridor_puzzle.gd")
const Frequency := preload("res://scripts/puzzles/implementations/frequency_puzzle.gd")
const Radio := preload("res://scripts/gameplay/radio/temporal_radio.gd")
const WorldTextLayout := preload("res://scripts/ui/world_text_layout.gd")
const TemporalGhost := preload("res://scripts/world/temporal_ghost.gd")
const TemporalButton := preload("res://scripts/menu/menu_button.gd")
const SEQUENCES := {
	"arrival": "res://resources/dialogue/maintenance/arrival.tres",
	"identity": "res://resources/dialogue/maintenance/identity.tres",
	"preserved": "res://resources/dialogue/maintenance/preserved.tres",
	"erased": "res://resources/dialogue/maintenance/erased.tres",
	"ending_preserved": "res://resources/dialogue/maintenance/ending_preserved.tres",
	"ending_erased": "res://resources/dialogue/maintenance/ending_erased.tres"}
const FUTURE_DEVICES := ["Battery", "ReserveFuture", "BypassFuture", "Archive", "Recorder", "Release"]
const PAST_DEVICES := ["Service", "ReservePast", "BypassPast", "Keypad"]

@export var pause_when_unfocused := true
@export var temporal_ghost_enabled := true
var temporal_ghost: Node3D
var role := "past"
var state: Dictionary = {}
var devices: Dictionary = {}
var radio: TemporalRadio
var controller: InteractionController
var prompt: CanvasLayer
var timeline_label: Label
var role_button: Button
var pause_button: Button
var pause_screen: Control
var ending_screen: Control
var _positions: Dictionary = {}
var _active_device := ""
var _rebuilding_panel := false
var _panel_refresh_queued := false
var _paused := false
var _disconnected := false
var _leaving := false
var _last_power := true
var _initialized := false
var _ending_dismissed := false
var _pending_lines: Array[String] = []
var _palette_materials: Dictionary = {}
var _signal_materials: Dictionary = {}
var _device_labels: Dictionary = {}
var _floating_labels: Array[Label3D] = []
var _equipment_tween: Tween
var storage: Node3D
var settings_overlay: CanvasLayer
var pause_menu: CanvasLayer
var sound: Node

@onready var player: CharacterBody3D = $Actors/Player
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var ui = $RoomUI
@onready var audio: AudioDirector = $AudioSystem
@onready var director: DialogueDirector = $DialogueDirector


func _ready() -> void:
	GameFlowManager.attach_room("room_02", self)
	# F6 is a stand-alone preview. A normal laboratory transition never seeds or resets progress.
	if not PuzzleManager.is_registered(Frequency.ID):
		PuzzleManager.register_puzzle(Frequency.ID, Frequency.new())
		if not NetworkManager.in_game and not GameFlowManager.demo_radio_link:
			PuzzleManager.submit_action(Frequency.ID, "acquire_radio", {"radio_role": "past"}, "past")
			PuzzleManager.submit_action(Frequency.ID, "acquire_radio", {"radio_role": "future"}, "future")
			PuzzleManager.submit_action(Frequency.ID, "tune_frequency", {"frequency": 67}, "past")
			PuzzleManager.submit_action(Frequency.ID, "tune_amplitude", {"amplitude": 70}, "past")
	if not PuzzleManager.is_registered(Rules.ID):
		PuzzleManager.register_puzzle(Rules.ID, Rules.new())
	role = PuzzleManager.get_local_role()
	state = PuzzleManager.get_state(Rules.ID)
	audio.add_to_group("lab_audio")
	sound = preload("res://scripts/world/maintenance_sound.gd").new()
	sound.name = "MaintenanceSound"
	add_child(sound)
	sound.bind(self, audio)
	_build_hud()
	_create_devices()
	storage = preload("res://scripts/gameplay/storage/storage_room.gd").new()
	$Layout.add_child(storage)
	storage.configure(self)
	ui.inspector.install_keypad($Layout/Shared/KeypadStand)
	for id in devices:
		_device_labels[id] = $Layout.get_node_or_null("Shared/" + id + "Label")
	for label in $Layout.find_children("*", "Label3D", true, false):
		if label.billboard == BaseMaterial3D.BILLBOARD_ENABLED: _floating_labels.append(label)
	prompt = load("res://scenes/ui/interaction_prompt.tscn").instantiate()
	add_child(prompt)
	radio = Radio.new()
	radio.name = "TemporalRadio"
	add_child(radio)
	ui.action_selected.connect(_request)
	ui.modal_changed.connect(_on_modal_changed)
	PuzzleManager.puzzle_state_changed.connect(_on_state_changed)
	PuzzleManager.action_rejected.connect(_on_rejected)
	NetworkManager.state_changed.connect(_on_network_changed)
	_spawn_role()
	_initialized = true
	GameFlowManager.input_lock_changed.connect(func(_locked: bool) -> void: _sync_controls())
	_apply_state(false)
	_sync_story_from_state()
	if not NetworkManager.in_game and temporal_ghost_enabled:
		temporal_ghost = TemporalGhost.new()
		add_child(temporal_ghost)
		var roots: Array[Node3D] = [$Layout]
		temporal_ghost.configure(self, roots, _temporal_ghost_context)
	get_tree().auto_accept_quit = false


func _temporal_ghost_context() -> Dictionary:
	return {"role": role, "player": player,
		"past_position": player.global_position if role == "past" else _positions.get("past", $past_entry.global_position),
		"future_position": player.global_position if role == "future" else _positions.get("future", $future_entry.global_position),
		"inspecting": ui.inspector.active,
		"blocked": _paused or _disconnected or _leaving or GameFlowManager.is_input_locked() or JournalManager.is_open() or ending_screen.visible}


func _create_devices() -> void:
	for marker in $Layout/Devices.get_children():
		var target := Interactable3D.new()
		target.name = marker.name
		target.position = marker.position
		var stand := $Layout.get_node_or_null("Shared/" + String(marker.name) + "Stand")
		if stand != null:
			target.prompt_anchor = stand.get_node_or_null("CrankWheel" if marker.name == "Battery" else "Panel")
		target.interaction_distance = 1.85
		target.interaction_name = "Use " + String(marker.name).to_snake_case().replace("_", " ")
		target.play_interaction_animation = true
		target.timing = Interactable3D.Timing.AFTER_ANIMATION
		if marker.name in FUTURE_DEVICES: target.allowed_timeline = 2
		elif marker.name in PAST_DEVICES: target.allowed_timeline = 1
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.45
		collision.shape = shape
		collision.position.y = 0.55
		target.add_child(collision)
		target.interacted.connect(func(_actor: Node, _role: String) -> void: _show_device(String(marker.name)))
		$Layout.add_child(target)
		devices[String(marker.name)] = target


func _spawn_role() -> void:
	ui.close_modal()
	director.reset_session()
	_pending_lines.clear()
	if radio.get_parent() != self: radio.reparent(self)
	var path := "res://scenes/characters/%s_3d_player.tscn" % ("professor" if role == "future" else "student")
	if player.scene_file_path != path:
		$Actors.remove_child(player)
		player.queue_free()
		player = load(path).instantiate()
		player.name = "Player"
		$Actors.add_child(player)
	var spawn := GameFlowManager.find_spawn_point(GameFlowManager.get_entry_spawn_id(role), self)
	player.global_position = _positions.get(role, spawn.global_position if spawn != null else Vector3(0, 0.05, 7.5))
	player.demonstration_items_enabled = false
	player.view_camera = camera
	# The radio stays on its hand socket without the bulky-item sprint restriction.
	player.carrying = false
	if not player.has_node("InteractionRig"):
		player.add_child(load("res://scenes/interaction/interaction_rig.tscn").instantiate())
	controller = player.get_node("InteractionRig/InteractionController")
	controller.prompt_ui = prompt
	controller.detector.set_current_role(role)
	if not player.has_node("FootstepEmitter3D"):
		player.add_child(load("res://scenes/audio/footstep_emitter_3d.tscn").instantiate())
	(player.get_node("FootstepEmitter3D") as FootstepEmitter3D).set_timeline(StringName(role))
	if not player.has_node("LocalAudioListener"):
		var listener := AudioListener3D.new()
		listener.name = "LocalAudioListener"
		listener.position.y = 1.4
		player.add_child(listener)
		listener.make_current()
	radio.reparent(player)
	radio.set_player_role(role)
	if not player.skeleton.has_node("CorridorRadioSocket"):
		var socket := BoneAttachment3D.new()
		socket.name = "CorridorRadioSocket"
		socket.bone_name = "handslot.r"
		player.skeleton.add_child(socket)
		var model: Node3D = load("res://scenes/gameplay/radio/placeholder_radio.tscn").instantiate()
		model.position = Vector3(0, 0.08, 0)
		socket.add_child(model)
	$CameraRig.target = player
	$CameraRig.snap_to_target()
	ui.set_timeline(role == "future")
	director.set_local_timeline(role)
	if not NetworkManager.in_game: PuzzleManager.offline_role = role
	audio.start_soundscape(StringName(role))
	sound.set_role(role)
	_apply_variants()
	_refresh_wayfinding(1.0)


func switch_role() -> void:
	if NetworkManager.in_game or ui.is_modal_open() or _paused or _disconnected or GameFlowManager.is_input_locked() or player.is_action_active(): return
	_positions[role] = player.global_position
	role = "future" if role == "past" else "past"
	_spawn_role()
	if state.anchor_past and state.anchor_future: _ending_dismissed = true
	_apply_state(false)
	_sync_story_from_state()


func _apply_variants() -> void:
	for label in $Layout.find_children("*", "Label3D", true, false):
		label.font = Typography.display_font(role == "future") if String(label.name).begins_with("Stage_") or label.name == &"RecorderPlaque" else Typography.font(&"ui_label")
	var keypad := $Layout/Shared/KeypadStand.get_node_or_null("MountedKeypad/EntryReadout")
	if keypad != null: keypad.font = Typography.display_font(role == "future")
	for prop in $Layout.find_children("*", "Node3D", true, false):
		if prop is TimelineProp: prop.future = role == "future"
	for name in ["PastOnly", "FutureOnly"]:
		var branch: Node3D = $Layout.get_node(name)
		var active: bool = (role == "future") == (name == "FutureOnly")
		branch.visible = active
		for shape in branch.find_children("*", "CollisionShape3D", true, false): shape.set_deferred("disabled", not active)
	$KeyLight.light_color = Color("9bb7c3") if role == "future" else Color("ffe6ba")
	var environment: Environment = $WorldEnvironment.environment
	environment.ambient_light_color = Color("7496a8") if role == "future" else Color("e5d9ba")
	environment.ambient_light_energy = 0.4 if role == "future" else 0.55
	var aged := {"floor": "35454b", "wall": "46575e", "steel": "354c55", "copper": "886e4e", "yellow": "b49a61", "concrete": "556166"}
	for piece in $Layout.find_children("*", "MeshInstance3D", true, false):
		var base := piece.get_meta("corridor_original", piece.material_override) as StandardMaterial3D
		if base == null or not base.resource_name.begins_with("corridor_"): continue
		piece.set_meta("corridor_original", base)
		var key := base.resource_name + role
		if not _palette_materials.has(key):
			var material := base.duplicate() as StandardMaterial3D
			var slot := base.resource_name.trim_prefix("corridor_")
			if role == "future" and aged.has(slot): material.albedo_color = Color(aged[slot])
			_palette_materials[key] = material
		piece.material_override = _palette_materials[key]


func _collisions(node: Node, enabled: bool) -> void:
	for shape in node.find_children("*", "CollisionShape3D", true, false): shape.set_deferred("disabled", not enabled)


func _apply_state(animate: bool) -> void:
	if state.is_empty(): return
	for variant in ["PastOnly", "FutureOnly"]:
		var unlocked: bool = state.core_authorized if variant == "PastOnly" else state.future_release_open
		var gate: Node3D = $Layout.get_node(variant + "/CoreGate")
		gate.visible = not unlocked
		_collisions(gate, not unlocked and ((role == "past") == (variant == "PastOnly")))
		$Layout.get_node(variant + "/GateBand").visible = not unlocked
	var powered := Rules.has_power(state, role)
	$KeyLight.light_energy = (0.66 if role == "future" else 0.95) if powered else (0.28 if role == "future" else 0.5)
	if powered and state.priority == role: $KeyLight.light_energy *= 1.2
	if _last_power and not powered and state.battery_ready:
		ui.toast("Auxiliary voltage dropped. Inspect the distribution meter at your reserve station.")
		if _initialized: sound.on_power_lost()
	_last_power = powered
	storage.refresh(animate)
	_refresh_equipment(animate)
	_refresh_hud()
	if state.anchor_past and state.anchor_future and not _ending_dismissed: _show_ending()
	if not _active_device.is_empty() and not _panel_refresh_queued:
		_panel_refresh_queued = true
		_refresh_panel.call_deferred()


func _signal(piece: MeshInstance3D, color: String) -> void:
	if not _signal_materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(color)
		material.roughness = 0.65
		material.emission_enabled = color != "314147"
		material.emission = Color(color)
		material.emission_energy_multiplier = 0.65
		_signal_materials[color] = material
	piece.material_override = _signal_materials[color]


func _equipment_light(path: String, color: String) -> void:
	var piece := $Layout.get_node(path) as MeshInstance3D
	_signal(piece, color)


func _refresh_equipment(animate: bool = false) -> void:
	# These indicators only display confirmed puzzle state, including snapshots and role changes.
	var off := "314147"
	var live := "76c9b3"
	var ready := "d6ac63"
	var fault := "c96a53"
	var local_power := Rules.has_power(state, role)
	var completed := {
		"Service": state.service_isolated, "Battery": state.battery_ready,
		"ReservePast": state.priority == "past", "ReserveFuture": state.priority == "future",
		"BypassPast": state.bypass_past, "BypassFuture": state.bypass_future,
		"Archive": state.archive_read, "Recorder": state.recording != "pending",
		"Keypad": state.core_authorized, "Release": state.future_release_open,
		"Anchor": state.get("anchor_" + role, false)}
	for id in completed:
		var allowed: bool = devices[id].is_timeline_allowed(role)
		var color := live if completed[id] else ready
		if not allowed: color = off
		elif state.battery_ready and not local_power and id not in ["Service", "BypassPast", "BypassFuture"]: color = fault
		_equipment_light("Shared/" + id + "Stand/Indicator/Mesh", color)
	for feed in ["Main", "PastFeed", "FutureFeed", "Bypass"]:
		var color := off
		match feed:
			"Main": color = live if state.battery_ready else (ready if state.service_isolated else off)
			"PastFeed": color = live if Rules.has_power(state, "past") else (fault if state.battery_ready else off)
			"FutureFeed": color = live if Rules.has_power(state, "future") else (fault if state.battery_ready else off)
			"Bypass": color = live if Rules.bypass_ready(state) else (ready if state.get("bypass_" + role, false) else off)
		for piece in $Layout.get_node("Shared/PowerRoutes/" + feed).get_children():
			if String(piece.name).begins_with("Current"): _signal(piece.get_node("Mesh"), color)
	for reserve in ["Past", "Future"]:
		_equipment_light("Shared/Reserve" + reserve + "Stand/MeterLamp/Mesh", ready if state.priority == reserve.to_lower() else off)
	if _equipment_tween: _equipment_tween.kill()
	_equipment_tween = create_tween().set_parallel(true)
	var mechanical := [
		[$Layout/Shared/BatteryStand/CrankWheel, "rotation_degrees:z", 720.0 if state.battery_ready else 0.0],
		[$Layout/Shared/ServiceStand/IsolatorLever, "rotation_degrees:x", 28.0 if state.service_isolated else -28.0],
		[$Layout/Shared/ReservePastStand/ReserveLever, "rotation_degrees:x", 28.0 if state.priority == "past" else -35.0],
		[$Layout/Shared/ReserveFutureStand/ReserveLever, "rotation_degrees:x", 28.0 if state.priority == "future" else -35.0],
		[$Layout/Shared/AnchorStand/AnchorLever, "rotation_degrees:x", 28.0 if state.get("anchor_" + role, false) else -28.0],
		[$Layout/Shared/ReleaseStand/ReleaseWheel, "rotation_degrees:z", 160.0 if state.future_release_open else 0.0]]
	for control in mechanical:
		var duration := 0.85 if control[0] == $Layout/Shared/BatteryStand/CrankWheel else 0.30
		_equipment_tween.tween_property(control[0], control[1], control[2], duration if animate else 0.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	$Layout/Shared/RecorderStand/Cell.visible = state.recording != "erased"
	$Layout/Shared/RecorderStand/CellHandle.visible = state.recording != "erased"
	_equipment_light("Shared/RecorderStand/RecordLamp/Mesh", live if state.recording == "preserved" else (off if state.recording == "erased" else fault))
	var anchor_color := live if state.anchor_past and state.anchor_future else (ready if state.get("anchor_" + role, false) else off)
	for side in [-1, 1]: _equipment_light("Shared/CoreMachine/PylonCurrent%d/Mesh" % side, anchor_color)
	var gate_open: bool = state.core_authorized if role == "past" else state.future_release_open
	for side in [-1, 1]: _equipment_light("Shared/GateSignal%d/Mesh" % side, live if gate_open else ready)


func _refresh_wayfinding(delta: float) -> void:
	# Close labels support the object silhouettes. Distant labels no longer overlap across the room.
	var inspecting: bool = ui.is_modal_open()
	for label in _floating_labels: label.visible = not inspecting
	var goals := _wayfinding_goals()
	for id in _device_labels:
		var label: Label3D = _device_labels[id]
		if label == null: continue
		var distance: float = player.global_position.distance_to(devices[id].global_position)
		var shown: bool = devices[id].is_timeline_allowed(role) and distance < (8.0 if id in goals else 3.4)
		if id == "Audit": shown = shown and player.position.z < -11.5
		label.modulate.a = move_toward(label.modulate.a, 1.0 if shown else 0.0, delta * 6.0)
		label.visible = not inspecting and label.modulate.a > 0.01
	# The fixed camera looks through this lintel after entering the Core.
	$Layout/Shared/GateLintel.visible = player.position.z > -9.0
	$Layout/Shared/NorthSign.visible = player.position.z > -9.0 and not inspecting
	if not inspecting:
		var reserved: Array[Rect2] = ui.reserved_text_rects()
		var screen := get_viewport().get_visible_rect().size
		reserved.append(Rect2(0, 0, screen.x, 140))
		reserved.append(Rect2(0, screen.y - 100, screen.x, 100))
		WorldTextLayout.arrange(_floating_labels, camera, player.global_position, reserved)


func _wayfinding_goals() -> Array:
	if not state.service_isolated: return ["Service"] if role == "past" else ["Battery"]
	if not state.battery_ready: return ["Battery"] if role == "future" else []
	if not Rules.has_power(state, role): return ["BypassPast" if role == "past" else "BypassFuture"]
	if not Rules.Storage.repaired(state): return ["Archive"] if role == "future" else ["StorageBay0", "StorageBay1", "StorageBay2"]
	if not state.archive_read: return ["Archive"] if role == "future" else []
	if state.recording == "pending":
		return ["Recorder", "BypassFuture"] if role == "future" else ["BypassPast"]
	if role == "past" and not state.core_authorized: return ["Keypad"]
	if role == "future" and not state.future_release_open: return ["Release"]
	return ["Audit"] if state.get("anchor_" + role, false) else ["Anchor"]


func _refresh_panel() -> void:
	_panel_refresh_queued = false
	if ui.is_modal_open() and not _active_device.is_empty(): _show_device(_active_device)


func _option(label: String, action: String, payload: Dictionary = {}, disabled: bool = false) -> Dictionary:
	return {"label": label, "action": action, "payload": payload, "disabled": disabled}


func _show_device(id: String) -> void:
	var target: Interactable3D = devices.get(id)
	if target == null or not target.is_timeline_allowed(role): return
	var first_inspection: bool = _active_device != id or not ui.is_modal_open()
	if id.begins_with("Case_"): return
	_active_device = id
	if storage.handles(id):
		storage.open_device(id)
		return
	if id == "Archive" and not Rules.Storage.repaired(state):
		storage.open_archive()
		return
	var title := ""
	var body := ""
	var thought := ""
	var actions: Array = []
	var bindings: Dictionary = {}
	var code_entry := false
	var powered := Rules.has_power(state, role)
	var stand: Node3D = $Layout.get_node_or_null("Shared/" + id + "Stand")
	match id:
		"Service":
			title = "SERVICE CIRCUIT / ISOLATOR"
			body = "FACILITIES / SAFETY NOTICE\nBefore charging an emergency cell, disconnect SERVICE from the research array. Leave the auxiliary return intact.\n" + ("SERVICE ISOLATED / LATCH ENGAGED" if state.service_isolated else "ARRAY CONNECTION / LEVER OPEN")
			thought = "The label says SERVICE. Pulling this should disconnect it from the array."
			actions = [_option("Flip SERVICE isolator", "isolate_service", {}, state.service_isolated)]
			bindings.isolate_service = stand.get_node("IsolatorLever")
		"Battery":
			title = "EMERGENCY CELL / HAND CRANK"
			body = "CHARGING INSTRUCTIONS\nIsolate SERVICE before charging. Turn crank until the charge latch engages.\n" + ("CHARGE LATCHED / CELL ONLINE" if state.battery_ready else "CELL DEPLETED / CHARGE REQUIRED")
			thought = "No mains power. The crank still moves, but this warning says to isolate SERVICE first."
			actions = [_option("Turn charging crank", "charge_battery", {}, state.battery_ready or not state.service_isolated)]
			bindings.charge_battery = stand.get_node("CrankWheel")
		"ReservePast", "ReserveFuture":
			if not state.get("briefed_" + role, false): _request("read_reserve_note", {})
			title = "PRIORITY RESERVE / ALLOCATION"
			body = "LOCAL PRIORITY / EMERGENCY USE\nEngage to charge this receiver and reserve its supply. WARNING: remote auxiliary feed disconnected. Allocation cannot be reversed under load.\n"
			body += "Reserve output powers the local equipment feed." if role == "past" else "Reserve output can operate the Core release independently of the authorization line."
			body += "\n\nISOLATED BYPASS: " + ("CONTINUITY VERIFIED" if Rules.bypass_ready(state) else "OPEN CIRCUIT")
			body += "\nLOCAL PRIORITY: " + ("ENGAGED" if state.priority == role else "DISENGAGED")
			thought = "I could power my own equipment right now. But that warning... it would cut the other receiver off."
			actions = [_option("Engage reserve lever", "reserve_power", {}, state.priority != "shared" or not state.service_isolated or not state.get("briefed_" + role, false))]
			bindings.reserve_power = stand.get_node("ReserveLever")
		"BypassPast", "BypassFuture":
			title = "AUXILIARY RETURN / SERVICE"
			body = "ISOLATED BYPASS\nSeat replacement fuse and reconnect ground lead before loading the circuit. Both connections are required for continuity.\nAn isolated supply maintains recorder memory during export.\nLOCAL CONNECTION: " + ("LATCHED" if state.get("bypass_" + role, false) else "OPEN")
			thought = "There's a clean fuse in the cover. The return line needs a ground connection too." if role == "past" else "The ground lead has come loose. The fuse symbol on the diagram marks the other break."
			actions = [_option("Seat replacement fuse" if role == "past" else "Reconnect ground lead", "repair_bypass", {}, state.get("bypass_" + role, false) or not state.service_isolated)]
			bindings.repair_bypass = stand.get_node("FuseLink")
		"Archive":
			title = "MAINTENANCE / ACCESS RECORD"
			if not powered: body = "RECORD TERMINAL OFFLINE\nAuxiliary voltage required."
			else:
				if not state.archive_read: _request("read_archive", {})
				body = "SERVICE OVERRIDE / 3142\nCore entrance: authorization at console, manual wheel at motor.\nPERSONNEL / CAREER HISTORY\nCurrent appointment: Research Professor.\nFirst appointment: Student Research Assistant.\nService record: 31 years.\nOriginal induction card attached.\nINCIDENT INDEX / 23:44\nWarning acknowledged. Automatic shutdown overridden. Authorization retained in incident recorder."
			thought = "My appointment file, beside my old induction card. He's going to recognise that watch."
		"Recorder":
			title = "INCIDENT RECORDER / 23:44"
			body = "AUTHORIZATION PREVIEW\nOperator credential matches the appointment file. Containment warning acknowledged.\nEXPORT / isolated supply required.\nBACKUP CELL / routes power to door release. Removing cell clears unsent memory and opens the auxiliary monitor circuit. Removal is logged mechanically.\nBUFFER: " + String(state.recording).to_upper()
			if Rules.bypass_ready(state): body += "\nIsolated supply connected. Monitor circuit protected. Unsent memory still lost on cell removal."
			thought = "That's my authorization. If I take the cell, the door gets power... and that recording never reaches him."
			actions = [_option("Press recording export", "preserve_recording", {}, state.recording != "pending" or not state.archive_read or not Rules.bypass_ready(state)), _option("Pull backup cell", "extract_cell", {}, state.recording != "pending" or not state.archive_read)]
			bindings.preserve_recording = stand.get_node("ExportButton")
			bindings.extract_cell = stand.get_node("CellHandle")
		"Keypad":
			title = "CORE ENTRANCE / AUTHORIZATION"
			body = "SERVICE ACCESS\nEnter maintenance override.\nRecorder memory transfer or buffer release must complete before interlock clears.\n" + ("ACCESS AUTHORIZED" if state.core_authorized else ("AUXILIARY VOLTAGE LOW" if not powered else "CODE REQUIRED"))
			thought = "Four digits. There should be an access record in the cabinets in the storage room."
			code_entry = not state.core_authorized
			actions = [_option("Authorize service entrance", "authorize_core", {}, state.core_authorized or not powered)]
		"Release":
			title = "CORE ENTRANCE / MANUAL RELEASE"
			body = "MOTOR FAILURE / USE HAND WHEEL\nAuthorization line or local emergency reserve required.\nRecorder memory must be secured or released before this interlock clears.\n" + ("RELEASE LATCHED" if state.future_release_open else "RELEASE LOCKED")
			thought = "The motor's seized. The wheel should turn once the interlock gets a supply."
			actions = [_option("Turn manual release", "release_door", {}, state.future_release_open or state.recording == "pending")]
			bindings.release_door = stand.get_node("ReleaseWheel")
		"Anchor":
			title = "ANCHOR 01 / STABILIZATION"
			body = "LATCH TRANSMITTER AND RECEIVER\nHold each contact until its indicator stays lit. Contacts latch independently.\nTRANSMITTER: %s\nRECEIVER: %s" % ["ARMED" if state.anchor_past else "OPEN", "CONNECTED" if state.anchor_future else "OPEN"]
			thought = "Two contacts on this diagram. Mine stays latched; I can wait for the answering light."
			actions = [_option("Latch stabilization contact", "arm_anchor", {}, state.get("anchor_" + role, false))]
			bindings.arm_anchor = stand.get_node("AnchorLever")
		"Audit":
			title = "ANCHOR 01 / INCIDENT AUDIT"
			body = _record_audit() if state.anchor_past and state.anchor_future else "AUDIT STORAGE SEALED\nStabilization required."
	ui.device_mount = stand
	ui.device_bindings = bindings
	ui.camera = camera
	ui.actor = player
	_rebuilding_panel = true
	ui.open_device(title, body, actions, code_entry)
	_rebuilding_panel = false
	if first_inspection and not thought.is_empty(): ui.observe("Professor" if role == "future" else "Student", thought)


func _request(action: String, payload: Dictionary = {}) -> void:
	if _disconnected or _leaving: return
	var result := PuzzleManager.submit_action(Rules.ID, action, payload, role)
	if result.status == PuzzleManager.Status.PENDING:
		ui.toast("Request sent. Waiting for confirmation.")
	elif result.status == PuzzleManager.Status.NO_CHANGE and not result.get("message", "").is_empty():
		ui.toast(result.message)
	elif result.status in [PuzzleManager.Status.CHANGED, PuzzleManager.Status.COMPLETED]:
		if not sound.owns_action(action): audio.play_sfx(&"switch_toggle")


func _on_rejected(id: String, _action: String, reason: String, actor_role: String) -> void:
	if id != Rules.ID or actor_role != role: return
	var messages := {"isolate_service_first": "Ask the Student to isolate SERVICE first.",
		"past_auxiliary_feed_offline": "The Student's auxiliary feed is offline. Repair both bypass ends.",
		"future_auxiliary_feed_offline": "The Professor's auxiliary feed is offline. Repair both bypass ends.",
		"repair_both_bypass_ends": "Repair the Past fuse and Future ground lead before exporting.",
		"resolve_archive_recording": "Read the archive and resolve its recorder transfer first.",
		"await_core_authorization": "Waiting for the Student's code authorization.",
		"repair_archive_first": "Inspect the archive damage and install all three preserved replacements.",
		"return_future_item_first": "Return or lower the Future tray before changing the Past contents.",
		"restore_power_first": "Restore the service power before using the storage equipment."}
	ui.toast(messages.get(reason, reason.replace("_", " ").capitalize()))
	audio.play_sfx(&"interaction_denied")


func _on_state_changed(id: String, next: Dictionary, _revision: int) -> void:
	if id != Rules.ID: return
	var previous := state
	state = next
	if not _initialized: return
	sound.on_state(previous, state)
	if state.archive_read and not previous.get("archive_read", false): _queue_line("identity")
	if state.recording != "pending" and previous.get("recording", "pending") == "pending": _queue_line(String(state.recording))
	if state.anchor_past and state.anchor_future and not (previous.get("anchor_past", false) and previous.get("anchor_future", false)):
		_queue_line("ending_" + String(state.recording))
	_apply_state(true)


func _queue_line(key: String) -> void:
	var seen: Dictionary = PuzzleManager.get_meta("maintenance_story_seen", {})
	var id := "%d/%s/%s" % [PuzzleManager.get_session_id(), role, key]
	if seen.has(id) or key in _pending_lines: return
	_pending_lines.append(key)


func _sync_story_from_state() -> void:
	if state.is_empty(): return
	if state.anchor_past and state.anchor_future:
		_queue_line("ending_" + String(state.recording))
		return
	_queue_line("arrival")
	if state.archive_read: _queue_line("identity")
	if state.recording != "pending": _queue_line(String(state.recording))


func _record_audit() -> String:
	var text := "23:44 / MANUAL ACTIVATION\n"
	text += "Operator credential: appointment file match.\nContainment risk acknowledged.\nAutomatic abort disabled." if state.recording == "preserved" else "Operator credential: BUFFER ERASED.\nPhysical cell extraction logged.\nMemory transfer incomplete."
	return text + "\n\nAnchor 01 stable.\nSecondary carrier detected."


func _audit_text() -> String:
	var text := "ANCHOR 01 STABLE. The recovered monitoring map shows other unresolved fractures. A second signal is answering.\n\n"
	if state.recording == "preserved":
		text += "FUTURE ACTIVATION AUDIT\nOperator: THE PROFESSOR.\nContainment failure risk acknowledged.\nAutomatic abort disabled.\nManual activation confirmed.\n\nStudent: You knew. Why did you do it?\nThe Professor does not answer."
	else:
		text += "FUTURE ACTIVATION AUDIT\nOperator authorization: BUFFER ERASED.\nTransfer aborted by physical cell extraction at the Future recorder.\n\nStudent: The removal command came from your terminal. What was on that recording?\nThe Professor does not answer."
	text += "\n\nDISTRIBUTION HISTORY\nReserve priority: %s.\nShared bypass: %s.\nRecording: %s." % [String(state.priority).to_upper(), "REPAIRED" if Rules.bypass_ready(state) else "INCOMPLETE", String(state.recording).to_upper()]
	return text


func _process(delta: float) -> void:
	if not _initialized or _leaving: return
	storage.update_carry()
	_refresh_wayfinding(delta)
	if player.position.y < -3: respawn()
	_sync_controls()
	if not _pending_lines.is_empty() and not GameFlowManager.is_input_locked() and not ui.is_modal_open() and not _paused and not _disconnected and not director.is_dialogue_active() and not player.is_action_active():
		var key: String = _pending_lines.pop_front()
		# Load the small dialogue resource on the scene thread when it is needed.
		# Preloading scripted resources here during threaded room loading leaks native
		# RefCounted instances in Godot 4.7; the map itself still loads in the background.
		if director.play_dialogue(load(SEQUENCES[key]), {"timeline": role}):
			var seen: Dictionary = PuzzleManager.get_meta("maintenance_story_seen", {})
			seen["%d/%s/%s" % [PuzzleManager.get_session_id(), role, key]] = true
			PuzzleManager.set_meta("maintenance_story_seen", seen)


func _on_modal_changed(open: bool) -> void:
	if not open and not _rebuilding_panel: _active_device = ""
	if _initialized: _sync_controls()


func _sync_controls() -> void:
	var transitioning := GameFlowManager.is_input_locked()
	var blocked: bool = transitioning or _paused or _disconnected or ui.is_modal_open() or (ending_screen != null and ending_screen.visible)
	$HUD.visible = not ui.inspector.active
	ui.inspector.suspended = transitioning or _paused or _disconnected or (ending_screen != null and ending_screen.visible)
	ui.set_overlay_blocked(ui.inspector.suspended)
	player.controls_enabled = not blocked
	if blocked: player.velocity = Vector3.ZERO
	controller.set_interaction_blocked(blocked)
	prompt.set_interaction_blocked(blocked)
	director.process_mode = Node.PROCESS_MODE_DISABLED if blocked else Node.PROCESS_MODE_INHERIT
	director.dialogue_box.visible = not blocked
	role_button.disabled = NetworkManager.in_game or blocked or player.is_action_active()


func _input(event: InputEvent) -> void:
	if pause_menu != null and pause_menu.handle_input(event): return
	if not _initialized or ui.is_modal_open() or GameFlowManager.is_input_locked(): return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if ending_screen.visible:
			ending_screen.hide()
			_ending_dismissed = true
		else: set_paused(not _paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("switch_role") and not event.is_echo() and not _paused:
		switch_role()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and not _paused:
		if event.physical_keycode == KEY_R and not player.is_action_active(): respawn()
		elif event.physical_keycode == KEY_E and player.controls_enabled and role == "past" and not state.storage.past_hand.is_empty() and not player.is_action_active():
			if player.position.z <= -3.3 and player.position.z >= -8.5:
				var drop := Vector3(clampf(player.position.x, -6.6, 6.6), 0, clampf(player.position.z + 0.5, -8.5, -3.3))
				_request("drop_storage_item", {"position": drop})
			else: ui.toast("Put equipment down inside the storage room.")
			get_viewport().set_input_as_handled()


func respawn() -> void:
	player.position = Vector3(0, 0.05, 7.5)
	player.velocity = Vector3.ZERO
	$CameraRig.snap_to_target()


func set_paused(value: bool) -> void:
	if _disconnected and not value: return
	if _paused != value: audio.play_ui(&"ui_pause" if value else &"ui_unpause")
	_paused = value
	pause_menu.present(value)
	if settings_overlay != null: settings_overlay.hide()
	_sync_controls()


func is_gameplay_paused() -> bool:
	return _paused or _disconnected or GameFlowManager.is_input_locked() or ui.is_modal_open() or (ending_screen != null and ending_screen.visible)


func _notification(what: int) -> void:
	if not is_node_ready() or not _initialized: return
	if what == NOTIFICATION_WM_CLOSE_REQUEST: set_paused(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and pause_when_unfocused: set_paused(true)


func _on_network_changed() -> void:
	if _leaving or not get_meta("started_networked", false): return
	if not NetworkManager.in_game or NetworkManager.state != NetworkManager.State.CONNECTED:
		_disconnected = true
		ui.close_modal()
		director.stop_dialogue()
		set_paused(true)
		pause_menu.label("PauseTitle").text = "The connection was lost"
		pause_menu.button("ResumeButton").disabled = true


func return_to_menu() -> void:
	if _leaving: return
	_leaving = true
	director.stop_dialogue()
	ui.close_modal()
	NetworkManager.leave_game()
	PuzzleManager.reset_all()
	get_tree().change_scene_to_file.call_deferred("res://scenes/menu/main_menu.tscn")


func _exit_tree() -> void:
	if is_instance_valid(audio):
		audio.stop_all_sfx()
		audio.stop_ambience(0.0)
		audio.stop_music(0.0)


func game_flow_suspend() -> void:
	ui.close_modal()
	director.stop_dialogue()
	_sync_controls()


func is_game_flow_ready() -> bool:
	return _initialized and is_instance_valid(player) and is_instance_valid(radio) and camera.current


func _hud_label(text: String, size: int = 20) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("e6deca"))
	return label


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180, 42)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


## Pause and ending screens use the title screen's buttons so every level shares one menu.
func _menu_button(parent: Node, text: String, callback: Callable, variation: StringName = &"SecondaryButton") -> Button:
	var button := TemporalButton.apply(Button.new(), variation)
	button.text = text
	button.custom_minimum_size = Vector2(0, 60 if variation == &"PrimaryButton" else 54)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _build_hud() -> void:
	set_meta("started_networked", NetworkManager.in_game)
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	layer.layer = 5
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var header := PanelContainer.new()
	header.name = "Header"
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 16
	header.offset_top = 12
	header.offset_right = -16
	header.offset_bottom = 64
	var header_style := LabUI._panel_style(Color(0.035, 0.065, 0.08, 1.0), Color("647b7a"), 1)
	header_style.content_margin_left = 16
	header_style.content_margin_right = 16
	header_style.content_margin_top = 8
	header_style.content_margin_bottom = 8
	header.add_theme_stylebox_override("panel", header_style)
	root.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	header.add_child(row)
	timeline_label = _hud_label("", 16)
	timeline_label.custom_minimum_size.x = 64
	timeline_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(timeline_label)
	var room_title := _hud_label("MAINTENANCE CORRIDOR", 16)
	room_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(room_title)
	role_button = _button(row, "SWITCH [T]", switch_role)
	role_button.visible = not NetworkManager.in_game
	pause_button = _button(row, "PAUSE", func() -> void: set_paused(true))
	for button in [role_button, pause_button]:
		button.custom_minimum_size = Vector2(0, 32)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", 16)
	var overlays := CanvasLayer.new()
	overlays.name = "Overlays"
	overlays.layer = 30
	add_child(overlays)
	pause_menu = load("res://scenes/ui/pause_menu.tscn").instantiate()
	add_child(pause_menu)
	pause_menu.configure(self, audio, func() -> String: return role, set_paused, reset_solo_session, return_to_menu)
	pause_screen = pause_menu.panel
	settings_overlay = pause_menu.settings
	ending_screen = _overlay(overlays, "Ending")


func _overlay(parent: Node, node_name: String) -> Control:
	var dim := ColorRect.new()
	dim.name = node_name
	dim.color = Color(0.015, 0.03, 0.045, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	TemporalButton.theme_for(dim)
	parent.add_child(dim)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -490
	panel.offset_right = 490
	panel.offset_top = -360
	panel.offset_bottom = 360
	var panel_style := LabUI._panel_style(Color("12252d"), Color("92b7b5"), 2)
	panel_style.content_margin_left = 28
	panel_style.content_margin_right = 28
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", panel_style)
	dim.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	dim.hide()
	return dim


func _show_ending() -> void:
	if ending_screen.visible: return
	ui.close_modal()
	var box := ending_screen.get_node("Panel/Box")
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	box.add_child(_hud_label("CHAPTER COMPLETE / PLAYER SUMMARY", 29))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var content := _hud_label(_audit_text(), 20)
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_menu_button(box, "INSPECT THE STABILIZED CORE", func() -> void:
		_ending_dismissed = true
		ending_screen.hide()
		_sync_controls()
	, &"PrimaryButton")
	_menu_button(box, "RETURN TO MAIN MENU", return_to_menu)
	ending_screen.show()
	_sync_controls()


func _refresh_hud() -> void:
	var message := ""
	if state.anchor_past and state.anchor_future:
		message = "Anchor 01 is stable. Inspect the recovered Core audit."
	elif state.core_authorized and state.future_release_open:
		message = "Enter the Core and latch both stabilization controls."
	elif state.recording != "pending":
		message = "Student: authorize the Core. Professor: turn the manual release."
	elif state.archive_read:
		message = "Recover the incident recording. The isolated bypass can preserve its buffer."
	elif state.battery_ready and not Rules.Storage.repaired(state):
		message = "Professor: inspect archive damage and shipping record. Student: weigh cases, then lower each tray underground."
	elif state.battery_ready:
		message = "Read the repaired maintenance archive for Core access."
	elif state.service_isolated:
		message = "Professor: charge the local emergency battery."
	else:
		message = "Student: isolate SERVICE. Professor: inspect the emergency-cell charging instructions."
	if state.battery_ready and not Rules.has_power(state, role):
		message = "AUXILIARY FEED OFFLINE / Repair the Past fuse and Future ground lead."
	ui.set_guidance(message)
	timeline_label.text = role.to_upper()
	timeline_label.add_theme_color_override("font_color", LabUI.FUTURE_ACCENT if role == "future" else LabUI.PAST_ACCENT)


func reset_solo_session() -> void:
	if NetworkManager.in_game: return
	PuzzleManager.begin_session()
	PuzzleManager.offline_role = "past"
	get_tree().change_scene_to_file.call_deferred("res://scenes/world/spawn_area.tscn")
