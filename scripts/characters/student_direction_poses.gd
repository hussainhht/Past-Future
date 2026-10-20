extends RefCounted
## Authored turnaround bind poses, in rig pixels. Anatomical left/right stay fixed.
## Values are independent of artwork bounding boxes and of animation time.
const POSES: Dictionary = {
	"south": {
		"right_shoulder": [-54,-52], "left_shoulder": [54,-52],
		"right_hip": [-25,0], "left_hip": [25,0], "right_foot": [-25,0], "left_foot": [25,0],
		"right_bend": 1.0, "left_bend": -1.0,
		"right_arm_depth": -1, "left_arm_depth": -1, "right_hand_depth": 8, "left_hand_depth": 8,
		"right_leg_depth": -4, "left_leg_depth": -3, "bag": [-77,12], "bag_depth": -4, "neck": [0,-54]
	},
	"south_west": {
		"right_shoulder": [-29,-55], "left_shoulder": [42,-51],
		"right_hip": [-18,-3], "left_hip": [18,3], "right_foot": [-19,-3], "left_foot": [19,3],
		"right_bend": 1.0, "left_bend": 1.0,
		"right_arm_depth": -6, "left_arm_depth": 3, "right_hand_depth": -5, "left_hand_depth": 8,
		"right_leg_depth": -5, "left_leg_depth": -3, "bag": [-54,12], "bag_depth": -4, "neck": [0,-54]
	},
	"west": {
		"right_shoulder": [11,-57], "left_shoulder": [15,-51],
		"right_hip": [4,-4], "left_hip": [-4,4], "right_foot": [8,-4], "left_foot": [-6,2],
		"right_bend": 1.0, "left_bend": 1.0,
		"right_arm_depth": -6, "left_arm_depth": 3, "right_hand_depth": -5, "left_hand_depth": 8,
		"right_leg_depth": -5, "left_leg_depth": -3, "bag": [0,12], "bag_depth": -4, "neck": [0,-54]
	},
	"north_west": {
		"right_shoulder": [42,-55], "left_shoulder": [-29,-51],
		"right_hip": [18,-3], "left_hip": [-18,3], "right_foot": [19,-3], "left_foot": [-19,3],
		"right_bend": 1.0, "left_bend": 1.0,
		"right_arm_depth": -6, "left_arm_depth": 3, "right_hand_depth": -5, "left_hand_depth": 8,
		"right_leg_depth": -5, "left_leg_depth": -3, "bag": [54,12], "bag_depth": -4, "neck": [0,-54]
	},
	"north": {
		"right_shoulder": [54,-52], "left_shoulder": [-54,-52],
		"right_hip": [25,0], "left_hip": [-25,0], "right_foot": [25,0], "left_foot": [-25,0],
		"right_bend": -1.0, "left_bend": 1.0,
		"right_arm_depth": -1, "left_arm_depth": -1, "right_hand_depth": 8, "left_hand_depth": 8,
		"right_leg_depth": -4, "left_leg_depth": -3, "bag": [77,12], "bag_depth": -4, "neck": [0,-54]
	},
	"north_east": {
		"right_shoulder": [29,-51], "left_shoulder": [-42,-55],
		"right_hip": [18,3], "left_hip": [-18,-3], "right_foot": [19,3], "left_foot": [-19,-3],
		"right_bend": -1.0, "left_bend": -1.0,
		"right_arm_depth": 3, "left_arm_depth": -6, "right_hand_depth": 8, "left_hand_depth": -5,
		"right_leg_depth": -3, "left_leg_depth": -5, "bag": [54,12], "bag_depth": 1, "neck": [0,-54]
	},
	"east": {
		"right_shoulder": [-15,-51], "left_shoulder": [-11,-57],
		"right_hip": [-4,4], "left_hip": [4,-4], "right_foot": [-6,2], "left_foot": [8,-4],
		"right_bend": -1.0, "left_bend": -1.0,
		"right_arm_depth": 3, "left_arm_depth": -6, "right_hand_depth": 8, "left_hand_depth": -5,
		"right_leg_depth": -3, "left_leg_depth": -5, "bag": [0,12], "bag_depth": 1, "neck": [0,-54]
	},
	"south_east": {
		"right_shoulder": [-42,-51], "left_shoulder": [29,-55],
		"right_hip": [-18,3], "left_hip": [18,-3], "right_foot": [-19,3], "left_foot": [19,-3],
		"right_bend": -1.0, "left_bend": -1.0,
		"right_arm_depth": 3, "left_arm_depth": -6, "right_hand_depth": 8, "left_hand_depth": -5,
		"right_leg_depth": -3, "left_leg_depth": -5, "bag": [-54,12], "bag_depth": 1, "neck": [0,-54]
	}
}
