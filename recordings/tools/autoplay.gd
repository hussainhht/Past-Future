extends Node
## QA playthrough harness (temporary, recording only). Activated by `-- --ap-role=host|client|solo` user args.
## It drives the game ONLY through the real input pipeline (Input.parse_input_event key / mouse events),
## so every action goes through the same code paths as a human player. It reads runtime state to decide
## where to walk and to verify that actions worked; it never edits puzzle or game state.

var args: Dictionary = {}
var role := ""
var tag := ""
var _log: FileAccess
var _t0 := 0
var held: Dictionary = {}
var _nav_cache: Dictionary = {}
var sprint_default := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ap-"):
			var kv := a.substr(5).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.is_empty():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	role = args.get("role", "solo")
	tag = role
	_t0 = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://recordings/logs"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://recordings/screenshots"))
	_log = FileAccess.open(ProjectSettings.globalize_path("res://recordings/logs/%s.log" % tag), FileAccess.WRITE)
	if args.has("timescale"):
		Engine.time_scale = float(args.timescale)
	say("AutoPlay harness started role=%s args=%s" % [role, str(args)])
	_run.call_deferred()


func say(text: String) -> void:
	var line := "[%7.2f f%06d %s] %s" % [(Time.get_ticks_msec() - _t0) / 1000.0, Engine.get_process_frames(), tag, text]
	print(line)
	if _log:
		_log.store_line(line)
		_log.flush()


func _run() -> void:
	var script_name: String = args.get("script", "playthrough")
	var script: GDScript = load("res://recordings/tools/ap_%s.gd" % script_name)
	var runner = script.new()
	await runner.run(self)
	say("Script finished.")
	if args.has("quit_when_done"):
		get_tree().quit()


# ---------------------------------------------------------------- timing / waiting

func sec(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## Waits until `cond` is true. Returns false (and logs) on timeout.
func until(cond: Callable, timeout: float, label: String = "") -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	say("TIMEOUT waiting for: %s" % label)
	return false


# ---------------------------------------------------------------- real input events

func key_event(code: int, pressed: bool, shift: bool = false) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.key_label = code
	e.pressed = pressed
	e.shift_pressed = shift
	Input.parse_input_event(e)


func tap(code: int, hold: float = 0.09, shift: bool = false) -> void:
	key_event(code, true, shift)
	await sec(hold)
	key_event(code, false, shift)
	await sec(0.06)


func press_f() -> void:
	await tap(KEY_F)


func hold_keys(codes: Array) -> void:
	for code in held.keys():
		if not codes.has(code) and held[code]:
			key_event(code, false)
			held[code] = false
	for code in codes:
		if not held.get(code, false):
			key_event(code, true)
			held[code] = true


func release_all() -> void:
	hold_keys([])


func mouse_move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)


