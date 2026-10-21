#!/usr/bin/env python3
"""Run the room-introduction checks on the real rooms (needs a renderer).

    python tests/run_cinematic_tests.py [--out DIR]

Set GODOT_BIN to the Godot executable. Without a DISPLAY the runner uses xvfb-run (software GL).
Screenshots of both themes, reduced motion and the target resolutions go to --out (default: a temp
folder that is printed at the end).
"""

from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

PROJECT = Path(__file__).resolve().parents[1]


def main() -> int:
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
    if not godot:
        raise SystemExit("Set GODOT_BIN to the Godot executable, or put godot/godot4 on PATH.")
    out = Path(sys.argv[sys.argv.index("--out") + 1]) if "--out" in sys.argv else Path(tempfile.mkdtemp(prefix="past-future-cinematic-"))
    out.mkdir(parents=True, exist_ok=True)
    display = [] if os.environ.get("DISPLAY") else ["xvfb-run", "-a", "-s", "-screen 0 1600x900x24"]
    result = subprocess.run(
        display + [godot, "--path", str(PROJECT), "--rendering-driver", "opengl3", "--audio-driver", "Dummy",
                   "--script", "res://tests/cinematic_system.gd"],
        capture_output=True, text=True, timeout=300, env=dict(os.environ, CINEMA_DIR=str(out)))
    text = result.stdout + result.stderr
    bad = [line for line in text.splitlines() if "SCRIPT ERROR:" in line or "FAILED:" in line or "leaked at exit" in line]
    if result.returncode or bad or "CINEMATIC: PASS" not in text:
        print("\n".join(bad[:20]) + "\n--- log ---\n" + text)
        return 1
    print("CINEMATIC: PASS  (screenshots: %s)" % out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
