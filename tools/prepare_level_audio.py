"""Prepare the Level 2 / Level 3 audio overhaul from acquired CC0 recordings.

Every output is built only from downloaded CC0 material (layering, filtering,
reversing, variable-rate playback, bar-aligned slicing). Nothing is synthesized.
Sources live in the ignored .godot/audio_sources cache:

  * Kenney Sci-fi Sounds / Impact Sounds / Interface Sounds  -> tools/acquire_audio_sources.py
  * SRG774 "Dark Sci-Fi Audio Pack" and bart "Steam boiler sound loop" -> --fetch

Usage:  python tools/prepare_level_audio.py [--fetch]
Requires ffmpeg, numpy and scipy. Merges its records into assets/audio/asset_provenance.json
(records carrying a "sources" list), leaving the earlier laboratory records untouched.
"""
from pathlib import Path
import hashlib
import io
import json
import subprocess
import sys
import urllib.request
import zipfile

import numpy as np
from scipy import signal

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / ".godot/audio_sources"
OUT = ROOT / "assets/audio"
SR = 48000
DATE = "2026-10-21"
BPM = 135.0
BAR = 4 * 60.0 / BPM
LOOP_BARS = 16
LOOP_SAMPLES = round(LOOP_BARS * BAR * SR)

CC0 = "https://creativecommons.org/publicdomain/zero/1.0/"
PACKS = {
    "sf": {"dir": "sci-fi-sounds/Audio", "ext": ".ogg", "creator": "Kenney", "title": "Sci-fi Sounds",
           "page": "https://kenney.nl/assets/sci-fi-sounds", "zip": "kenney_sci-fi-sounds.zip"},
    "im": {"dir": "impact-sounds/Audio", "ext": ".ogg", "creator": "Kenney", "title": "Impact Sounds",
           "page": "https://kenney.nl/assets/impact-sounds", "zip": "kenney_impact-sounds.zip"},
    "ui": {"dir": "interface-sounds/Audio", "ext": ".ogg", "creator": "Kenney", "title": "Interface Sounds",
           "page": "https://kenney.nl/assets/interface-sounds", "zip": "kenney_interface-sounds.zip"},
    "dsf": {"dir": "dark-sci-fi-audio-pack/ogg", "ext": ".ogg", "creator": "SRG774", "title": "Dark Sci-Fi Audio Pack",
            "page": "https://opengameart.org/content/dark-sci-fi-audio-pack",
            "download": "https://opengameart.org/sites/default/files/ogg.zip",
            "sha256": "c17c40f2b5ff32a51016d121a017cf1a307e0065c7acfcc30c66f05f1d047ce1",
            "zip": "dark-sci-fi-audio-pack/ogg.zip"},
    "boiler": {"dir": "steam-boiler-sound-loop", "ext": ".wav", "creator": "bart", "title": "Steam boiler sound loop (generator_loop.wav)",
               "page": "https://opengameart.org/content/steam-boiler-sound-loop",
               "download": "https://opengameart.org/sites/default/files/generator_loop.wav",
               "sha256": "64b174cf8ef71e7f71aa03cf29864ab489f7be1f624456cab916043da38911bd",
               "file": "steam-boiler-sound-loop/generator_loop.wav"},
    "vent": {"file": "ventilation.mp3", "creator": "Kinoton", "title": "Room Tone, Deep Ventilation",
             "page": "https://freesound.org/people/Kinoton/sounds/503255/", "ext": ""},
    "wind": {"file": "wind.ogg", "creator": "SketchMan3", "title": "wind whoosh loop",
             "page": "https://opengameart.org/content/wind-whoosh-loop", "ext": ""},
}

used: dict = {}
records: list = []


# ---------------------------------------------------------------- acquisition
def fetch():
    for key in ("dsf", "boiler"):
        pack = PACKS[key]
        target = CACHE / pack.get("zip", pack.get("file"))
        if not target.exists():
            print("Downloading", pack["download"], flush=True)
            request = urllib.request.Request(pack["download"], headers={"User-Agent": "PastFuture-AudioResearch/1.0"})
            data = urllib.request.urlopen(request, timeout=90).read()
            if hashlib.sha256(data).hexdigest() != pack["sha256"]:
                raise RuntimeError("Published source changed; review its license before replacing " + pack["title"])
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        if key == "dsf" and not (CACHE / pack["dir"]).exists():
            with zipfile.ZipFile(target) as archive:
                archive.extractall(target.parent)
        if hashlib.sha256(target.read_bytes()).hexdigest() != pack["sha256"]:
            raise RuntimeError("Cached source hash mismatch: " + str(target))
    print("OpenGameArt sources verified.")


# ---------------------------------------------------------------- DSP helpers
def source_path(ref):
    key, _, name = ref.partition(":")
    pack = PACKS[key]
    if "dir" in pack and key != "boiler":
        return CACHE / pack["dir"] / (name + pack["ext"])
    if key == "boiler":
        return CACHE / pack["file"]
    return CACHE / pack["file"]


def _ffmpeg_decode(path, channels, filters=""):
    command = ["ffmpeg", "-v", "error", "-i", str(path)]
    if filters:
        command += ["-af", filters]
    data = subprocess.check_output(command + ["-f", "f32le", "-ac", str(channels), "-ar", str(SR), "-"])
    return np.frombuffer(data, np.float32).copy().reshape(-1, channels)


def load(ref, t0=0.0, dur=None, ch=1):
    used[ref.partition(":")[0]] = used.get(ref.partition(":")[0], set()) | {source_path(ref).name}
    x = _ffmpeg_decode(source_path(ref), ch)
    x = x[round(t0 * SR):]
    if dur is not None:
        x = x[:round(dur * SR)]
    return x - x.mean(axis=0)


def _sos(kind, freq, order):
    return signal.butter(order, freq, kind, fs=SR, output="sos")


def lp(x, f, order=2):
    return signal.sosfilt(_sos("low", f, order), x, axis=0).astype(np.float32)


def hp(x, f, order=2):
    return signal.sosfilt(_sos("high", f, order), x, axis=0).astype(np.float32)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(_sos("band", [lo, hi], order), x, axis=0).astype(np.float32)


def db(x, gain_db):
    return (x * (10 ** (gain_db / 20))).astype(np.float32)


