#!/usr/bin/env python3
"""Objective tracker tests: rules and playthrough (headless), real rooms and Mission Log (headless),
then two real ENet peers on loopback (Student host, Professor guest).

Run from any directory: python tests/run_objective_tests.py
Set GODOT_BIN to the Godot executable (or put godot/godot4 on PATH).

The Godot scripts print PASS even when the engine logs script errors, so this runner also fails on
"SCRIPT ERROR:" and on any "FAILED:" line. Leak notices at exit that name audio streams come from
the rooms' ambience playing while the headless engine quits; they are not objective-system objects.
"""

from pathlib import Path
import os
import shutil
import socket
import subprocess
import tempfile
import time


def godot_binary() -> str:
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
    if not godot:
        raise SystemExit("Set GODOT_BIN to the Godot executable, or put godot/godot4 on PATH.")
    return godot


def run_script(godot: str, project: Path, script: str, marker: str, timeout: int) -> None:
    result = subprocess.run([godot, "--headless", "--path", str(project), "--script", script],
                            capture_output=True, text=True, timeout=timeout)
    output = result.stdout + result.stderr
    if result.returncode or "SCRIPT ERROR:" in output or "FAILED:" in output or marker not in output:
        print(output)
        raise RuntimeError(f"{script} failed")
    print(next(line for line in output.splitlines() if line.startswith(marker)), flush=True)


def run_peers(godot: str, project: Path) -> None:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    processes = []
    with tempfile.TemporaryDirectory(prefix="past-future-objectives-") as temp:
        outputs = {}

        def start(role: str) -> subprocess.Popen:
            outputs[role] = Path(temp) / f"{role}.txt"
            with outputs[role].open("w") as output:
                process = subprocess.Popen(
                    [godot, "--headless", "--path", str(project), "--script", "res://tests/objective_peer.gd",
                     "--log-file", str(Path(temp) / f"{role}.log"), "--", role, str(port)],
                    stdout=output, stderr=subprocess.STDOUT)
            processes.append(process)
            return process

        try:
            host = start("host")
            deadline = time.monotonic() + 20
            while "HOST_LISTENING" not in outputs["host"].read_text():
                if host.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError("Host failed to start")
                time.sleep(0.05)
            client = start("client")
            client_result = client.wait(timeout=120)
            host_result = host.wait(timeout=40)
            for role in ["host", "client"]:
                text = outputs[role].read_text()
                if "SCRIPT ERROR:" in text or "FAILED:" in text or f"OBJECTIVES {role}: PASS" not in text:
                    raise RuntimeError(f"{role} did not finish its checks cleanly")
                print(next(line for line in text.splitlines() if line.startswith(f"OBJECTIVES {role}:")), flush=True)
            if client_result or host_result:
                raise RuntimeError("Objective peer checks failed")
        except Exception:
            for role, path in outputs.items():
                print(f"--- {role} ---\n{path.read_text()}")
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
    project = Path(__file__).resolve().parents[1]
    godot = godot_binary()
    run_script(godot, project, "res://tests/objective_system.gd", "OBJECTIVE SYSTEM: PASS", 180)
    run_script(godot, project, "res://tests/objective_ui.gd", "OBJECTIVE UI: PASS", 240)
    run_peers(godot, project)


if __name__ == "__main__":
    main()
