@tool
extends Node2D
## Eight-view illustrated cutout rig. All motion is drawn in 2D, then shown in 3D.

signal animation_finished(animation_name: String)

const ATLAS_DATA: Script = preload("res://scripts/characters/student_atlas_regions.gd")
const REGIONS: Dictionary = ATLAS_DATA.REGIONS
const POSES: Dictionary = preload("res://scripts/characters/student_direction_poses.gd").POSES
const JOINT_ANCHORS: Dictionary = ATLAS_DATA.JOINT_ANCHORS
const TORSO_SHEET: Texture2D = preload("res://assets/characters/student_2d/torso_corrections.png")
const DIRECTIONS: Array[String] = ["south", "south_west", "west", "north_west", "north", "north_east", "east", "south_east"]
const SHEETS: Dictionary = {
	"south": preload("res://assets/characters/student_2d/south_parts.png"),
	"south_west": preload("res://assets/characters/student_2d/south_west_parts.png"),
	"west": preload("res://assets/characters/student_2d/west_parts.png"),
	"north_west": preload("res://assets/characters/student_2d/north_west_parts.png"),
	"north": preload("res://assets/characters/student_2d/north_parts.png"),
	"north_east": preload("res://assets/characters/student_2d/north_east_parts.png"),
	"east": preload("res://assets/characters/student_2d/east_parts.png"),
	"south_east": preload("res://assets/characters/student_2d/south_east_parts.png")
}
const CLIPS: Dictionary = {
	"idle": {"duration": 2.8, "loop": true, "label": "Idle / breathe / blink"},
	"walk": {"duration": 0.85, "loop": true, "label": "Walk"},
	"run": {"duration": 0.55, "loop": true, "label": "Run"},
	"interact": {"duration": 0.95, "loop": false, "label": "Interact / use terminal"},
	"inspect": {"duration": 2.2, "loop": false, "label": "Inspect / read"},
	"pick_up": {"duration": 1.2, "loop": false, "label": "Pick up"},
	"put_down": {"duration": 1.15, "loop": false, "label": "Put down"},
	"carry_idle": {"duration": 2.8, "loop": true, "label": "Carry / idle"},
	"carry_walk": {"duration": 0.95, "loop": true, "label": "Carry / walk"},
	"push": {"duration": 1.15, "loop": true, "label": "Push"},
	"pull": {"duration": 1.15, "loop": true, "label": "Pull"},
	"react": {"duration": 1.0, "loop": false, "label": "Temporal shock / react"},
	"arrive": {"duration": 1.9, "loop": false, "label": "Arrive / regain balance"}
}

var animation_name: String = "idle"
var facing: String = "south"
var animation_time: float = 0.0
var paused: bool = false
var playback_speed: float = 1.0
var holding_object: bool = false
var palette_tint: Color = Color.WHITE:
	set(value):
		palette_tint = value
		if is_instance_valid(_body):
			_body.modulate = value

var _body: Node2D
var _sprites: Dictionary = {}
var _textures: Dictionary = {}
var _blink_clock: float = 0.0


func _ready() -> void:
	_build_textures()
	_body = Node2D.new()
	_body.name = "IllustratedBody"
	_body.z_index = 10
	_body.modulate = palette_tint
	add_child(_body)
	for part in ["head", "torso", "pelvis", "right_arm", "right_forearm", "left_arm", "left_forearm", "right_thigh", "right_shin", "left_thigh", "left_shin", "bag", "document"]:
		var sprite := Sprite2D.new()
		sprite.name = part
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_body.add_child(sprite)
		_sprites[part] = sprite
	_apply_pose()


func _build_textures() -> void:
	var data: Dictionary = REGIONS
	for direction in DIRECTIONS:
		var frames: Array[Texture2D] = []
		for part_index in range(16):
			var bounds: Array = ATLAS_DATA.TORSO_REGIONS[direction] if part_index == 1 else data[direction][part_index]
			var texture := AtlasTexture.new()
			texture.atlas = TORSO_SHEET if part_index == 1 else SHEETS[direction]
			texture.region = Rect2(bounds[0], bounds[1], bounds[2], bounds[3])
			texture.filter_clip = true
			frames.append(texture)
		_textures[direction] = frames


func set_facing(direction: Vector2) -> void:
	if direction.length_squared() < 0.001:
		return
	var angle := fposmod(atan2(-direction.x, direction.y), TAU)
	set_view(DIRECTIONS[int(round(angle / (PI / 4.0))) % 8])


func set_view(direction: String) -> void:
	if direction not in DIRECTIONS:
		return
	facing = direction
	if is_instance_valid(_body):
		_apply_pose()


