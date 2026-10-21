#!/usr/bin/env python3
"""Run the first-time tutorial popup test headless against the real solo room.

Run from any directory: python tests/run_tutorial_tests.py
Set GODOT_BIN to the Godot executable (or put godot/godot4 on PATH).
"""

from pathlib import Path
import os
import shutil
import subprocess

PROJECT = Path(__file__).resolve().parents[1]


def main() -> None:
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
    if not godot:
        raise SystemExit("Set GODOT_BIN to the Godot executable, or put godot/godot4 on PATH.")
    result = subprocess.run(
        [godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/tutorial_popup.gd"],
        capture_output=True, text=True, timeout=120,
    )
    output = result.stdout + result.stderr
    problems = [line for line in output.splitlines() if "SCRIPT ERROR" in line or "FAILED:" in line]
    if result.returncode or "TUTORIAL POPUP: PASS" not in output or problems:
        print(output)
        raise RuntimeError("Tutorial popup tests failed")
    print(next(line for line in output.splitlines() if line.startswith("TUTORIAL POPUP:")))


if __name__ == "__main__":
    main()