func mouse_button(pos: Vector2, pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.global_position = pos
	e.button_index = button
	e.pressed = pressed
	e.button_mask = (1 << (button - 1)) if pressed else 0
	Input.parse_input_event(e)


func click(pos: Vector2) -> void:
	mouse_move(pos)
	await sec(0.12)
	mouse_button(pos, true)
	await sec(0.08)
	mouse_button(pos, false)
	await sec(0.12)


func wheel(pos: Vector2, up: bool, shift: bool = false) -> void:
	mouse_move(pos)
	var e := InputEventMouseButton.new()
	e.position = pos
	e.global_position = pos
	e.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	e.pressed = true
	e.shift_pressed = shift
	Input.parse_input_event(e)
	await sec(0.05)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await sec(0.05)


## Clicks a UI Control at its centre, using its on-screen rectangle (viewport coordinates).
func click_control(c: Control) -> void:
	var rect := c.get_global_rect()
	await click(to_window(rect.get_center()))


## Viewport (virtual canvas) coordinates -> window pixels, which is what injected mouse events expect.
func to_window(pos: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * pos


# ---------------------------------------------------------------- scene queries

func scene() -> Node:
	return get_tree().current_scene


func find_all(node: Node, class_name_: String, out: Array = []) -> Array:
	for child in node.get_children():
		if child.get_class() == class_name_ or (child.get_script() != null and child.get_script().get_global_name() == class_name_):
			out.append(child)
		find_all(child, class_name_, out)
	return out


func find_buttons(root: Node, out: Array = []) -> Array:
	for child in root.get_children():
		if child is BaseButton:
			out.append(child)
		find_buttons(child, out)
	return out


func button_by_text(text: String) -> BaseButton:
	for b in find_buttons(get_tree().root):
		if b.is_visible_in_tree() and b.text.strip_edges().to_upper().contains(text.to_upper()) and not b.disabled:
			return b
	return null


func player() -> CharacterBody3D:
	var room := scene()
	if room == null:
		return null
	var p = room.get("player")
	if p is CharacterBody3D and is_instance_valid(p):
		return p
	for n in room.find_children("*", "CharacterBody3D", true, false):
		if "controls_enabled" in n:
			return n
	return null


func camera() -> Camera3D:
	return get_viewport().get_camera_3d()


## First enabled interactable whose path contains `needle` that the local role may use.
func find_int(needle: String) -> Node:
	var r := local_role()
	for i in interactables():
		if str(i.get_path()).contains(needle) and i.interaction_enabled and i.is_timeline_allowed(r) and i.is_visible_in_tree():
			return i
	return null


func interactables() -> Array:
	var out: Array = []
	var room := scene()
	if room == null:
		return out
	for n in room.find_children("*", "Area3D", true, false):
		if n.has_method("get_interaction_prompt") and n.has_method("can_interact"):
			out.append(n)
	return out


func local_role() -> String:
	return PuzzleManager.get_local_role()


func interactable_info(i: Node) -> String:
	var p: Vector3 = i.get_interaction_position()
	return "%s | '%s' | at (%.2f, %.2f, %.2f) | en=%s tl=%d dist=%.1f | %s" % [str(i.get_path()).trim_prefix("/root/"), i.interaction_name, p.x, p.y, p.z,
		str(i.interaction_enabled), i.allowed_timeline, i.interaction_distance, "visible" if i.is_visible_in_tree() else "hidden"]


func dump_interactables() -> void:
	for i in interactables():
		say("INT " + interactable_info(i))
	var p := player()
	if p:
		say("PLAYER at %s mask=%d layer=%d" % [str(p.global_position), p.collision_mask, p.collision_layer])


func screenshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://recordings/screenshots/%s_%s.png" % [label, tag])
	img.save_png(path)
	say("screenshot %s" % path.get_file())


# ---------------------------------------------------------------- dialogue / modal handling

func dialogue_active() -> bool:
	for d in get_tree().get_nodes_in_group(DialogueDirector.GROUP):
		if d.is_dialogue_active():
			return true
	return false


## Reads each dialogue line (lets the typewriter finish, dwells so viewers can read) then presses interact.
func read_dialogue(max_seconds: float = 120.0, dwell: float = 1.6) -> int:
	var lines := 0
	var end := Time.get_ticks_msec() + int(max_seconds * 1000.0)
	while dialogue_active() and Time.get_ticks_msec() < end:
		var d: DialogueDirector = null
		for cand in get_tree().get_nodes_in_group(DialogueDirector.GROUP):
			if cand.is_dialogue_active():
				d = cand
		if d == null:
			break
		var line = d.get_current_line()
		var text := ""
		if line != null:
			text = str(line.get("text"))
		# wait for the typewriter to finish (state WAITING_FOR_INPUT)
		var typed := await until(func() -> bool: return not d.is_dialogue_active() or d.get_state() == DialogueDirector.State.WAITING_FOR_INPUT, 7.0, "typewriter")
		if not d.is_dialogue_active():
			break
		if typed:
			say("DIALOGUE: %s" % text.replace("\n", " ").left(140))
			await sec(clampf(dwell + text.length() * 0.018, 1.2, 4.5))
			lines += 1
		await tap(KEY_SPACE)
		await sec(0.15)
	return lines


## Like until(), but keeps reading any dialogue that blocks input while waiting (so neither player stalls).
func wait_for(cond: Callable, timeout: float, label: String = "") -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		if dialogue_active():
			await read_dialogue(90.0)
			end += 6000
		await get_tree().process_frame
	say("TIMEOUT waiting for: %s" % label)
	return false


# ---------------------------------------------------------------- navigation

const CELL := 0.25


class Grid:
	var astar := AStarGrid2D.new()
	var origin := Vector2.ZERO


func _build_grid(center: Vector3, half: float, p: CharacterBody3D) -> Grid:
	var g := Grid.new()
	var cells := int(half * 2.0 / CELL)
	g.origin = Vector2(center.x - half, center.z - half)
	g.astar.region = Rect2i(0, 0, cells, cells)
	g.astar.cell_size = Vector2(CELL, CELL)
	g.astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	g.astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	g.astar.update()
	var space := p.get_world_3d().direct_space_state
	var shape := CylinderShape3D.new()
	shape.radius = 0.34
	shape.height = 0.4
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = p.collision_mask
	q.exclude = [p.get_rid()]
	q.collide_with_areas = false
	q.collide_with_bodies = true
	for x in cells:
		for z in cells:
			var w := Vector3(g.origin.x + (x + 0.5) * CELL, 0.25, g.origin.y + (z + 0.5) * CELL)
			q.transform = Transform3D(Basis.IDENTITY, w)
			if not space.intersect_shape(q, 1).is_empty():
				g.astar.set_point_solid(Vector2i(x, z), true)
	return g


func _cell(g: Grid, w: Vector3) -> Vector2i:
	return Vector2i(int((w.x - g.origin.x) / CELL), int((w.z - g.origin.y) / CELL))


func _world(g: Grid, c: Vector2i) -> Vector3:
	return Vector3(g.origin.x + (c.x + 0.5) * CELL, 0.0, g.origin.y + (c.y + 0.5) * CELL)


func _nearest_free(g: Grid, c: Vector2i) -> Vector2i:
	if g.astar.is_in_boundsv(c) and not g.astar.is_point_solid(c):
		return c
	for r in range(1, 20):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if max(abs(dx), abs(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if g.astar.is_in_boundsv(n) and not g.astar.is_point_solid(n):
					return n
	return c


## Path (array of world points) between two world positions, or [] when unreachable.
func plan(from: Vector3, to: Vector3, p: CharacterBody3D, half: float = 16.0) -> PackedVector3Array:
	var center := (from + to) * 0.5
	var g := _build_grid(center, maxf(half, from.distance_to(to) * 0.5 + 6.0), p)
	var a := _nearest_free(g, _cell(g, from))
	var b := _nearest_free(g, _cell(g, to))
	var ids := g.astar.get_id_path(a, b)
	var out := PackedVector3Array()
	for c in ids:
		out.append(_world(g, c))
	return out


func _move_dir(p: CharacterBody3D, dir: Vector3) -> void:
	var cam := camera()
	var right := cam.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var down := cam.global_basis.z
	down.y = 0.0
	down = down.normalized()
	var a := dir.dot(right)
	var b := dir.dot(down)
	var keys: Array = []
	var thr := 0.38
	if a > thr: keys.append(KEY_D)
	elif a < -thr: keys.append(KEY_A)
	if b > thr: keys.append(KEY_S)
	elif b < -thr: keys.append(KEY_W)
	hold_keys(keys)


## Walk to a world position, following an A* path built from the real collision world.
func walk_to(target: Vector3, tolerance: float = 0.35, timeout: float = 40.0, sprint: bool = false) -> bool:
	var p := player()
	if p == null:
		say("walk_to: no player")
		return false
	var end := Time.get_ticks_msec() + int(timeout * 1000.0)
	var path := plan(p.global_position, target, p)
	if path.is_empty():
		say("walk_to: NO PATH to %s" % str(target))
		return false
	var idx := 0
	var last_pos := p.global_position
	var last_move := Time.get_ticks_msec()
	var replans := 0
	while Time.get_ticks_msec() < end:
		p = player()
		if p == null:
			break
		if dialogue_active():
			release_all()
			await read_dialogue(60.0)
			last_move = Time.get_ticks_msec()
			end += 8000
		var pos := p.global_position
		var flat := Vector3(pos.x, 0, pos.z)
		if flat.distance_to(Vector3(target.x, 0, target.z)) <= tolerance:
			release_all()
			return true
		# advance along the path using a look-ahead point
		while idx < path.size() - 1 and flat.distance_to(path[idx]) < 0.45:
			idx += 1
		var look := idx
		while look < path.size() - 1 and flat.distance_to(path[look]) < 0.9:
			look += 1
		var dir := path[look] - flat
		dir.y = 0.0
		var to_goal := Vector3(target.x, 0, target.z) - flat
		if to_goal.length() < 0.8:
			# final approach: axis-wise dead-zone so digital keys settle instead of orbiting the goal
			var cam := camera()
			var right := cam.global_basis.x
			right.y = 0.0
			right = right.normalized()
			var down := cam.global_basis.z
			down.y = 0.0
			down = down.normalized()
			var ka: Array = []
			var ax := to_goal.dot(right)
			var ay := to_goal.dot(down)
			if ax > 0.1: ka.append(KEY_D)
			elif ax < -0.1: ka.append(KEY_A)
			if ay > 0.1: ka.append(KEY_S)
			elif ay < -0.1: ka.append(KEY_W)
			if ka.is_empty():
				release_all()
				return true
			hold_keys(ka)
		elif dir.length() > 0.05:
			_move_dir(p, dir.normalized())
		if (sprint or sprint_default) and to_goal.length() > 2.5:
			if not held.get(KEY_SHIFT, false):
				held[KEY_SHIFT] = true
				key_event(KEY_SHIFT, true)
		elif held.get(KEY_SHIFT, false):
			held[KEY_SHIFT] = false
			key_event(KEY_SHIFT, false)
		if pos.distance_to(last_pos) > 0.05:
			last_pos = pos
			last_move = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - last_move > 1500:
			replans += 1
			if replans > 4:
				say("walk_to: stuck near %s heading to %s" % [str(pos), str(target)])
				release_all()
				return false
			path = plan(pos, target, p)
			idx = 0
			last_move = Time.get_ticks_msec()
		await get_tree().physics_frame
	release_all()
	if held.get(KEY_SHIFT, false):
		key_event(KEY_SHIFT, false)
		held[KEY_SHIFT] = false
	var pl := player()
	say("walk_to: timeout heading to %s (pos %s ctrl=%s action=%s dlg=%s)" % [str(target), str(pl.global_position) if pl else "?", str(pl.controls_enabled) if pl else "?", str(pl.is_action_active()) if pl else "?", str(dialogue_active())])
	return false


## Walks next to an Interactable3D until the player's own detector selects it.
func approach(target: Node, max_seconds: float = 40.0) -> bool:
	var p := player()
	var anchor: Vector3 = target.get_interaction_position()
	# can_interact() uses the 3D distance from the player's feet, so account for the anchor height.
	var dy: float = anchor.y - p.global_position.y
	var reach: float = sqrt(maxf(0.09, pow(target.interaction_distance - 0.08, 2.0) - dy * dy))
	# choose a reachable standing cell within reach of the target
	var grid_half := 14.0
	var g := _build_grid((p.global_position + anchor) * 0.5, maxf(grid_half, p.global_position.distance_to(anchor) * 0.5 + 6.0), p)
	var best := Vector3.INF
	var best_d := INF
	var start := _nearest_free(g, _cell(g, p.global_position))
	for cx in range(g.astar.region.size.x):
		for cy in range(g.astar.region.size.y):
			var c := Vector2i(cx, cy)
			if g.astar.is_point_solid(c):
				continue
			var w := _world(g, c)
			var d := Vector2(w.x - anchor.x, w.z - anchor.z).length()
			if d > reach:
				continue
			# prefer cells close to the player, then check reachability for the best few
			var score := d * 1.0 + w.distance_to(p.global_position) * 0.04
			if score < best_d:
				if g.astar.get_id_path(start, c).size() > 0:
					best_d = score
					best = w
	if best == Vector3.INF:
		say("approach: no standing cell near %s" % str(target.get_path()))
		return false
	say("approach %s -> stand at %s" % [target.get_path().get_concatenated_names().right(40), str(best)])
	return await walk_to(best, 0.22, max_seconds)


func current_target_of_player() -> Node:
	var p := player()
	if p == null:
		return null
	var c = p.get_node_or_null("InteractionRig/InteractionController")
	return c.get_current_interactable() if c else null


## Walk to the interactable, wait for it to become the selected prompt target, then press F.
func use(target: Node, settle: float = 0.5) -> bool:
	if dialogue_active():
		await read_dialogue(90.0)
	if not await approach(target):
		return false
	var ok := await until(func() -> bool: return current_target_of_player() == target, 4.0, "target selected " + str(target.name))
	if not ok:
		say("use: current target is %s; nudging closer" % str(current_target_of_player()))
		var a: Vector3 = target.get_interaction_position()
		await walk_to(Vector3(a.x, 0, a.z), 0.3, 8.0)
		ok = await until(func() -> bool: return current_target_of_player() == target, 3.0, "target selected (retry) " + str(target.name))
		if not ok:
			return false
	await sec(settle)
	say("USE '%s'" % target.interaction_name)
	await press_f()
	return true