func play(clip: String, restart: bool = false) -> void:
	if clip not in CLIPS or (clip == animation_name and not restart):
		return
	animation_name = clip
	animation_time = 0.0
	if is_instance_valid(_body):
		_apply_pose()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		advance(delta * playback_speed)


func advance(delta: float) -> void:
	if paused or not is_instance_valid(_body):
		return
	_blink_clock += delta
	animation_time += delta
	var definition: Dictionary = CLIPS[animation_name]
	if animation_time >= float(definition.duration):
		if definition.loop:
			animation_time = fmod(animation_time, float(definition.duration))
		else:
			var finished := animation_name
			animation_name = "idle"
			animation_time = 0.0
			animation_finished.emit(finished)
	_apply_pose()


func _place(part: String, slot: int, at: Vector2, height: float, angle: float = 0.0, depth: int = 0) -> void:
	var sprite: Sprite2D = _sprites[part]
	var texture: Texture2D = _textures[facing][slot]
	sprite.texture = texture
	sprite.position = at
	sprite.scale = Vector2.ONE * (height / float(texture.get_height()))
	sprite.rotation = angle
	sprite.flip_h = facing == "east" and part == "left_shin"
	sprite.z_index = depth
	sprite.visible = true


func _attach_head(slot: int, neck: Vector2, angle: float) -> void:
	var texture: Texture2D = _textures[facing][slot]
	var anchor: Array = JOINT_ANCHORS[facing][slot][1]
	var scale_factor := 112.0 / texture.get_height()
	var offset := (Vector2(anchor[0], anchor[1]) - Vector2.ONE * 0.5) * texture.get_size() * scale_factor
	_place("head", slot, neck - offset.rotated(angle), 112.0, angle, 12)


func _bone(part: String, slot: int, start: Vector2, end: Vector2, depth: int) -> void:
	var sprite: Sprite2D = _sprites[part]
	var texture: Texture2D = _textures[facing][slot]
	var anchors: Array = JOINT_ANCHORS[facing][slot]
	var size := texture.get_size()
	var source_start := Vector2(anchors[0][0], anchors[0][1]) * size
	var source_end := Vector2(anchors[1][0], anchors[1][1]) * size
	var flipped := facing == "east" and part == "left_shin"
	if flipped:
		source_start.x = size.x - source_start.x
		source_end.x = size.x - source_end.x
	var source_axis := source_end - source_start
	var target_axis := end - start
	var scale_factor := target_axis.length() / maxf(source_axis.length(), 1.0)
	var rotation_angle := target_axis.angle() - source_axis.angle()
	sprite.texture = texture
	sprite.scale = Vector2.ONE * scale_factor
	sprite.rotation = rotation_angle
	sprite.position = start - ((source_start - size * 0.5) * scale_factor).rotated(rotation_angle)
	sprite.flip_h = flipped
	sprite.z_index = depth
	sprite.visible = true


func _joint(start: Vector2, end: Vector2, upper: float, lower: float, bend: float) -> Vector2:
	var difference := end - start
	var distance := clampf(difference.length(), absf(upper - lower) + 0.1, upper + lower - 0.1)
	var axis := difference.normalized()
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var perpendicular := Vector2(-axis.y, axis.x)
	return start + axis * along + perpendicular * sqrt(maxf(0.0, upper * upper - along * along)) * bend


func _point(value: Array) -> Vector2:
	return Vector2(value[0], value[1])


