class_name ReactorMusicProfile
extends RefCounted
## Pure rules for the 150-second reactor score. Everything is a function of the
## authoritative remaining time, so retries, late joins and snapshots cannot desync it.

const TOTAL_SECONDS := 150.0
const BPM := 135.0
const BEAT := 60.0 / BPM
const STEP := BEAT / 4.0
const BAR := BEAT * 4.0
const LOOP_BARS := 16
const LOOP_SECONDS := BAR * LOOP_BARS

const STEMS: Array[StringName] = [&"bed", &"pad", &"drive", &"lead", &"climax"]
const OFF_DB := -80.0

## Stem gain (dB) per tier. Tier 1 = 150-111 s ... tier 6 = 10-0 s.
const STEM_DB := {
	1: {&"bed": -4.0, &"pad": OFF_DB, &"drive": OFF_DB, &"lead": OFF_DB, &"climax": OFF_DB},
	2: {&"bed": -3.0, &"pad": -9.0, &"drive": OFF_DB, &"lead": OFF_DB, &"climax": OFF_DB},
	3: {&"bed": -4.0, &"pad": -10.0, &"drive": -5.0, &"lead": OFF_DB, &"climax": OFF_DB},
	4: {&"bed": -6.0, &"pad": -12.0, &"drive": -3.0, &"lead": -7.0, &"climax": OFF_DB},
	5: {&"bed": -8.0, &"pad": -14.0, &"drive": OFF_DB, &"lead": -6.0, &"climax": -2.0},
	6: {&"bed": -12.0, &"pad": OFF_DB, &"drive": -4.0, &"lead": -5.0, &"climax": -1.0},
}

## Seconds remaining at which each tier begins, as shown on the countdown (ceil).
const TIER_FLOORS := {1: 111, 2: 76, 3: 41, 4: 21, 5: 11, 6: 0}


## 0 = silent (not running / expired). Otherwise 1..6, using the ceiling of the remaining time so
## the music follows the number the player reads on the countdown.
static func tier(remaining: float) -> int:
	if remaining <= 0.0:
		return 0
	var seconds := ceili(remaining)
	if seconds >= 111: return 1
	if seconds >= 76: return 2
	if seconds >= 41: return 3
	if seconds >= 21: return 4
	if seconds >= 11: return 5
	return 6


static func stem_db(tier_index: int, stem: StringName) -> float:
	if not STEM_DB.has(tier_index):
		return OFF_DB
	return float(STEM_DB[tier_index].get(stem, OFF_DB))


## Pulse spacing in seconds of elapsed time; 0 = none. Tiers 2-5 sit on nested grid subdivisions
## (quarter, eighth, sixteenth, sixteenth) of the 135 BPM score. The final ten seconds accelerate
## continuously from a sixteenth note toward a near-continuous warning flutter.
static func pulse_interval(remaining: float) -> float:
	match tier(remaining):
		2: return BEAT
		3: return STEP * 2.0
		4, 5: return STEP
		6:
			var urgency := clampf(1.0 - remaining / 10.0, 0.0, 1.0)
			return lerpf(STEP, 0.06, urgency)
	return 0.0


## Percussion for a grid step (16th-note index since arming) as [[event_id, extra_db]].
static func pattern(tier_index: int, step: int) -> Array:
	var s := posmod(step, 16)
	match tier_index:
		2:
			return [[&"core_perc_kick", 0.0]] if s % 4 == 0 else []
		3:
			if s % 8 == 0: return [[&"core_perc_kick", 0.0]]
			if s % 4 == 0: return [[&"core_perc_hit", -4.0]]
			return [[&"core_perc_tick", -4.0]]
		4:
			var hits: Array = []
			if s % 4 == 0: hits.append([&"core_perc_kick", 0.0])
			if s == 4 or s == 12: hits.append([&"core_perc_hit", -2.0])
			if s == 0 or s == 10: hits.append([&"core_warn_beep", -6.0])
			if s % 2 == 0 and hits.is_empty(): hits.append([&"core_perc_tick", -5.0])
			elif s % 4 == 3: hits.append([&"core_perc_tick", -10.0])
			return hits
		5:
			var hits: Array = []
			if s % 4 == 0: hits.append([&"core_perc_kick", 1.0])
			if s == 4 or s == 12: hits.append([&"core_perc_hit", 0.0])
			if s % 2 == 1: hits.append([&"core_perc_tick", -3.0])
			if s % 4 == 2: hits.append([&"core_warn_beep", -5.0])
			return hits
	return []


## Warning-blip pitch for the final ten seconds (1.0 -> 1.6).
static func final_pitch(remaining: float) -> float:
	return lerpf(1.0, 1.6, clampf(1.0 - remaining / 10.0, 0.0, 1.0))


## Spacing of the reactor alarm (0 = silent): sparse from 20 s, constant in the last ten.
static func alarm_interval(remaining: float) -> float:
	match tier(remaining):
		5: return 2.4
		6: return 1.3
	return 0.0


static func elapsed_for(remaining: float, total: float = TOTAL_SECONDS) -> float:
	return clampf(total - remaining, 0.0, total)


static func loop_position(elapsed: float) -> float:
	return fposmod(elapsed, LOOP_SECONDS)


## Reactor instability 0..1 for hum, arcs and flicker, rising through the countdown.
static func instability(remaining: float, total: float = TOTAL_SECONDS) -> float:
	var progress := clampf(1.0 - remaining / maxf(total, 0.001), 0.0, 1.0)
	return progress * progress * (3.0 - 2.0 * progress) * 0.6 + progress * 0.4