def fade(x, fin=0.004, fout=0.03):
    x = x.copy()
    n = min(round(fin * SR), len(x) // 2)
    if n > 0:
        x[:n] *= np.linspace(0, 1, n, dtype=np.float32)[:, None]
    n = min(round(fout * SR), len(x) // 2)
    if n > 0:
        x[-n:] *= np.linspace(1, 0, n, dtype=np.float32)[:, None]
    return x


def envelope(x, points):
    t = np.arange(len(x)) / SR
    g = np.interp(t, [p[0] for p in points], [p[1] for p in points])
    return (x * g[:, None]).astype(np.float32)


def rev(x):
    return x[::-1].copy()


def ramp_resample(x, r0, r1, dur, loop=True):
    """Variable-speed playback of x (loops): pitch and speed glide from r0 to r1."""
    n = round(dur * SR)
    rate = np.linspace(r0, r1, n)
    phase = np.cumsum(rate)
    if not loop:
        phase = np.minimum(phase, len(x) - 1)
    idx = phase % len(x)
    grid = np.arange(len(x))
    out = np.stack([np.interp(idx, grid, x[:, c], period=len(x)) for c in range(x.shape[1])], axis=1)
    return out.astype(np.float32)


def pitch(x, ratio):
    return ramp_resample(x, ratio, ratio, len(x) / SR / ratio, loop=False)


def drive(x, amount):
    return (np.tanh(x * amount) / np.tanh(amount)).astype(np.float32)


def tv_lowpass(x, start_hz, end_hz, steps=7):
    """Time-varying lowpass by crossfading statically filtered copies (log-spaced cutoffs)."""
    cutoffs = np.geomspace(start_hz, end_hz, steps)
    copies = [lp(x, float(f)) for f in cutoffs]
    pos = np.linspace(0, steps - 1, len(x))
    out = np.zeros_like(x)
    for k, copy in enumerate(copies):
        out += copy * np.clip(1 - np.abs(pos - k), 0, 1)[:, None]
    return out.astype(np.float32)


def ff(x, filters):
    """Pass an array through an ffmpeg audio filter chain."""
    ch = x.shape[1]
    out = subprocess.run(["ffmpeg", "-v", "error", "-f", "f32le", "-ar", str(SR), "-ac", str(ch), "-i", "-",
                          "-af", filters, "-f", "f32le", "-ac", str(ch), "-ar", str(SR), "-"],
                         input=x.astype(np.float32).tobytes(), capture_output=True, check=True).stdout
    return np.frombuffer(out, np.float32).copy().reshape(-1, ch)


def stereo(x):
    return np.repeat(x, 2, axis=1) if x.shape[1] == 1 else x


def mono(x):
    return x.mean(axis=1, keepdims=True).astype(np.float32)


def widen(x, delay_ms=11.0):
    """Mono source -> stereo with a short Haas offset (keeps mono compatibility)."""
    d = round(delay_ms / 1000 * SR)
    right = np.concatenate((np.zeros((d, 1), np.float32), x))[:len(x)]
    return np.concatenate((x, right), axis=1)


def mix(parts, ch=1, tail=0.0, length=None):
    end = max(round(at * SR) + len(x) for x, at, _ in parts)
    n = length if length is not None else end + round(tail * SR)
    out = np.zeros((n, ch), np.float32)
    for x, at, gain_db in parts:
        x = db(x if x.shape[1] == ch else (stereo(x) if ch == 2 else mono(x)), gain_db)
        start = round(at * SR)
        stop = min(n, start + len(x))
        if stop > start:
            out[start:stop] += x[:stop - start]
    return out


def loopify(x, overlap):
    """Equal-length loop whose wrap crossfades the tail into the head (non-musical beds)."""
    n = min(round(overlap * SR), len(x) // 3)
    ramp = np.linspace(0, 1, n, dtype=np.float32)[:, None]
    seam = x[-n:] * (1 - ramp) + x[:n] * ramp
    return np.concatenate((x[n:-n], seam))


def tile(x, seconds, overlap=0.5):
    """Repeat a seamless-wrapped bed until it fills `seconds`."""
    unit = loopify(x, overlap)
    reps = int(np.ceil(seconds * SR / len(unit)))
    return np.tile(unit, (reps, 1))[:round(seconds * SR)]


def peak_to(x, peak_db):
    peak = float(np.max(np.abs(x)))
    return x * ((10 ** (peak_db / 20)) / peak) if peak > 0 else x


def rms_to(x, rms_db, ceiling_db=-4.5):
    rms = float(np.sqrt(np.mean(x ** 2)))
    x = x * ((10 ** (rms_db / 20)) / rms)
    ceiling = 10 ** (ceiling_db / 20)
    peak = float(np.max(np.abs(x)))
    return x * (ceiling / peak) if peak > ceiling else x


# ---------------------------------------------------------------- output
def emit(target, x, usage, recipe, *, kind="sfx", peak_db=-6.0, rms_db=None, loop=False):
    global used
    channels = x.shape[1]
    x = fade(x, 0.003, 0.02) if not loop else x
    x = rms_to(x, rms_db) if rms_db is not None else peak_to(x, peak_db)
    dest = OUT / target
    dest.parent.mkdir(parents=True, exist_ok=True)
    codec = ["-c:a", "libvorbis", "-q:a", "5"] if dest.suffix == ".ogg" else ["-c:a", "pcm_s16le"]
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", str(channels), "-i", "-", *codec, str(dest)],
                   input=x.astype(np.float32).tobytes(), check=True)
    sources = []
    for key, names in used.items():
        pack = PACKS[key]
        source_file = pack.get("zip") or pack.get("file")
        digest = hashlib.sha256((CACHE / source_file).read_bytes()).hexdigest() if source_file else ""
        sources.append({"pack": pack["title"], "creator": pack["creator"], "page": pack["page"],
                        "license": "CC0-1.0", "license_url": CC0, "files_used": sorted(names), "pack_sha256": digest})
    first = sources[0]
    records.append({"collection": "level2_level3_audio", "original_asset_title": first["pack"], "creator": first["creator"],
                    "source_url": first["page"], "license": "CC0-1.0", "license_url": CC0,
                    "attribution_requirements": "None; voluntary credit retained.", "download_date": DATE,
                    "imported_filename": dest.relative_to(ROOT).as_posix(), "sha256": hashlib.sha256(dest.read_bytes()).hexdigest(),
                    "duration_seconds": round(len(x) / SR, 4), "channels": channels, "mix_rate": SR, "kind": kind,
                    "processing": recipe, "sources": sources, "intended_game_usage": usage})
    used = {}


# ---------------------------------------------------------------- music stems (shared 135 BPM grid)
def stem(ref, bar0, name, offset_db=0.0):
    overlap = round(BAR * SR)
    x = load(ref, t0=bar0 * BAR, dur=LOOP_BARS * BAR + BAR + 0.01, ch=2)
    head = x[:LOOP_SAMPLES].copy()
    tail = x[LOOP_SAMPLES:LOOP_SAMPLES + overlap]
    n = len(tail)
    ramp = np.linspace(0, 1, n, dtype=np.float32)[:, None]
    head[:n] = head[:n] * ramp + tail * (1 - ramp)
    assert len(head) == LOOP_SAMPLES, (ref, len(head))
    return head


def build_music():
    jobs = [
        ("bed", "dsf:pulse", 22, "slow heartbeat bed", dict(), -20.0),
        ("pad", "dsf:airy", 8, "temporal pad", dict(), -22.0),
        ("drive", "dsf:urgent", 1, "driving rhythm", dict(), -20.0),
        ("lead", "dsf:sector", 8, "tension lead", dict(), -22.0),
        ("climax", "dsf:urgent", 14, "climax rhythm", dict(), -19.0),
    ]
    for name, ref, bar0, label, _, rms in jobs:
        x = stem(ref, bar0, name)
        x = hp(x, 28)
        emit(f"level3/music/core_music_{name}.ogg", x, [f"core_music_{name}"],
             f"bars {bar0}-{bar0 + LOOP_BARS} of {ref.split(':')[1]} at {BPM:g} BPM; {LOOP_BARS}-bar loop, 1-bar tail-continuation crossfade at the wrap; RMS {rms} dBFS",
             kind="music", rms_db=rms, loop=True)


# ---------------------------------------------------------------- level 3 effects
def L(ref, t0=0.0, dur=None, lo=None, hi=None, gain=0.0, reverse=False, ratio=None):
    x = load(ref, t0, dur)
    if hi:
        x = hp(x, hi)
    if lo:
        x = lp(x, lo)
    if ratio:
        x = pitch(x, ratio)
    if reverse:
        x = rev(x)
    return db(x, gain)


def build_level3_sfx():
    S = "level3/sfx/"
    for i in range(3):
        emit(S + f"relay_clunk_{i + 1}.wav", mix([(L(f"im:impactMetal_heavy_00{i}", lo=6000, hi=60), 0, 0),
             (L("im:impactPlate_heavy_001", lo=1800), 0, -7), (L("im:impactSoft_heavy_000", lo=200), 0, -9)], tail=0.05),
             ["core_relay_clunk"], "heavy relay: impactMetal_heavy + impactPlate_heavy_001 + low impactSoft_heavy")
    emit(S + "battery_latch.wav", mix([(L("im:impactMetal_medium_000"), 0, -2), (L("im:impactMining_000", lo=2500), 0, -6),
         (L("im:impactMetal_light_001", hi=800), 0.16, -9)], tail=0.1), ["core_battery_latch"], "battery contact latch: metal medium + mining impact + light metal tail")
    emit(S + "switch_heavy.wav", mix([(L("im:impactPlate_heavy_000"), 0, 0), (L("im:impactSoft_heavy_001", lo=260), 0, -3),
         (L("im:impactMetal_light_002", hi=800), 0.05, -10)], tail=0.1), ["core_switch_heavy"], "heavy phase switch: plate impact + sub thud + light metal ring")
    emit(S + "coil_surge.wav", mix([(L("sf:forceField_000"), 0, 0), (L("sf:laserLarge_001", hi=800), 0.02, -9),
         (L("ui:glitch_002"), 0.05, -10)], tail=0.1), ["core_coil_surge"], "coil energy surge: forceField + laserLarge zap + glitch crackle")
    emit(S + "coil_align.wav", mix([(L("sf:laserRetro_001", lo=3000), 0, -8), (L("im:impactBell_heavy_001", lo=2500), 0.02, -3),
         (L("sf:forceField_002", hi=150), 0.05, -9)], tail=0.2), ["core_coil_align"], "coil aligned confirmation: retro zap + bell + force-field bloom")
    battery = L("sf:computerNoise_001", dur=1.4)
    emit(S + "battery_connect.wav", mix([(envelope(battery, [(0, 0.05), (0.9, 1), (1.4, 0)]), 0, -4), (L("im:impactMetal_medium_001"), 0, -4),
         (L("sf:laserSmall_004"), 0.5, -6), (L("sf:forceField_001"), 0.7, -8)], tail=0.2), ["core_battery_connect"], "receiver battery connected: rising computer hum + latch + zap + field")
    sweep = envelope(ramp_resample(load("sf:forceField_000"), 0.5, 2.2, 1.6), [(0, 0), (0.15, 1), (1.4, 1), (1.6, 0)])
    emit(S + "anchor_calibrate.wav", mix([(sweep, 0, -3), (L("sf:computerNoise_002", t0=0.3, dur=1.2), 0.3, -10)], tail=0.1),
         ["core_anchor_calibrate"], "Signal Anchor frequency sweep: forceField variable-rate glide + computerNoise bed")
    emit(S + "anchor_lock.wav", mix([(L("im:impactBell_heavy_000", lo=3000), 0, 0), (L("sf:laserSmall_003"), 0, -8),
         (L("sf:forceField_003"), 0.1, -10), (L("ui:confirmation_003", lo=3000), 0.05, -12)], tail=0.3), ["core_anchor_lock"], "anchor locked: bell + laser ping + force-field + confirmation")
    engine = L("sf:spaceEngineLow_001", dur=3.4, lo=400)
    emit(S + "origin_stabilize.wav", mix([(envelope(engine, [(0, 0), (0.5, 1), (2.0, 1), (3.4, 0)]), 0, -2), (L("sf:lowFrequency_explosion_001"), 0, -3),
         (L("sf:forceField_004", lo=900), 0.3, -8), (L("im:impactBell_heavy_002", lo=800), 0.4, -12)], tail=0.3), ["core_origin_stabilize"], "Origin Core stabilizer: low engine resonance + sub explosion + field + deep bell")
    surge = L("sf:spaceEngineLarge_002", dur=3.2, lo=3500)
    zaps = [(L(f"sf:laserLarge_00{n}", hi=600), at, -9) for n, at in ((0, 0.1), (2, 0.35), (3, 0.6), (4, 0.95))]
    emit(S + "power_restore.wav", mix([(L("sf:lowFrequency_explosion_000"), 0, 0), (envelope(surge, [(0, 0), (1.8, 1), (3.2, 0)]), 0, -6),
         (L("im:impactMetal_heavy_001"), 0, -8), *zaps], tail=0.3), ["core_power_restore"], "conduit power routing restored: sub boom + rising engine surge + zap train")
    emit(S + "sync_engage.wav", mix([(L("im:impactPlate_heavy_002"), 0, 0), (L("im:impactSoft_heavy_000", lo=250), 0, -3),
         (bp(envelope(ramp_resample(load("sf:engineCircular_002"), 0.7, 1.6, 1.2), [(0, 0), (1.0, 1), (1.2, 0)]), 300, 3000), 0.05, -10)], tail=0.1),
         ["core_sync_engage"], "phase switch engage: plate thunk + charging engine whine glide")
    emit(S + "sync_tick.wav", mix([(L("ui:bong_001", lo=1500), 0, 0), (L("ui:tick_004"), 0, -6)], tail=0.1), ["core_sync_tick"], "five-second window urgency pulse: low bong + tick")
    emit(S + "sync_success.wav", mix([(L("sf:lowFrequency_explosion_001"), 0, 0),
         (ramp_resample(load("sf:forceField_004"), 0.8, 1.8, 1.2), 0, -5), (L("im:impactBell_heavy_003"), 0.25, -6), (L("ui:confirmation_004"), 0.3, -10)], tail=0.5),
         ["core_sync_success"], "synchronization success: sub boom + rising field glide + bell + confirmation")
    emit(S + "sync_fail.wav", mix([(ramp_resample(load("sf:forceField_001"), 1.0, 0.35, 1.2), 0, -2), (L("ui:error_006"), 0, -4),
         (L("im:impactMetal_heavy_000"), 0.05, -5), (L("sf:laserRetro_003", lo=2000, reverse=True), 0, -10)], tail=0.2), ["core_sync_fail"], "missed phase window: descending field glide + error + relay drop")
    emit(S + "command_lock.wav", mix([(L("im:impactPlate_heavy_001"), 0, 0), (L("im:impactMetal_medium_003"), 0.02, -8),
         (L("ui:confirmation_001", lo=3500), 0.06, -12), (envelope(L("sf:spaceEngineLow_004", dur=1.3, lo=300), [(0, 0), (0.2, 1), (1.3, 0)]), 0, -8)], tail=0.2),
         ["core_command_lock"], "identity command locked: plate impact + metal + confirmation + low resonance")
    emit(S + "reject.wav", mix([(L("ui:error_007", lo=2500), 0, -2), (L("im:impactTin_medium_000"), 0, -8), (L("sf:laserSmall_002", lo=1500, reverse=True), 0, -14)], tail=0.05),
         ["core_reject"], "rejected operation: low-passed error buzz + tin knock")
    emit(S + "arm_confirm.wav", mix([(L("im:impactMetal_heavy_001"), 0, 0), (L("sf:lowFrequency_explosion_000"), 0, -2),
         (envelope(lp(ramp_resample(load("sf:spaceEngineLarge_000"), 0.6, 1.4, 3.6), 4000), [(0, 0), (0.6, 1), (2.4, 1), (3.6, 0)]), 0, -6),
         (L("sf:forceField_002"), 0.15, -7), (L("im:impactBell_heavy_004", lo=900), 0.25, -10)], tail=0.3), ["core_arm_confirm"], "ARM REACTOR: heavy metal slam + sub boom + engine spool-up glide + field + deep bell")
    emit(S + "console_open.wav", mix([(envelope(L("sf:computerNoise_003", dur=0.7, lo=4000), [(0, 0), (0.1, 1), (0.7, 0)]), 0, -8), (L("ui:toggle_003"), 0, -10)], tail=0.05),
         ["core_console_open"], "console power-on: computer noise + toggle")
    emit(S + "console_close.wav", mix([(L("sf:computerNoise_003", dur=0.4, lo=3000, reverse=True), 0, -12), (L("ui:toggle_004"), 0, -10)], tail=0.05),
         ["core_console_close"], "console power-off: reversed computer noise + toggle")
    rising = ramp_resample(load("sf:engineCircular_000"), 0.8, 1.6, 0.55)
    falling = ramp_resample(load("sf:engineCircular_000"), 1.6, 0.8, 0.55)
    siren = bp(np.concatenate((rising, falling)), 300, 2500)
    emit(S + "alarm_siren.wav", siren, ["core_alarm"], "reactor alarm: engineCircular variable-rate rise/fall, band-limited")
    for i in range(3):
        emit(S + f"arc_{i + 1}.wav", mix([(L(f"sf:laserSmall_00{i}", hi=700), 0, 0), (L(f"ui:glitch_00{i + 1}"), 0.01, -9)], tail=0.15),
             ["core_arc"], "distant electrical arc: laserSmall + glitch crackle")
        emit(S + f"clank_{i + 1}.wav", L(f"sf:impactMetal_00{i + 1}", lo=1200, ratio=0.75), ["core_clank"], "distant machinery clank: impactMetal slowed to 0.75x, low-passed")
    emit(S + "temporal_pulse.wav", mix([(L("sf:lowFrequency_explosion_001", lo=140), 0, 0), (L("sf:forceField_003", lo=900, reverse=True), 0, -8)], tail=0.1),
         ["core_temporal_pulse"], "mysterious temporal pulse: sub explosion + reversed force field")
    emit(S + "tier_hit.wav", mix([(L("sf:lowFrequency_explosion_001", lo=300), 0, 0), (L("im:impactMetal_heavy_000"), 0, -6)], tail=0.1),
         ["core_tier_hit"], "countdown tier stinger: low boom + metal hit")
    # percussion layer scheduled on the 135 BPM grid
    emit(S + "perc_kick.wav", envelope(lp(L("im:impactSoft_heavy_000"), 220), [(0, 1), (0.22, 0.4), (0.3, 0)])[:round(0.3 * SR)], ["core_perc_kick"], "pulse kick: impactSoft_heavy low-passed, shortened")
    emit(S + "perc_tick.wav", mix([(L("ui:tick_002"), 0, 0), (L("im:impactMetal_light_001", hi=3000), 0, -10)], tail=0.05), ["core_perc_tick"], "pulse hat: tick + light metal")
    emit(S + "perc_hit.wav", L("im:impactPlate_medium_000", hi=400), ["core_perc_hit"], "pulse accent: impactPlate_medium high-passed")
    emit(S + "warn_beep.wav", L("ui:bong_001", hi=200, ratio=2.0), ["core_warn_beep"], "countdown warning blip: bong pitched up one octave")
    emit(S + "countdown_second.wav", mix([(L("im:impactBell_heavy_000", hi=500, lo=3000), 0, -4), (L("ui:tick_004"), 0, -4)], tail=0.1),
         ["core_countdown_second"], "final ten-second marker: bell + tick")
    emit(S + "reset_return.wav", envelope(lp(ramp_resample(load("sf:spaceEngineLow_001"), 0.4, 1.0, 2.5), 600), [(0, 0), (1.2, 1), (2.5, 0)]), ["core_reset_return"],
         "attempt reset: low engine spin-up glide back toward the ambient hum")


def build_level3_loops():
    base = load("sf:spaceEngineLow_000", ch=1)
    core = loopify(bp(base, 45, 520), 0.8)
    emit("level3/sfx/reactor_core_loop.ogg", core, ["core_reactor_loop"], "positional reactor core hum: spaceEngineLow_000 band-passed 45-520 Hz, 0.8 s wrap crossfade", loop=True, peak_db=-6)
    coil = loopify(bp(load("sf:spaceEngineLow_003"), 90, 800), 0.8)
    emit("level3/sfx/coil_hum_loop.ogg", coil, ["core_coil_hum"], "aligned coil transformer hum: spaceEngineLow_003 band-passed 90-800 Hz", loop=True, peak_db=-6)
    seconds = 24.0
    vent = load("vent:ventilation", t0=8, dur=seconds, ch=2)
    past = mix([(widen(lp(hp(tile(load("sf:spaceEngineLow_000"), seconds), 40), 450)), 0, -2),
                (lp(hp(pitch(load("boiler:generator_loop"), 0.7), 40), 500), 0, -8), (lp(vent, 3500), 0, -12)], ch=2, length=round(seconds * SR))
    emit("level3/ambience/core_ambience_past.ogg", loopify(past, 1.5), ["core_ambience_past"],
         "Past reactor bed: spaceEngineLow + boiler loop at 0.7x pitch + ventilation, low-passed", kind="ambience", loop=True, rms_db=-26.0)
    wind = load("wind:wind", dur=seconds, ch=2)
    detuned = pitch(load("boiler:generator_loop"), 0.62)
    future_hum = ff(widen(lp(hp(detuned, 35), 380)), "vibrato=f=0.35:d=0.6")
    future = mix([(widen(lp(hp(tile(pitch(load("sf:spaceEngineLow_000"), 0.8), seconds), 35), 380)), 0, -3), (future_hum, 0, -6),
                  (hp(lp(wind, 3000), 250), 0, -9)], ch=2, length=round(seconds * SR))
    emit("level3/ambience/core_ambience_future.ogg", loopify(future, 1.5), ["core_ambience_future"],
         "Future reactor bed: detuned engine + boiler at 0.62x with slow vibrato + air leak", kind="ambience", loop=True, rms_db=-27.0)


def build_riser():
    n = round(10.0 * SR)
    drone = ramp_resample(load("sf:engineCircular_001", ch=2), 0.55, 2.2, 10.0)
    drone = bp(drone, 120, 5000)
    drone = envelope(drone, [(0, 0), (2, 0.25), (8, 0.8), (9.6, 1), (10, 0)])
    swell = ramp_resample(load("sf:spaceEngineLarge_001", ch=2), 0.5, 1.9, 10.0)
    swell = envelope(lp(swell, 5000), [(0, 0), (4, 0.2), (9.5, 1), (10, 0)])
    boom = mix([(rev(L("sf:explosionCrunch_004")), 8.0, -4), (rev(L("sf:lowFrequency_explosion_000")), 7.4, -2)], ch=1, length=n)
    ticks = [(L("ui:tick_004"), 5.0 + t, -8) for t in np.concatenate((np.arange(0, 3, 0.5), np.arange(3, 4.5, 0.25), np.arange(4.5, 5, 0.125)))]
    x = mix([(stereo(drone), 0, -6), (stereo(swell), 0, -4), (stereo(boom), 0, -3), *[(stereo(a), b, c) for a, b, c in ticks]], ch=2, length=n)
    emit("level3/music/core_riser_final.ogg", x, ["core_riser_final"],
         "final ten-second riser: engineCircular and spaceEngineLarge variable-rate glides (0.55x->2.2x) + reversed explosion run-in + accelerating ticks",
         kind="music", peak_db=-6.0)


def build_endings():
    E = "level3/endings/"
    rng = np.random.default_rng(7)
    # Trust / Last Goodbye: peaceful release, stabilization, melancholy
    airy = lp(hp(load("dsf:airy", t0=20 * BAR, dur=24.0, ch=2), 80), 2200)
    victory = ff(lp(load("dsf:victory", ch=2), 1800), "aecho=0.8:0.7:600:0.3")
    spin = stereo(envelope(lp(ramp_resample(load("sf:spaceEngineLow_002"), 1.0, 0.25, 8.0), 500), [(0, 0), (0.5, 1), (8, 0)]))
    shimmer = [(stereo(L("ui:glass_003", lo=8000, reverse=True)), 0.2, -14), (stereo(L("ui:glass_005", ratio=0.8)), 3.0, -16),
               (stereo(L("sf:forceField_002", reverse=True)), 4.5, -16)]
    x = mix([(envelope(airy, [(0, 0), (3, 1), (17, 1), (24, 0)]), 0, -2), (victory, 1.0, -6), (spin, 0, -9), *shimmer], ch=2, length=round(24 * SR))
    emit(E + "ending_trust.ogg", x, ["core_ending_trust"], "Trust: airy pad + softened victory sting + reactor spin-down glide + reversed glass shimmer", kind="ending", peak_db=-5.0)
    # Student Override: reverse energy, erasure
    pulse = tv_lowpass(rev(load("dsf:pulse", t0=24 * BAR, dur=8 * BAR, ch=2)), 9000, 220)
    glide = [(stereo(ramp_resample(load("sf:laserLarge_000"), 1.6, 0.3, 4.0)), 3.0, -6),
             (stereo(rev(L("sf:explosionCrunch_004"))), 0.2, -5),
             *[(stereo(rev(ramp_resample(load("sf:forceField_000"), 1.0, 0.6 + 0.2 * k, 1.5))), 1.5 + k * 1.6, -6) for k in range(4)]]
    x = mix([(envelope(pulse, [(0, 0), (1.5, 1), (11.5, 1), (12.0, 0)]), 0, -3), *glide, (stereo(L("sf:lowFrequency_explosion_000")), 12.0, 0),
             (stereo(L("ui:glass_001", lo=7000, ratio=0.6)), 12.3, -16)], ch=2, length=round(16 * SR))
    emit(E + "ending_student_override.ogg", x, ["core_ending_student_override"], "Student Override: reversed pulse closing to 220 Hz + reversed explosions/force fields + falling laser glide + sub boom then hush", kind="ending", peak_db=-5.0)
    # Professor Override: cold locking, resonance, ominous
    trans = ff(tv_lowpass(load("dsf:transmission", t0=8.0, dur=20.0, ch=2), 6000, 900), "aecho=0.8:0.88:900|1700:0.4|0.3")
    locks = [(stereo(L("im:impactPlate_heavy_000")), 0.5, -2), (stereo(L("im:impactGlass_heavy_001", lo=6000)), 1.7, -6),
             (stereo(L("sf:doorClose_001", ratio=0.6)), 3.2, -4)]
    res = stereo(lp(load("sf:spaceEngineLarge_001"), 180))
    deep = np.concatenate((res, res[:-round(1.0 * SR)]))
    bell = ff(stereo(L("im:impactBell_heavy_000", lo=2500, ratio=0.5)), "aecho=0.8:0.9:1200:0.5")
    x = mix([(envelope(trans, [(0, 0), (2, 1), (16, 1), (20, 0)]), 0, -4), *locks,
             (envelope(deep, [(0, 0), (1, 1), (8, 1), (9, 0)]), 0.0, -3), (bell, 11.0, -2)], ch=2, length=round(20 * SR))
    emit(E + "ending_professor_override.ogg", x, ["core_ending_professor_override"], "Professor Override: transmission closing to 900 Hz with long echo + plate/glass/door lock hits + 180 Hz resonance + octave-down bell", kind="ending", peak_db=-5.0)
    # Paradox / Iteration 02: distortion, glitches, reversal, reset
    base = load("dsf:transmission", t0=30.0, dur=22.0, ch=2)
    crushed = ff(base, "acrusher=bits=5:mix=0.8:mode=lin,vibrato=f=6:d=0.5")
    glitch = [(stereo(L(f"ui:glitch_00{int(rng.integers(1, 5))}")), float(t), -6) for t in np.sort(rng.uniform(1.0, 16.5, 16))]
    stutter_src = base[round(5.0 * SR):round(5.12 * SR)]
    stutter = np.concatenate([stutter_src] * 8)
    unstable = ff(stereo(lp(ramp_resample(load("sf:spaceEngineLow_004"), 0.5, 0.5, 22.0), 400)), "vibrato=f=3:d=0.8")
    reset = [(stereo(rev(L("sf:lowFrequency_explosion_000"))), 17.0, -2), (stereo(rev(L("sf:explosionCrunch_000"))), 18.0, -3)]
    x = mix([(envelope(crushed, [(0, 0), (1, 1), (17, 1), (19.5, 0)]), 0, -4), (envelope(rev(crushed), [(0, 0), (6, 0.6), (15, 0.6), (17, 0)]), 0, -12),
             (stutter, 9.0, -6), (stutter, 13.2, -6), (envelope(unstable, [(0, 0), (3, 1), (18, 1), (19.5, 0)]), 0, -6), *glitch, *reset,
             (stereo(L("sf:forceField_000", lo=1500)), 20.3, -10)], ch=2, length=round(22 * SR))
    emit(E + "ending_paradox.ogg", x, ["core_ending_paradox"], "Paradox: bit-crushed vibrato transmission + reversed ghost + stutter + 16 seeded glitches + unstable low engine + reversed explosion reset", kind="ending", peak_db=-5.0)
    # Overload meltdown cues (the 5 s cinematic fires impact at 0.8 s, rupture, then shockwave at 1.1 s)
    O = "level3/sfx/"
    impact = mix([(stereo(L("sf:explosionCrunch_000")), 0, 0), (stereo(L("sf:lowFrequency_explosion_000")), 0, 0), (stereo(L("im:impactMetal_heavy_001")), 0, -4),
                  (stereo(L("ui:glitch_001")), 0.05, -8)], ch=2, tail=1.2)
    emit(O + "overload_impact.wav", tv_lowpass(drive(impact, 3.0), 9000, 400), ["core_overload_impact"],
         "Reactor overload impact: explosionCrunch + sub explosion + metal slam + glitch, saturated and closing 9 kHz -> 400 Hz", kind="ending", peak_db=-4.0)
    zaps = [(stereo(L(f"sf:laserLarge_00{k % 5}", hi=700)), 0.1 + 0.28 * k, -8) for k in range(8)]
    glitches = [(stereo(L(f"ui:glitch_00{k % 4 + 1}")), 0.05 + 0.17 * k, -7) for k in range(12)]
    rupture = mix([(stereo(L("sf:explosionCrunch_004")), 0, -2), *zaps, *glitches], ch=2, tail=0.6)
    emit(O + "overload_rupture.wav", tv_lowpass(drive(rupture, 2.0), 10000, 600), ["core_overload_rupture"],
         "Reactor overload rupture: explosionCrunch_004 + eight laser tears + twelve glitch bursts", kind="ending", peak_db=-6.0)
    wave = ramp_resample(load("sf:lowFrequency_explosion_001", ch=2), 1.0, 0.35, 4.0)
    swell = envelope(lp(ramp_resample(load("sf:spaceEngineLarge_000", ch=2), 0.7, 0.4, 4.0), 300), [(0, 0), (0.4, 1), (3.0, 0.7), (4.0, 0)])
    emit(O + "overload_shockwave.wav", tv_lowpass(mix([(wave, 0, 0), (swell, 0, -3), (stereo(rev(L("sf:forceField_002"))), 0, -9)], ch=2), 7000, 120), ["core_overload_shockwave"],
         "Reactor overload shockwave: falling-rate sub explosion + low engine swell + reversed field, collapsing to 120 Hz", kind="ending", peak_db=-5.0)


# ---------------------------------------------------------------- level 2
def build_level2():
    S = "level2/sfx/"
    seconds = 22.0
    boiler = load("boiler:generator_loop")
    vent = load("vent:ventilation", t0=8, dur=seconds, ch=2)
    past = mix([(widen(lp(hp(boiler, 55), 1200)), 0, -3), (lp(vent, 4000), 0, -9)], ch=2, length=len(boiler))

    emit("level2/ambience/maint_bed_past.ogg", loopify(past, 1.5), ["maint_bed_past"], "Level 2 Past bed: steam boiler loop 55-1200 Hz + ventilation",
         kind="ambience", loop=True, rms_db=-30.0)
    wind = load("wind:wind", dur=seconds, ch=2)
    boiler = load("boiler:generator_loop")
    future = mix([(widen(lp(hp(pitch(boiler, 0.85), 70), 900)), 0, -4), (hp(lp(wind, 3000), 220), 0, -9)], ch=2, length=round(seconds * SR))
    emit("level2/ambience/maint_bed_future.ogg", loopify(future, 1.5), ["maint_bed_future"], "Level 2 Future bed: boiler loop at 0.85x + air leak",
         kind="ambience", loop=True, rms_db=-30.0)
    boiler = load("boiler:generator_loop")
    emit("level2/sfx/machine_loop.ogg", loopify(lp(hp(boiler, 60), 900), 1.0), ["maint_machine_loop"], "positional boiler machinery: generator loop 60-900 Hz", loop=True, peak_db=-6)
    buzz = bp(load("sf:spaceEngineSmall_001"), 100, 1500)
    emit("level2/sfx/buzz_loop.ogg", loopify(ff(buzz, "tremolo=f=100:d=0.5"), 0.6), ["maint_buzz_loop"], "positional electrical buzz: spaceEngineSmall band-passed, 100 Hz tremolo", loop=True, peak_db=-6)
    emit(S + "lever_clunk.wav", mix([(L("im:impactMetal_heavy_001"), 0, 0), (L("im:impactMining_001", lo=3000), 0, -8),
         (L("sf:forceField_001", reverse=True, lo=3000), 0.05, -10), (L("ui:switch_003", hi=400), 0, -12)], tail=0.2), ["maint_lever_clunk"], "service isolator lever: heavy metal + mining impact + reversed disconnect arc")
    ratchet = [(mix([(L("ui:tick_004"), 0, 0), (L(f"im:impactMetal_light_00{k % 4}", hi=1500), 0, -8)], tail=0.02), 0.04 + k * 0.095 * (1 - 0.02 * k), -2 * (k % 2)) for k in range(8)]
    emit(S + "crank_ratchet.wav", mix(ratchet, tail=0.1), ["maint_crank"], "emergency crank: eight ratchet clicks (tick + light metal) over the 0.85 s wheel turn")
    emit(S + "charge_latch.wav", mix([(L("im:impactMetal_heavy_000"), 0, 0), (L("sf:laserSmall_003"), 0.05, -8), (L("im:impactBell_heavy_001", lo=2000), 0.1, -8)], tail=0.2),
         ["maint_charge_latch"], "battery charge latch: heavy metal + zap + bell")
    emit(S + "power_surge.wav", mix([(L("sf:lowFrequency_explosion_001"), 0, 0), (envelope(L("sf:spaceEngineLarge_003", dur=2.4, lo=2500), [(0, 0), (1.2, 1), (2.4, 0)]), 0, -8),
         (L("sf:laserLarge_001", hi=600), 0.3, -10), (L("sf:laserLarge_003", hi=600), 0.7, -10)], tail=0.3), ["maint_power_surge"], "electrical restoration surge: sub boom + engine swell + zaps")
    emit(S + "power_down.wav", mix([(ramp_resample(load("sf:forceField_002"), 1.0, 0.3, 1.2), 0, -3), (L("ui:error_005"), 0, -8)], tail=0.2),
         ["maint_power_down"], "voltage drop: descending force field + low error")
    emit(S + "reserve_lever.wav", mix([(L("im:impactPlate_heavy_000"), 0, 0), (L("im:impactMetal_medium_002"), 0.02, -6), (L("sf:laserSmall_001", hi=800), 0.08, -10)], tail=0.2),
         ["maint_reserve_lever"], "reserve priority lever: plate + metal + short zap")
    emit(S + "fuse_seat.wav", mix([(L("im:impactMetal_light_003", hi=500), 0, 0), (L("im:impactMetal_medium_004", lo=3500), 0.07, -5), (L("ui:switch_005"), 0.1, -12)], tail=0.1),
         ["maint_fuse_seat"], "fuse seated / ground lead clamped: light metal + clack + switch")
    emit(S + "archive_access.wav", mix([(envelope(L("sf:computerNoise_002", dur=1.6, lo=5000), [(0, 0), (0.2, 1), (1.6, 0)]), 0, -6), (L("ui:maximize_004"), 0.1, -12)], tail=0.1),
         ["maint_archive"], "archive terminal access: computer noise + interface open")
    emit(S + "recorder_export.wav", mix([(ramp_resample(load("sf:computerNoise_000", dur=1.0), 0.8, 1.7, 1.8), 0, -6), (L("ui:confirmation_002"), 1.7, -8), (L("im:impactMetal_light_001", lo=3000), 0, -10)], tail=0.2),
         ["maint_recorder_export"], "recorder export: rising data chatter glide + confirmation")
    emit(S + "cell_pull.wav", mix([(L("im:impactPlate_heavy_001", lo=3000), 0, 0), (ramp_resample(load("sf:forceField_003"), 1.0, 0.3, 1.0), 0.05, -6), (L("ui:error_006"), 0.1, -12)], tail=0.2),
         ["maint_cell_pull"], "backup cell pulled: plate impact + collapsing field")
    emit(S + "keypad_authorize.wav", mix([(L("im:impactMetal_medium_000", lo=4000), 0, -2), (L("ui:confirmation_004"), 0.05, -6), (L("sf:laserSmall_003", lo=3000), 0.1, -12)], tail=0.2),
         ["maint_keypad_authorize"], "access granted: metal latch + confirmation + zap")
    grind = pitch(L("ui:scratch_002", hi=100), 0.5)
    emit(S + "release_wheel.wav", mix([(envelope(np.concatenate((grind, grind)), [(0, 0), (0.1, 1), (1.2, 1), (len(grind) * 2 / SR, 0)]), 0, -4),
         (L("im:impactMining_002", lo=2500), 0.0, -6), (L("im:impactMetal_heavy_002"), 1.0, -4)], tail=0.2), ["maint_release_wheel"], "manual release wheel: slowed scratch grind + mining impact + latch thunk")
    emit(S + "gate_open.wav", mix([(L("sf:doorOpen_001", ratio=0.6), 0, -2), (L("sf:spaceEngineLow_002", dur=2.5, lo=300), 0, -8), (L("im:impactMetal_heavy_000"), 0.05, -6)], tail=0.4),
         ["maint_gate_open"], "Core gate opens: door slowed to 0.6x + low engine rumble + metal hit")
    emit(S + "anchor_latch.wav", mix([(L("im:impactPlate_heavy_001"), 0, 0), (L("sf:laserSmall_002"), 0.03, -8), (L("sf:forceField_001", lo=1200), 0.05, -10)], tail=0.2),
         ["maint_anchor_latch"], "stabilization contact latched: plate + zap + field")
    emit(S + "anchor_complete.wav", mix([(L("sf:lowFrequency_explosion_001"), 0, 0), (L("im:impactBell_heavy_000", lo=2500), 0.1, -4), (ramp_resample(load("sf:forceField_004"), 0.7, 1.5, 1.6), 0.2, -8)], tail=0.5),
         ["maint_anchor_complete"], "both anchors stable: sub boom + bell + rising field")
    emit(S + "hatch_open.wav", mix([(envelope(L("sf:thrusterFire_002", dur=0.9, lo=5000, hi=300), [(0, 0), (0.1, 1), (0.9, 0)]), 0, -6), (L("sf:doorOpen_002", ratio=0.8), 0, -4), (L("im:impactMetal_heavy_002"), 0.3, -8)], tail=0.1),
         ["maint_hatch_open"], "floor hatch: hydraulic hiss + door slowed + latch")
    emit(S + "hatch_close.wav", mix([(envelope(L("sf:thrusterFire_003", dur=0.9, lo=5000, hi=300), [(0, 0), (0.1, 1), (0.9, 0)]), 0, -6), (L("sf:doorClose_002", ratio=0.8), 0.1, -4), (L("im:impactMetal_heavy_001"), 0.4, -6)], tail=0.1),
         ["maint_hatch_close"], "floor hatch closes: hydraulic hiss + door + seal thunk")
    lift = envelope(lp(L("sf:spaceEngineSmall_002", dur=1.2), 1800), [(0, 0), (0.15, 1), (1.0, 1), (1.2, 0)])
    emit(S + "lift_move.wav", mix([(lift, 0, -4), (L("sf:thrusterFire_001", dur=1.2, lo=3000, hi=300), 0, -12)], tail=0.05), ["maint_lift_move"], "hydraulic lift movement: small engine drone + hiss")
    emit(S + "lift_stop.wav", mix([(L("im:impactMetal_heavy_000"), 0, 0), (envelope(L("sf:thrusterFire_000", dur=0.6, lo=4000, hi=400), [(0, 1), (0.6, 0)]), 0.03, -8)], tail=0.1),
         ["maint_lift_stop"], "lift settles: metal clunk + hiss release")
    for i in range(3):
        emit(S + f"clank_{i + 1}.wav", L(f"sf:impactMetal_00{i + 2}", lo=1500, ratio=0.7), ["maint_detail"], "distant pipe clank: impactMetal slowed to 0.7x")
    emit(S + "steam_hiss.wav", envelope(L("sf:thrusterFire_004", dur=2.2, lo=7000, hi=1500), [(0, 0), (0.5, 1), (1.4, 0.8), (2.2, 0)]), ["maint_detail"], "steam vent: thrusterFire band-limited with swell")


def merge_provenance():
    path = OUT / "asset_provenance.json"
    existing = json.loads(path.read_text(encoding="utf8"))
    existing = [r for r in existing if r.get("collection") != "level2_level3_audio"]
    path.write_text(json.dumps(existing + records, indent=2) + "\n", encoding="utf8")


def main():
    if "--fetch" in sys.argv:
        fetch()
    build_music()
    build_level3_sfx()
    build_level3_loops()
    build_riser()
    build_endings()
    build_level2()
    merge_provenance()
    licenses = OUT / "licenses"
    for key, name in (("dsf", "srg774_dark_sci_fi_audio_pack.txt"), ("boiler", "bart_steam_boiler_loop.txt")):
        pack = PACKS[key]
        (licenses / name).write_text(
            f"{pack['title']}\nCreator: {pack['creator']}\nPage: {pack['page']}\nLicense: CC0 1.0 Universal (public domain dedication), as shown on the OpenGameArt page.\n"
            f"License text: {CC0}\nAttribution is not required; the creator asks for credit where convenient.\nDownload: {pack['download']}\nSHA256: {pack['sha256']}\nVerified: {DATE}\n",
            encoding="utf8")
    print(f"Prepared {len(records)} level 2/3 audio assets.")


if __name__ == "__main__":
    main()
