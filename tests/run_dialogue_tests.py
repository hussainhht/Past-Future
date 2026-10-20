#!/usr/bin/env python3
"""Run the dialogue system tests headless, with the checks Godot itself does not make.

Run from any directory: python tests/run_dialogue_tests.py [--skip-import] [--regression]
Set GODOT_BIN to the Godot executable (or put godot/godot4 on PATH).

Why a runner at all:
  - The dialogue scripts use class_name. Godot registers those names when it imports the project,
    so the project is imported first (--skip-import to skip it when you know it is fresh).
  - Godot scripts print PASS even when the engine logs a script error, so the output is also
    scanned for "SCRIPT ERROR", "Parse Error" and "ERROR:" lines.
--regression also runs the other headless suites (puzzle system, spawn area, student 3D).
The multi-process LAN checks stay in run_puzzle_tests.py and run_lan_smoke.py.
"""

from pathlib import Path
import argparse
import os
import shutil
import subprocess
import time

FATAL_MARKERS = ("SCRIPT ERROR", "Parse Error", "ERROR:")

DIALOGUE_SUITE = ("DIALOGUE SYSTEM", "res://tests/dialogue_system.gd")
REGRESSION_SUITES = (
    ("PUZZLE SYSTEM", "res://tests/puzzle_system.gd"),
    ("SPAWN AREA", "res://tests/spawn_area.gd"),
    ("STUDENT 3D", "res://tests/student_3d.gd"),
)


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the dialogue system tests.")
    parser.add_argument("--skip-import", action="store_true", help="do not import the project first")
    parser.add_argument("--regression", action="store_true", help="also run the other headless test suites")
    arguments = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
    if not godot:
        raise SystemExit("Set GODOT_BIN to the Godot executable, or put godot/godot4 on PATH.")
    if not arguments.skip_import:
        import_project(godot, project)
    suites = [DIALOGUE_SUITE] + (list(REGRESSION_SUITES) if arguments.regression else [])
    for label, script in suites:
        run_suite(godot, project, label, script)


def import_project(godot: str, project: Path) -> None:
    started = time.monotonic()
    result = subprocess.run([godot, "--headless", "--path", str(project), "--import"],
                            capture_output=True, text=True, timeout=600)
    output = result.stdout + result.stderr
    problems = fatal_lines(output)
    if result.returncode or problems:
        print(output)
        raise RuntimeError("Importing the project failed")
    print(f"import: OK ({time.monotonic() - started:.1f}s)")


def run_suite(godot: str, project: Path, label: str, script: str) -> None:
    started = time.monotonic()
    result = subprocess.run([godot, "--headless", "--path", str(project), "--script", script],
                            capture_output=True, text=True, timeout=300)
    output = result.stdout + result.stderr
    problems = fatal_lines(output)
    summary = next((line for line in output.splitlines() if line.startswith(label + ":")), "")
    if result.returncode or problems or f"{label}: PASS" not in output:
        print(output)
        raise RuntimeError(f"{label} failed")
    warnings = [line for line in output.splitlines() if line.startswith("WARNING:")]
    note = f"  ({len(warnings)} warning(s))" if warnings else ""
    print(f"{summary}  [{time.monotonic() - started:.1f}s]{note}")
    for line in warnings:
        print("  " + line)


def fatal_lines(output: str) -> list[str]:
    return [line for line in output.splitlines() if any(marker in line for marker in FATAL_MARKERS)]


if __name__ == "__main__":
    main()