func _apply_pose() -> void:
	var bind_pose: Dictionary = POSES[facing]
	var angle := DIRECTIONS.find(facing) * PI / 4.0
	var lateral := cos(angle)
	var heading := Vector2(-sin(angle), cos(angle) * 0.28)
	var time := animation_time / float(CLIPS[animation_name].duration)
	var cycle := time * TAU
	var stride := 0.0
	var lift := 0.0
	var crouch := 0.0
	var lean := 0.0
	var reach := 0.0
	var read := 0.0
	var carry := 1.0 if holding_object or animation_name.begins_with("carry") else 0.0
	var recoil := 0.0
	var head_tilt := 0.0
	if animation_name in ["walk", "run", "carry_walk"]:
		stride = sin(cycle) * (45.0 if animation_name == "run" else 27.0)
		lift = 26.0 if animation_name == "run" else 16.0
		lean = 0.10 if animation_name == "run" else 0.02
	elif animation_name == "interact":
		reach = sin(PI * time)
	elif animation_name == "inspect":
		read = minf(time * 5.0, 1.0) * minf((1.0 - time) * 5.0, 1.0)
		head_tilt = read * 0.11
	elif animation_name in ["pick_up", "put_down"]:
		crouch = sin(PI * time)
		lean = crouch * 0.20
		carry = clampf((time - 0.45) * 8.0, 0.0, 1.0) if animation_name == "pick_up" else 1.0 - clampf((time - 0.45) * 8.0, 0.0, 1.0)
	elif animation_name in ["push", "pull"]:
		reach = 0.85 + 0.10 * sin(cycle)
		lean = 0.16 if animation_name == "push" else -0.13
		stride = sin(cycle) * 9.0
		lift = 5.0
	elif animation_name == "react":
		recoil = sin(PI * time) * (1.0 - time)
		lean = -recoil * 0.30
	elif animation_name == "arrive":
		recoil = exp(-time * 5.0) * sin(time * PI * 5.0)
		head_tilt = sin(time * TAU) * 0.14 * (1.0 - time)
	var breath := sin(_blink_clock * 2.1) * 1.1
	var bob := absf(sin(cycle)) * (3.5 if animation_name == "run" else 1.5) if lift > 0 else 0.0
	_body.position = Vector2(recoil * 10.0, 0)
	var hip_y := -230.0 + crouch * 42.0 - bob
	var torso_at := Vector2(heading.x * lean * 95.0, hip_y - 91.0 + breath)
	var torso_rotation := -heading.x * lean
	_place("pelvis", 2, Vector2(0, hip_y - 1), 76.0, 0, -2)
	_place("torso", 1, torso_at, 160.0, torso_rotation, 0)
	var neck_at := torso_at + _point(bind_pose.neck).rotated(torso_rotation)
	var blink := fmod(_blink_clock, 4.7) > 4.55
	_attach_head(12 if blink else 0, neck_at, torso_rotation + head_tilt)
	var bag_at := _point(bind_pose.bag) + Vector2(0, hip_y) + heading * sin(cycle + 0.4) * (absf(stride) * 0.08)
	_place("bag", 11, bag_at, 96.0, -heading.x * sin(cycle) * absf(stride) * 0.002, int(bind_pose.bag_depth))
	var held_at := torso_at + Vector2(heading.x * 65.0, 25.0)
	for side in [-1, 1]:
		var right: bool = side == -1
		var prefix := "right" if right else "left"
		var phase := cycle + (0.0 if right else PI)
		var step := stride * (1.0 if right else -1.0)
		var foot := _point(bind_pose[prefix + "_foot"]) + heading * step
		foot.y -= maxf(0.0, sin(phase)) * lift
		var hip := _point(bind_pose[prefix + "_hip"]) + Vector2(0, hip_y)
		var bend: float = bind_pose[prefix + "_bend"]
		var knee := _joint(hip, foot, 110.0, 120.0, bend)
		var limb_depth: int = bind_pose[prefix + "_leg_depth"]
		_bone(prefix + "_thigh", 7 if right else 9, hip, knee, limb_depth)
		_bone(prefix + "_shin", 8 if right else 10, knee, foot, limb_depth + 1)
		var shoulder := torso_at + _point(bind_pose[prefix + "_shoulder"]).rotated(torso_rotation)
		var hand := shoulder + Vector2(side * lateral * 3.0, 172.0)
		hand -= heading * step * 0.85
		hand.y -= cos(angle) * step * 0.35
		hand += heading * reach * 87.0 + Vector2(0, -reach * 80.0)
		hand.y -= recoil * 85.0
		hand = hand.lerp(held_at + Vector2(side * lateral * 44.0, 4.0), maxf(carry, read))
		if crouch > 0.0:
			hand = hand.lerp(Vector2(side * 23.0, hip_y + 125.0), crouch)
		# IK clamps its solve distance; clamp the target too so the forearm artwork
		# cannot stretch past the fixed arm lengths during low or distant reaches.
		hand = shoulder + (hand - shoulder).limit_length(173.9)
		var arm_bend := signf(heading.x) if absf(heading.x) > 0.1 and maxf(reach, maxf(carry, read)) > 0.1 else bend
		var elbow := _joint(shoulder, hand, 78.0, 96.0, arm_bend)
		var arm_depth: int = bind_pose[prefix + "_hand_depth"]
		if facing == "north" and maxf(carry, read) > 0.1:
			arm_depth = -3
		_bone(prefix + "_arm", 3 if right else 5, shoulder, elbow, int(bind_pose[prefix + "_arm_depth"]))
		var forearm_slot := (13 if right else 14) if maxf(carry, maxf(read, reach)) > 0.4 else (4 if right else 6)
		_bone(prefix + "_forearm", forearm_slot, elbow, hand, arm_depth)
	_place("document", 15, held_at, 68.0, -0.12 * lateral, -3 if cos(angle) < -0.1 else 6)
	_sprites.document.visible = maxf(carry, read) > 0.1
