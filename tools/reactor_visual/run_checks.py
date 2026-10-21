"""Run this module's checks or rendered review without touching shared test files."""
from pathlib import Path
import argparse
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--import-assets", action="store_true")
    parser.add_argument("--room", action="store_true", help="render current room context without saving changes")
    parser.add_argument("--profile", action="store_true", help="profile standalone Future overload in Compatibility")
    args = parser.parse_args()
    godot = os.environ.get("GODOT_BIN", str(Path.home()/"OneDrive/Desktop/Godot_v4.7.2-stable_win64.exe"))
    command = [godot, "--path", str(ROOT)]
    if not args.render and not args.room and not args.profile:
        command += ["--headless"]
    else:
        # Exercise the actual Compatibility renderer explicitly.
        command += ["--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3", "--resolution", "1600x900", "--position", "40,40"]
    if args.import_assets:
        command += ["--editor", "--import"]
        label = "import"
    else:
        label = "profile" if args.profile else "room" if args.room else "render" if args.render else "checks"
        script = {"profile": "profile_reactor.gd", "room": "room_review.gd", "render": "render_review.gd", "checks": "verify_reactor.gd"}[label]
        command += ["--script", "res://tools/reactor_visual/" + script]
    log_path = ROOT / "tools/reactor_visual" / (label+".log")
    command += ["--log-file", str(log_path)]
    result = subprocess.run(command, capture_output=True, text=True, timeout=160,
                            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
    log = log_path.read_text(encoding="utf-8") if log_path.exists() else ""
    print(log or result.stdout or result.stderr)
    bad = any(marker in log for marker in ["ERROR:", "Parse Error", ": FAIL"])
    expected = {"checks": "REACTOR VISUAL: PASS", "render": "REACTOR REVIEW: PASS", "room": "REACTOR ROOM: PASS", "profile": "REACTOR PROFILE: PASS"}
    if not args.import_assets and expected[label] not in log:
        bad = True
    sys.exit(result.returncode or int(bad))


if __name__ == "__main__":
    main()
