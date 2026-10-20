#!/usr/bin/env python3
"""Rendered checks for the level-flow system: real frames, real fades, real two-process screens.

Needs a display. On a machine without one the runner uses xvfb-run (software GL), so Xvfb must be
installed. Set GODOT_BIN to the Godot executable. Screenshots go to --out (default: a temp folder
that is printed at the end).

    python tests/run_game_flow_render.py [--out DIR]

The solo run reads frames back and asserts on them: the fade darkens the room, the black screen
carries the loading text, the readiness panel and notices appear, and a stuck load rolls back to a
visible room. The two-process run captures what each player sees while waiting for the other, and
the Past and Future versions of Room B.
"""

from pathlib import Path
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time

PROJECT = Path(__file__).resolve().parents[1]
RENDER_ARGS = ["--rendering-driver", "opengl3", "--audio-driver", "Dummy"]


def godot_binary() -> str:
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
    if not godot:
        raise SystemExit("Set GODOT_BIN to the Godot executable, or put godot/godot4 on PATH.")
    return godot


def display_command() -> list[str]:
    if os.environ.get("DISPLAY"):
        return []
    xvfb = shutil.which("xvfb-run")
    if not xvfb:
        raise SystemExit("No DISPLAY and no xvfb-run: a rendered test needs one of them.")
    return [xvfb, "-a", "-s", "-screen 0 1280x720x24"]


def clean(output: str) -> str:
    # ALSA/audio device noise from a machine without sound is not a failure.
    return "\n".join(line for line in output.splitlines() if "ALSA" not in line and "audio" not in line.lower())


def check_output(label: str, output: str, returncode: int, marker: str) -> None:
    text = clean(output)
    bad = [line for line in text.splitlines()
           if "SCRIPT ERROR:" in line or ("FAILED" in line and "ERROR:" in line) or "leaked at exit" in line]
    if returncode or bad or marker not in text:
        raise RuntimeError(f"{label} failed (exit {returncode})\n" + "\n".join(bad[:10]) + f"\n--- log ---\n{text}")
    print(next(line for line in text.splitlines() if marker in line), flush=True)


def run_solo(godot: str, out: Path) -> None:
    env = dict(os.environ, FLOW_RENDER_DIR=str(out))
    result = subprocess.run(display_command() + [godot, "--path", str(PROJECT), *RENDER_ARGS, "--script", "res://tests/game_flow_render.gd"],
                            capture_output=True, text=True, timeout=300, env=env)
    check_output("rendered solo run", result.stdout + result.stderr, result.returncode, "GAME FLOW RENDER: PASS")


def run_peers(godot: str, out: Path) -> None:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    env = dict(os.environ, FLOW_SHOTS_DIR=str(out))
    processes = []
    with tempfile.TemporaryDirectory(prefix="past-future-flow-render-") as directory:
        outputs = {}

        def start(role: str) -> subprocess.Popen:
            outputs[role] = Path(directory) / f"{role}.txt"
            with outputs[role].open("w") as handle:
                process = subprocess.Popen(
                    display_command() + [godot, "--path", str(PROJECT), *RENDER_ARGS, "--script", "res://tests/game_flow_peer.gd",
                                         "--log-file", str(Path(directory) / f"{role}.log"), "--", role, str(port), "full"],
                    stdout=handle, stderr=subprocess.STDOUT, env=env)
            processes.append(process)
            return process

        try:
            host = start("host")
            deadline = time.monotonic() + 40
            while "FLOW_HOST_LISTENING" not in outputs["host"].read_text():
                if host.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError("The rendered host failed to start")
                time.sleep(0.1)
            client = start("client")
            client_code = client.wait(timeout=240)
            host_code = host.wait(timeout=60)
            for role, code in (("host", host_code), ("client", client_code)):
                text = outputs[role].read_text()
                # The forged-RPC and broken-scene engine errors are expected here too (see run_game_flow_tests.py).
                filtered = "\n".join(line for line in text.splitlines()
                                     if "is not allowed on node /root/GameFlowManager" not in line and "broken_" not in line)
                check_output(f"rendered {role}", filtered, code, f"FLOW {role} full: PASS")
        except Exception:
            for role, path in outputs.items():
                print(f"--- {role} ---\n{clean(path.read_text())}", flush=True)
            raise
        finally:
            for process in processes:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()


def main() -> None:
    godot = godot_binary()
    out = Path(sys.argv[sys.argv.index("--out") + 1]) if "--out" in sys.argv else Path(tempfile.mkdtemp(prefix="past-future-flow-shots-"))
    out.mkdir(parents=True, exist_ok=True)
    run_solo(godot, out)
    run_peers(godot, out)
    print(f"Rendered checks passed. Screenshots: {out}", flush=True)
    for shot in sorted(out.glob("*.png")):
        print(f"  {shot.name}")


if __name__ == "__main__":
    main()
