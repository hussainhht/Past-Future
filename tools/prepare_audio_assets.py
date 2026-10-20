"""Prepare acquired CC0 recordings/packs; never synthesizes replacement audio.

Source downloads and verified page snapshots live in .godot/audio_sources (not shipped).
Requires ffmpeg and numpy. Produces distributable assets plus a provenance manifest.
"""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / ".godot/audio_sources"
OUT = ROOT / "assets/audio"
DATE = "2026-10-20"
records = []


def decode(path, channels=1, filters=""):
    command = ["ffmpeg", "-v", "error", "-i", str(path)]
    if filters:
        command += ["-af", filters]
    data = subprocess.check_output(command + ["-f", "f32le", "-ac", str(channels), "-ar", "48000", "-"])
    return np.frombuffer(data, np.float32).copy().reshape(-1, channels)


def prepare(source, target, title, creator, page, *, start=0.0, duration=None,
            filters="", loop=False, stereo=False, original=None):
    channels = 2 if stereo else 1
    x = decode(CACHE / source, channels, filters)
    x = x[round(start * 48000):]
    if duration is not None:
        x = x[:round(duration * 48000)]
    x -= np.mean(x, axis=0)
    if loop:
        # Tail->head overlap: both sides of the wrap meet at original sample n.
        n = min(48000 * 2, len(x) // 8)
        ramp = np.linspace(0, 1, n, dtype=np.float32)[:, None]
        seam = x[-n:] * (1 - ramp) + x[:n] * ramp
        x = np.concatenate((x[n:-n], seam))
    else:
        energy = np.max(np.abs(x), axis=1)
        active = np.flatnonzero(energy > max(float(energy.max()) * 0.006, 0.0001))
        if len(active):
            x = x[max(0, active[0] - 240):min(len(x), active[-1] + 2400)]
        n = min(240, len(x) // 4)
        x[:n] *= np.linspace(0, 1, n)[:, None]
        x[-n:] *= np.linspace(1, 0, n)[:, None]
    peak = float(np.max(np.abs(x)))
    if peak > 0:
        x *= (10 ** (-6 / 20)) / peak
    dest = OUT / target
    dest.parent.mkdir(parents=True, exist_ok=True)
    codec = ["-c:a", "libvorbis", "-q:a", "5"] if dest.suffix == ".ogg" else ["-c:a", "pcm_s16le"]
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", "48000",
                    "-ac", str(channels), "-i", "-", *codec, str(dest)], input=x.astype(np.float32).tobytes(), check=True)
    source_html = CACHE / (source.split("/")[0] + ".html")
    if page.startswith("https://kenney.nl"):
        html = source_html.read_text(encoding="utf8")
        direct = re.search(r'https://kenney\.nl/[^\"\']+\.zip', html).group()
    elif "freesound.org/people" in page:
        html = (CACHE / (source.split(".")[0] + ".html")).read_text(encoding="utf8")
        direct = re.search(r'https://cdn\.freesound\.org/[^\"\s<>]+-hq\.mp3', html).group()
    else:
        html_name = "future_music_alternative" if "galactic-temple" in page else "past_music" if "another-space" in page else "wind"
        html = (CACHE / (html_name + ".html")).read_text(encoding="utf8")
        links = re.findall(r'href=[\"\']([^\"\']+\.(?:zip|ogg))', html)
        direct = links[-1] if html_name == "wind" else links[0]
    if "freesound.org/people" in page:
        original = direct.rsplit("/", 1)[-1]
    records.append({"original_asset_title": title, "creator": creator, "source_url": page,
                    "direct_asset_page_url": page, "download_url": direct, "license": "CC0-1.0",
                    "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
                    "attribution_requirements": "None; voluntary credit retained.", "download_date": DATE,
                    "original_filename": original or Path(source).name, "downloaded_filename": direct.rsplit("/", 1)[-1] if "freesound.org/people" in page else Path(source).name, "cached_source": source,
                    "imported_filename": dest.relative_to(ROOT).as_posix(), "source_sha256": hashlib.sha256((CACHE / source).read_bytes()).hexdigest(),
                    "sha256": hashlib.sha256(dest.read_bytes()).hexdigest(), "duration_seconds": round(len(x) / 48000, 4),
                    "processing": {"start_seconds": start, "duration_limit_seconds": duration,
                                   "filters": filters, "seam_overlap": loop, "peak_dbfs": -6,
                                   "channels": channels, "mix_rate": 48000},
                    "sound_event_ids": [], "intended_game_usage": []})


