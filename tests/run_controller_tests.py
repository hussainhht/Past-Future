#!/usr/bin/env python3
"""Run the PlayStation 5 DualSense controller support tests headless.

Run from any directory: python tests/run_controller_tests.py
Set GODOT_BIN to the Godot console executable (or put godot/godot4 on PATH).
"""

from pathlib import Path
import os
import shutil
import subprocess
import sys
import time

PROJECT = Path(__file__).resolve().parents[1]
FATAL_MARKERS = ("SCRIPT ERROR", "Parse Error", "ERROR:")


def verify(output: str, returncode: int, marker: str) -> None:
    problems = [line for line in output.splitlines() if any(m in line for m in FATAL_MARKERS)]
    if returncode or marker not in output or problems:
        print(output)
        raise RuntimeError(f"Failed: {marker}\n{output}")
    print(next(line for line in output.splitlines() if line.startswith(marker)), flush=True)


def main() -> None:
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
    if not godot:
        raise SystemExit("Set GODOT_BIN to your Godot console executable.")

    print(f"Running PS5 Controller Tests with {godot}...")
    started = time.monotonic()
    result = subprocess.run([
        godot, "--headless", "--path", str(PROJECT),
        "--script", "res://tests/controller_system.gd"
    ], capture_output=True, text=True, timeout=120)

    output = result.stdout + result.stderr
    verify(output, result.returncode, "PS5 CONTROLLER SYSTEM: PASS")
    print(f"Controller verification complete in {time.monotonic() - started:.2f}s")


if __name__ == "__main__":
    main()

