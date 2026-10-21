"""Regenerate resources/audio/level_sound_events.tres (Level 2 / Level 3 sound events).

The .tres is the editable source of truth once generated; this script documents the
mixing decisions (volume_db, spatial intent, cooldown, priority) and keeps the export
dependency list in step with the files under assets/audio/level2 and level3.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
A = "res://assets/audio/"


def ev(files, bus="SFX", vol=-10.0, spatial=False, cd=0.1, conc=2, prio=60, loop=False, pv=0.0, unit=None, dist=None, **extra):
    if isinstance(files, str):
        files = [files]
    entry = {"files": [A + f for f in files], "bus": bus, "volume_db": vol, "pitch_variance": pv, "volume_variance_db": 0.0,
             "spatial": spatial, "cooldown": cd, "concurrency": conc, "priority": prio, "loop": loop}
    if spatial:
        entry["unit_size"] = unit or 7.0
        entry["max_distance"] = dist or 26.0
    entry.update(extra)
    return entry


S3 = "level3/sfx/"
E = {
    # --- Level 3 devices (spatial = heard at the machine; 2D = whole-room events)
    "core_relay_clunk": ev([S3 + f"relay_clunk_{i}.wav" for i in (1, 2, 3)], vol=-8, spatial=True, pv=0.04, cd=0.08, prio=80),
    "core_battery_latch": ev(S3 + "battery_latch.wav", vol=-8, spatial=True, prio=80),
    "core_switch_heavy": ev(S3 + "switch_heavy.wav", vol=-7, spatial=True, prio=80),
    "core_coil_surge": ev(S3 + "coil_surge.wav", vol=-9, spatial=True, cd=0.1, prio=85),
    "core_coil_align": ev(S3 + "coil_align.wav", vol=-10, spatial=True, cd=0.2, prio=85),
    "core_battery_connect": ev(S3 + "battery_connect.wav", vol=-7, spatial=True, prio=90),
    "core_anchor_calibrate": ev(S3 + "anchor_calibrate.wav", vol=-8, spatial=True, prio=85),
    "core_anchor_lock": ev(S3 + "anchor_lock.wav", vol=-8, spatial=True, prio=90),
    "core_origin_stabilize": ev(S3 + "origin_stabilize.wav", vol=-5, spatial=True, prio=92, unit=10.0, dist=30.0),
    "core_power_restore": ev(S3 + "power_restore.wav", vol=-4, conc=1, prio=95),
    "core_arm_confirm": ev(S3 + "arm_confirm.wav", vol=-3, conc=1, prio=100),
    "core_sync_engage": ev(S3 + "sync_engage.wav", vol=-7, spatial=True, prio=90),
    "core_sync_engage_remote": ev(S3 + "sync_engage.wav", vol=-12, prio=85),
    "core_sync_tick": ev(S3 + "sync_tick.wav", vol=-13, cd=0.0, conc=3, prio=95),
    "core_sync_success": ev(S3 + "sync_success.wav", vol=-4, prio=98),
    "core_sync_fail": ev(S3 + "sync_fail.wav", vol=-5, prio=98),
    "core_command_lock": ev(S3 + "command_lock.wav", vol=-7, spatial=True, prio=90),
    "core_command_lock_remote": ev(S3 + "command_lock.wav", vol=-14, prio=85),
    "core_reject": ev(S3 + "reject.wav", vol=-9, cd=0.15, prio=90),
    "core_console_open": ev(S3 + "console_open.wav", bus="UI", vol=-16, prio=60),
    "core_console_close": ev(S3 + "console_close.wav", bus="UI", vol=-16, prio=60),
    "core_alarm": ev(S3 + "alarm_siren.wav", vol=-16, cd=0.5, conc=1, prio=70),
    # --- room machinery details
    "core_arc": ev([S3 + f"arc_{i}.wav" for i in (1, 2, 3)], vol=-14, spatial=True, pv=0.08, cd=0.5, conc=1, prio=25, unit=8.0, dist=30.0),
    "core_clank": ev([S3 + f"clank_{i}.wav" for i in (1, 2, 3)], vol=-15, spatial=True, pv=0.05, cd=1.0, conc=1, prio=20, unit=8.0, dist=30.0),
    "core_temporal_pulse": ev(S3 + "temporal_pulse.wav", vol=-13, spatial=True, pv=0.1, cd=3.0, conc=1, prio=30, unit=12.0, dist=40.0),
    "core_reset_return": ev(S3 + "reset_return.wav", vol=-10, conc=1, prio=95),
    # --- positional loops, driven by CoreSound
    "core_reactor_loop": ev("level3/sfx/reactor_core_loop.ogg", vol=-20, spatial=True, loop=True, conc=1, unit=9.0, dist=34.0),
    "core_coil_hum_loop": ev("level3/sfx/coil_hum_loop.ogg", vol=-24, spatial=True, loop=True, conc=1, unit=4.0, dist=14.0),
    # --- room beds (AmbientAudioController)
    "core_ambience_past": ev("level3/ambience/core_ambience_past.ogg", bus="Ambience", vol=-8, loop=True),
    "core_ambience_future": ev("level3/ambience/core_ambience_future.ogg", bus="Ambience", vol=-8, loop=True),
    # --- countdown score: stems share one 135 BPM / 16-bar grid (ReactorMusic plays them in sync)
    **{f"core_music_{n}": ev(f"level3/music/core_music_{n}.ogg", bus="Music", vol=0, conc=1, prio=100, music_stem=True)
       for n in ("bed", "pad", "drive", "lead", "climax")},
    "core_riser_final": ev("level3/music/core_riser_final.ogg", bus="Music", vol=-3, conc=1, prio=100),
    "core_tier_hit": ev(S3 + "tier_hit.wav", bus="Music", vol=-9, cd=0.5, conc=1, prio=95),
    "core_perc_kick": ev(S3 + "perc_kick.wav", bus="Music", vol=-8, cd=0.0, conc=4, prio=90),
    "core_perc_tick": ev(S3 + "perc_tick.wav", bus="Music", vol=-10, cd=0.0, conc=4, prio=90),
    "core_perc_hit": ev(S3 + "perc_hit.wav", bus="Music", vol=-12, cd=0.0, conc=3, prio=90),
    "core_warn_beep": ev(S3 + "warn_beep.wav", bus="Music", vol=-9, cd=0.0, conc=4, prio=95),
    "core_countdown_second": ev(S3 + "countdown_second.wav", bus="Music", vol=-3, cd=0.4, conc=2, prio=95),
    # --- meltdown cues and endings
    "core_overload_impact": ev(S3 + "overload_impact.wav", vol=-2, conc=1, prio=100),
    "core_overload_rupture": ev(S3 + "overload_rupture.wav", vol=-6, conc=1, prio=100),
    "core_overload_shockwave": ev(S3 + "overload_shockwave.wav", vol=-4, conc=1, prio=100),
    **{f"core_ending_{n}": ev(f"level3/endings/ending_{n}.ogg", bus="Music", vol=-4, conc=1, prio=100)
       for n in ("trust", "student_override", "professor_override", "paradox")},
}

S2 = "level2/sfx/"
E.update({
    "maint_bed_past": ev("level2/ambience/maint_bed_past.ogg", bus="Ambience", vol=-10, loop=True),
    "maint_bed_future": ev("level2/ambience/maint_bed_future.ogg", bus="Ambience", vol=-10, loop=True),
    "maint_machine_loop": ev(S2 + "machine_loop.ogg", vol=-24, spatial=True, loop=True, conc=1, unit=6.0, dist=22.0),
    "maint_buzz_loop": ev(S2 + "buzz_loop.ogg", vol=-26, spatial=True, loop=True, conc=1, unit=3.0, dist=12.0),
    "maint_lever_clunk": ev(S2 + "lever_clunk.wav", vol=-8, spatial=True, prio=80),
    "maint_crank": ev(S2 + "crank_ratchet.wav", vol=-10, spatial=True, prio=80),
    "maint_charge_latch": ev(S2 + "charge_latch.wav", vol=-8, spatial=True, prio=85),
    "maint_power_surge": ev(S2 + "power_surge.wav", vol=-5, conc=1, prio=95),
    "maint_power_down": ev(S2 + "power_down.wav", vol=-8, conc=1, prio=90),
    "maint_reserve_lever": ev(S2 + "reserve_lever.wav", vol=-8, spatial=True, prio=80),
    "maint_fuse_seat": ev(S2 + "fuse_seat.wav", vol=-9, spatial=True, prio=80),
    "maint_archive": ev(S2 + "archive_access.wav", vol=-12, spatial=True, prio=70),
    "maint_recorder_export": ev(S2 + "recorder_export.wav", vol=-9, spatial=True, prio=85),
    "maint_cell_pull": ev(S2 + "cell_pull.wav", vol=-8, spatial=True, prio=85),
    "maint_keypad_authorize": ev(S2 + "keypad_authorize.wav", vol=-8, spatial=True, prio=85),
    "maint_release_wheel": ev(S2 + "release_wheel.wav", vol=-7, spatial=True, prio=85),
    "maint_gate_open": ev(S2 + "gate_open.wav", vol=-5, spatial=True, prio=90, unit=10.0, dist=34.0),
    "maint_anchor_latch": ev(S2 + "anchor_latch.wav", vol=-8, spatial=True, prio=85),
    "maint_anchor_complete": ev(S2 + "anchor_complete.wav", vol=-4, conc=1, prio=98),
    "maint_hatch_open": ev(S2 + "hatch_open.wav", vol=-9, spatial=True, prio=75),
    "maint_hatch_close": ev(S2 + "hatch_close.wav", vol=-9, spatial=True, prio=75),
    "maint_lift_move": ev(S2 + "lift_move.wav", vol=-11, spatial=True, prio=70),
    "maint_lift_stop": ev(S2 + "lift_stop.wav", vol=-9, spatial=True, prio=70),
    "maint_detail": ev([S2 + f"clank_{i}.wav" for i in (1, 2, 3)], vol=-17, spatial=True, pv=0.05, cd=1.0, conc=1, prio=15, unit=8.0, dist=30.0),
    "maint_steam_hiss": ev(S2 + "steam_hiss.wav", vol=-20, spatial=True, cd=2.0, conc=1, prio=15, unit=6.0, dist=22.0),
})


def godot(value, indent=1):
    pad = "  " * indent
    if isinstance(value, dict):
        rows = [f'{pad}"{k}": {godot(v, indent + 1)}' for k, v in value.items()]
        return "{\n" + ",\n".join(rows) + "\n" + "  " * (indent - 1) + "}"
    if isinstance(value, list):
        rows = [pad + json.dumps(v) for v in value]
        return "[\n" + ",\n".join(rows) + "\n" + "  " * (indent - 1) + "]"
    return json.dumps(value)


def main():
    files = sorted({f for entry in E.values() for f in entry["files"]})
    for f in files:
        if not (ROOT / f.replace("res://", "")).exists():
            raise SystemExit("Missing audio file: " + f)
    lines = ["[gd_resource type=\"Resource\" load_steps=%d format=3]" % (len(files) + 2), "",
             '[ext_resource type="Script" path="res://scripts/audio/sound_event_library.gd" id="1_library"]']
    for i, f in enumerate(files):
        lines.append(f'[ext_resource type="AudioStream" path="{f}" id="{i + 2}"]')
    refs = ", ".join(f'ExtResource("{i + 2}")' for i in range(len(files)))
    lines += ["", "[resource]", 'script = ExtResource("1_library")', "events = " + godot(E), f"assets = Array[AudioStream]([{refs}])", ""]
    (ROOT / "resources/audio/level_sound_events.tres").write_text("\n".join(lines), encoding="utf8", newline="\n")
    print(len(E), "events,", len(files), "files")


if __name__ == "__main__":
    main()
