"""Run Room C environment invariants; --render captures both production timelines."""
from pathlib import Path
import argparse
import os
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    godot = os.environ.get("GODOT_BIN", str(Path.home() / "OneDrive/Desktop/Godot_v4.7.2-stable_win64.exe"))
    command = [godot, "--path", str(root)]
    if args.render:
        command += ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--resolution", "1600x900"]
    else:
        command += ["--headless"]
    command += ["--script", "res://tests/level3_environment.gd"]
    if args.render:
        command += ["--", "--render-review"]
    result = subprocess.run(command, capture_output=True, text=True, timeout=120,
                            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
    output = result.stdout + result.stderr
    print(output)
    return result.returncode or int("LEVEL3 ENVIRONMENT: PASS" not in output or "ERROR:" in output)


if __name__ == "__main__":
    sys.exit(main())
