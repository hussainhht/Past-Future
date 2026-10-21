#!/usr/bin/env python3
"""Run the main-menu button tests headless.

Run from any directory: python tests/run_menu_tests.py
Set GODOT_BIN to the Godot executable (or put godot/godot4 on PATH).
"""

from pathlib import Path
import os
import shutil
import subprocess
import time

PROJECT = Path(__file__).resolve().parents[1]
FATAL_MARKERS = ("SCRIPT ERROR", "Parse Error", "ERROR:")


def main() -> None:
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
    if not godot:
        raise SystemExit("Set GODOT_BIN to the Godot executable, or put godot/godot4 on PATH.")

    started = time.monotonic()
    result = subprocess.run(
        [godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/menu_buttons.gd"],
        capture_output=True, text=True, timeout=120,
    )
    output = result.stdout + result.stderr
    problems = [line for line in output.splitlines() if any(marker in line for marker in FATAL_MARKERS)]
    if result.returncode or "MENU BUTTONS: PASS" not in output or problems:
        print(output)
        raise RuntimeError("Menu button tests failed")
    print(next(line for line in output.splitlines() if line.startswith("MENU BUTTONS:")), flush=True)
    print(f"Menu verification complete in {time.monotonic() - started:.2f}s")


if __name__ == "__main__":
    main()
