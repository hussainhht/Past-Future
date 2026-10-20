#!/usr/bin/env python3
"""Run the level-flow tests: offline checks, then two real ENet peers on loopback.

Run from any directory: python tests/run_game_flow_tests.py
Set GODOT_BIN to the Godot executable (or put godot/godot4 on PATH).
Set FLOW_TEST_VERBOSE=1 to print every log even when everything passes.
Use --offline-only or --peers-only to run half of it.

Godot scripts print PASS even when the engine logs script errors, so this runner also fails on
"SCRIPT ERROR:", on any failed check ("FAILED"), on leaked objects, and on engine "ERROR:" lines that
the deliberate failure tests do not explain. The expected ones are the forged RPCs a client sends
to the host and the scenes that are broken on purpose.
"""

from pathlib import Path
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time

PROJECT = Path(__file__).resolve().parents[1]

# Engine errors that the failure tests provoke on purpose.
EXPECTED_ERRORS = [
    # A client forging begin / commit / abort: the engine refuses them because only the host is the authority.
    r"RPC '_rpc_(begin|commit|abort)' is not allowed on node /root/GameFlowManager",
    # The scenes written broken on purpose (one per peer) fail to parse.
    r"Parse Error: Parse error\. \[Resource file res://\.game_flow_test/broken_(host|client|load_room)\.tscn",
    r"Failed loading resource: res://\.game_flow_test/broken_(host|client|load_room)\.tscn",
]


def godot_binary() -> str:
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
    if not godot:
        raise SystemExit("Set GODOT_BIN to the Godot executable, or put godot/godot4 on PATH.")
    return godot


def problems(output: str) -> list[str]:
    found = []
    lines = output.splitlines()
    for index, line in enumerate(lines):
        if "SCRIPT ERROR:" in line or "FAILED" in line and "ERROR:" in line:
            found.append(line)
        elif line.startswith("ERROR:") and not any(re.search(pattern, line) for pattern in EXPECTED_ERRORS):
            # The detail of a multi-line engine error sits on the following lines.
            detail = " ".join(lines[index:index + 3])
            if not any(re.search(pattern, detail) for pattern in EXPECTED_ERRORS):
                found.append(line)
        elif "leaked at exit" in line or "resources still in use at exit" in line:
            found.append(line)
    return found


def verify(output: str, returncode: int, marker: str, label: str) -> None:
    bad = problems(output)
    if returncode or bad or marker not in output:
        raise RuntimeError(f"{label} failed (exit {returncode}); marker '{marker}' {'found' if marker in output else 'missing'}\n"
                           + "\n".join(bad[:12]) + f"\n--- log ---\n{output}")
    print(next(line for line in output.splitlines() if marker in line), flush=True)
    if os.environ.get("FLOW_TEST_VERBOSE"):
        print(f"--- {label} log ---\n{output}")


def run_offline(godot: str) -> None:
    result = subprocess.run([godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/game_flow_system.gd"],
                            capture_output=True, text=True, timeout=180)
    verify(result.stdout + result.stderr, result.returncode, "GAME FLOW SYSTEM: PASS", "offline suite")


def run_peers(godot: str, scenario: str) -> None:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    processes = []
    with tempfile.TemporaryDirectory(prefix="past-future-flow-") as directory:
        outputs = {}

        def start(role: str) -> subprocess.Popen:
            outputs[role] = Path(directory) / f"{role}.txt"
            with outputs[role].open("w") as output:
                process = subprocess.Popen(
                    [godot, "--headless", "--path", str(PROJECT), "--script", "res://tests/game_flow_peer.gd",
                     "--log-file", str(Path(directory) / f"{role}.log"), "--", role, str(port), scenario],
                    stdout=output, stderr=subprocess.STDOUT)
            processes.append(process)
            return process

        try:
            host = start("host")
            deadline = time.monotonic() + 20
            while "FLOW_HOST_LISTENING" not in outputs["host"].read_text():
                if host.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError("The host failed to start")
                time.sleep(0.05)
            client = start("client")
            client_result = client.wait(timeout=150)
            host_result = host.wait(timeout=60)
            for role, code in (("host", host_result), ("client", client_result)):
                verify(outputs[role].read_text(), code, f"FLOW {role} {scenario}: PASS", f"{scenario} {role}")
        except Exception:
            for role, path in outputs.items():
                print(f"--- {role} ({scenario}) ---\n{path.read_text()}", flush=True)
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
    if "--peers-only" not in sys.argv:
        run_offline(godot)
    if "--offline-only" not in sys.argv:
        run_peers(godot, "full")
        run_peers(godot, "host_leaves")
    print("Level-flow tests passed. Rendered checks: tests/run_game_flow_render.py", flush=True)


if __name__ == "__main__":
    main()
