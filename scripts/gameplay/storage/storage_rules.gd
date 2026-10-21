extends "res://scripts/puzzles/puzzle_base.gd"
## Generic preservation bays: weight and contents never determine whether a seal is accepted.
const ITEMS := {
	"r17": {"label": "R-17 / ochre case", "kg": 4.8, "part": "reader", "contents": "Optical archive reader", "color": "c89b4c", "home": Vector3(3.9, 0, -4.8)},
	"k04": {"label": "K-04 / blue case", "kg": 2.6, "part": "regulator", "contents": "Voltage regulator", "color": "57859f", "home": Vector3(6.1, 0, -7.6)},
	"m22": {"label": "M-22 / red case", "kg": 7.2, "part": "memory", "contents": "Shielded memory module", "color": "ae6158", "home": Vector3(3.8, 0, -7.3)},
	"v09": {"label": "V-09 / green case", "kg": 3.4, "part": "", "contents": "Ventilation motor", "color": "6c8c68", "home": Vector3(6.0, 0, -4.9)},
	"t31": {"label": "T-31 / cream case", "kg": 5.9, "part": "", "contents": "Survey instrument", "color": "c7bca0", "home": Vector3(4.2, 0, -8.1)},
	"h08": {"label": "H-08 / violet case", "kg": 1.8, "part": "", "contents": "Hydraulic gauge", "color": "887494", "home": Vector3(6.3, 0, -3.5)},
	"spool": {"label": "Loose cable spool", "kg": 6.3, "part": "", "contents": "Cable spool — no archive component", "color": "815d43", "home": Vector3(3.0, 0, -5.9)}}
const PARTS := {"reader": "Optical archive reader", "regulator": "Voltage regulator", "memory": "Shielded memory module"}

static func initial() -> Dictionary:
	var locations := {}
	for id in ITEMS: locations[id] = ITEMS[id].home
	return {"manifest_read": false, "past_hand": "", "future_hand": "", "floor_items": locations,
		"bays": [{"item": "", "sealed": false, "retrieved": false, "raised": false}, {"item": "", "sealed": false, "retrieved": false, "raised": false}, {"item": "", "sealed": false, "retrieved": false, "raised": false}],
		"installed": {"reader": "", "regulator": "", "memory": ""}}

static func actions() -> Dictionary:
	return {"read_manifest": [FUTURE], "pickup_storage_item": [PAST], "drop_storage_item": [PAST],
		"place_storage_item": [PAST], "remove_storage_item": [PAST], "seal_bay": [PAST], "unseal_bay": [PAST],
		"raise_storage_tray": [FUTURE], "lower_storage_tray": [FUTURE], "retrieve_storage_item": [FUTURE], "return_storage_item": [FUTURE], "install_component": [FUTURE]}

static func repaired(state: Dictionary) -> bool:
	var installed: Dictionary = state.get("storage", {}).get("installed", {})
	for part in PARTS:
		if installed.get(part, "").is_empty(): return false
	return true

static func validate(action: String, payload: Dictionary, state: Dictionary) -> String:
	var s: Dictionary = state.storage
	if not state.battery_ready: return "restore_power_first"
	if action == "pickup_storage_item":
		if payload.size() != 1 or not payload.get("item") is String or not ITEMS.has(payload.item): return "invalid_item"
		if not s.past_hand.is_empty(): return "hands_full"
		return "" if s.floor_items.has(payload.item) else "item_unavailable"
	if action == "drop_storage_item":
		if payload.size() != 1 or not payload.get("position") is Vector3: return "invalid_position"
		var p: Vector3 = payload.position
		# Vector3 coordinates use float32; allow rounding at the storage-room boundary.
		if not p.is_finite() or absf(p.x) > 6.601 or p.z < -8.501 or p.z > -3.299 or p.y != 0: return "invalid_position"
		return "" if not s.past_hand.is_empty() else "hands_empty"
	if action == "install_component":
		if payload.size() != 1 or not payload.get("part") is String or not PARTS.has(payload.part): return "invalid_part"
		if not s.manifest_read: return "inspect_damage_first"
		if s.future_hand.is_empty(): return "hands_empty"
		return "" if s.installed[payload.part].is_empty() else "component_already_installed"
	if action == "read_manifest": return "" if payload.is_empty() else "invalid_payload"
	if payload.size() != 1 or typeof(payload.get("bay")) != TYPE_INT or payload.bay < 0 or payload.bay >= 3: return "invalid_bay"
	var bay: Dictionary = s.bays[payload.bay]
	match action:
		"place_storage_item":
			if s.past_hand.is_empty(): return "hands_empty"
			if bay.sealed: return "bay_sealed"
			if not bay.item.is_empty(): return "bay_occupied"
		"remove_storage_item":
			if not s.past_hand.is_empty(): return "hands_full"
			if bay.sealed: return "bay_sealed"
			if bay.item.is_empty(): return "bay_empty"
		"seal_bay":
			if bay.sealed: return "bay_sealed"
		"unseal_bay":
			if not bay.sealed: return "bay_open"
			if bay.retrieved or bay.raised: return "return_future_item_first"
		"raise_storage_tray":
			if not bay.sealed or bay.item.is_empty() or bay.retrieved: return "future_bay_empty"
			if bay.raised: return "tray_already_raised"
		"lower_storage_tray":
			if not bay.raised: return "tray_already_lowered"
			if bay.retrieved: return "return_future_item_first"
		"retrieve_storage_item":
			if not bay.raised: return "raise_tray_first"
			if not s.future_hand.is_empty(): return "hands_full"
			if not bay.sealed or bay.item.is_empty() or bay.retrieved: return "future_bay_empty"
		"return_storage_item":
			if s.future_hand.is_empty() or s.future_hand != bay.item or not bay.retrieved: return "return_to_source_bay"
	return ""

static func apply(action: String, payload: Dictionary, state: Dictionary) -> Dictionary:
	var s: Dictionary = state.storage
	match action:
		"read_manifest":
			if s.manifest_read: return no_change()
			s.manifest_read = true
		"pickup_storage_item":
			s.past_hand = payload.item
			s.floor_items.erase(payload.item)
		"drop_storage_item":
			s.floor_items[s.past_hand] = payload.position
			s.past_hand = ""
		"install_component":
			if ITEMS[s.future_hand].part != payload.part:
				return no_change("Professor: This is %s. It doesn't fit the %s socket. I'll return it to its bay." % [ITEMS[s.future_hand].contents, PARTS[payload.part]])
			for bay in s.bays:
				if bay.item == s.future_hand: bay.raised = false
			s.installed[payload.part] = s.future_hand
			s.future_hand = ""
		_:
			var bay: Dictionary = s.bays[payload.bay]
			match action:
				"place_storage_item":
					bay.item = s.past_hand
					s.past_hand = ""
				"remove_storage_item":
					s.past_hand = bay.item
					bay.item = ""
				"seal_bay": bay.sealed = true
				"unseal_bay": bay.sealed = false
				"raise_storage_tray": bay.raised = true
				"lower_storage_tray": bay.raised = false
				"retrieve_storage_item":
					s.future_hand = bay.item
					bay.retrieved = true
				"return_storage_item":
					s.future_hand = ""
					bay.retrieved = false
					bay.raised = false
	return change(state)