def main():
    for i, start in enumerate([2.97, 4.96, 8.83, 10.02, 11.26, 13.90], 1):
        prepare("tile.mp3", f"footsteps/past_tile/step_{i:02}.wav", "Footsteps, Tile, Male Sneakers, Slow Pace.wav",
                "SpliceSound", "https://freesound.org/people/SpliceSound/sounds/170506/", start=start,
                duration=0.58, filters="highpass=f=85,lowpass=f=11000",
                original="Footsteps, Tile, Male Sneakers, Slow Pace.wav")
    for i in range(5):
        prepare(f"impact-sounds/Audio/footstep_concrete_{i:03}.ogg", f"footsteps/future_concrete/step_{i+1:02}.wav",
                "Impact Sounds", "Kenney", "https://kenney.nl/assets/impact-sounds", filters="highpass=f=65,lowpass=f=6500")
    for source, target in {
        "click_001": "ui/click", "select_001": "ui/hover", "confirmation_002": "ui/confirm",
        "back_001": "ui/back", "open_001": "ui/open", "close_001": "ui/close",
        "error_003": "ui/error", "switch_002": "interactions/switch",
        "scroll_001": "computer/tune", "confirmation_001": "computer/lock",
        "maximize_001": "computer/calibrate", "glitch_001": "computer/invalid",
        "question_001": "radio/incoming", "select_003": "radio/outgoing",
        "confirmation_004": "radio/connect", "minimize_001": "radio/disconnect",
        "toggle_001": "radio/activate", "toggle_002": "radio/deactivate",
        "pluck_001": "puzzles/progress",
    }.items():
        prepare(f"interface-sounds/Audio/{source}.ogg", target + ".wav", "Interface Sounds", "Kenney",
                "https://kenney.nl/assets/interface-sounds", filters="highpass=f=100,lowpass=f=9500")
    for source, target in {
        "doorOpen_000": "doors/open", "doorClose_000": "doors/close",
        "computerNoise_000": "computer/equipment", "impactMetal_000": "ambience/future/metal_detail",
    }.items():
        prepare(f"sci-fi-sounds/Audio/{source}.ogg", target + ".wav", "Sci-fi Sounds", "Kenney",
                "https://kenney.nl/assets/sci-fi-sounds", filters="highpass=f=110,lowpass=f=6000")
    prepare("impact-sounds/Audio/impactGeneric_light_000.ogg", "radio/pickup.wav", "Impact Sounds", "Kenney",
            "https://kenney.nl/assets/impact-sounds", filters="lowpass=f=8000")
    prepare("paper.mp3", "documents/paper.wav", "Paper Rustle", "BenjaminNelan",
            "https://freesound.org/people/BenjaminNelan/sounds/353125/", original="Paper Rustle")
    prepare("radio_static.mp3", "radio/static.wav", "Radio Static.wav", "thegoose09",
            "https://freesound.org/people/thegoose09/sounds/125392/", start=3.0, duration=0.38,
            filters="highpass=f=600,lowpass=f=3300", original="Radio Static.wav")
    prepare("ventilation.mp3", "ambience/past/ventilation.ogg", "Room Tone, Deep Ventilation", "Kinoton",
            "https://freesound.org/people/Kinoton/sounds/503255/", start=8, duration=55, loop=True, stereo=True,
            filters="highpass=f=55,lowpass=f=5000", original="Room Tone, Deep Ventilation.wav")
    prepare("wind.ogg", "ambience/future/air_leak.ogg", "wind whoosh loop", "SketchMan3",
            "https://opengameart.org/content/wind-whoosh-loop", loop=True, stereo=True,
            filters="highpass=f=100,lowpass=f=4200", original="wind woosh loop.ogg")
    prepare("sci-fi-sounds/Audio/forceField_000.ogg", "rift/energy_loop.ogg", "Sci-fi Sounds", "Kenney",
            "https://kenney.nl/assets/sci-fi-sounds", loop=True, filters="highpass=f=90,lowpass=f=1800")
    prepare("interface-sounds/Audio/glass_001.ogg", "rift/stabilize.wav", "Interface Sounds", "Kenney",
            "https://kenney.nl/assets/interface-sounds", filters="lowpass=f=6500")
    prepare("past_music/ObservingTheStar.ogg", "music/past/observing_the_star.ogg", "Another space background track (ObservingTheStar)",
            "yd", "https://opengameart.org/content/another-space-background-track", loop=True, stereo=True)
    prepare("future_music/GalacticTemple.ogg", "music/future/galactic_temple.ogg", "Galactic Temple",
            "yd", "https://opengameart.org/content/galactic-temple", loop=True, stereo=True)
    license_dir = OUT / "licenses"
    license_dir.mkdir(exist_ok=True)
    for pack in ["impact-sounds", "interface-sounds", "sci-fi-sounds"]:
        shutil.copyfile(CACHE / pack / "License.txt", license_dir / ("kenney_" + pack.replace("-", "_") + ".txt"))
    catalog_path = ROOT / "resources/audio/sound_events.tres"
    if catalog_path.exists():
        events = json.loads(re.search(r"events = (\{.*\})\nassets =", catalog_path.read_text(encoding="utf8"), re.S).group(1))
        for record in records:
            record["sound_event_ids"] = [key for key, entry in events.items() if "res://" + record["imported_filename"] in entry["files"]]
            record["intended_game_usage"] = record["sound_event_ids"]
    (OUT / "asset_provenance.json").write_text(json.dumps(records, indent=2) + "\n", encoding="utf8")
    print(f"Prepared {len(records)} licensed audio assets.")


if __name__ == "__main__":
    main()
