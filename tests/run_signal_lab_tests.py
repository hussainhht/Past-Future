#!/usr/bin/env python3
"""Run the Signal Laboratory tests: the solo flow, then two real ENet peers on loopback.

Run from any directory: python tests/run_signal_lab_tests.py
Set GODOT_BIN to the Godot executable (or put godot/godot4 on PATH).
Set SIGNAL_LAB_TEST_VERBOSE=1 to print each peer's full log even when everything passes.

Like run_puzzle_tests.py, this fails on any "SCRIPT ERROR:" line, because the Godot scripts can
print PASS while the engine logs script errors.
"""

from pathlib import Path
import os
import shutil
import socket
import subprocess
import tempfile
import time


def main() -> None:
    project = Path(__file__).resolve().parents[1]
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
    if not godot:
        raise SystemExit("Set GODOT_BIN to the Godot executable, or put godot/godot4 on PATH.")
    run_solo_test(godot, project)
    run_peer_test(godot, project)


def run_solo_test(godot: str, project: Path) -> None:
    result = subprocess.run(
        [godot, "--headless", "--path", str(project), "--script", "res://tests/signal_lab.gd"],
        capture_output=True, text=True, timeout=180,
    )
    output = result.stdout + result.stderr
    if result.returncode or "SCRIPT ERROR:" in output or "SIGNAL LAB: PASS" not in output:
        print(output)
        raise RuntimeError("Solo Signal Laboratory test failed")
    print(next(line for line in output.splitlines() if line.startswith("SIGNAL LAB:")))


def run_peer_test(godot: str, project: Path) -> None:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    processes = []
    with tempfile.TemporaryDirectory(prefix="past-future-signal-lab-") as temp:
        output_paths = {}

        def start(role: str) -> subprocess.Popen:
            output_paths[role] = Path(temp) / f"{role}.txt"
            with output_paths[role].open("w") as output:
                process = subprocess.Popen(
                    [godot, "--headless", "--path", str(project),
                     "--script", "res://tests/signal_lab_peer.gd",
                     "--log-file", str(Path(temp) / f"{role}.log"),
                     "--", role, str(port)],
                    stdout=output, stderr=subprocess.STDOUT,
                )
            processes.append(process)
            return process

        try:
            host = start("host")
            deadline = time.monotonic() + 20
            while "HOST_LISTENING" not in output_paths["host"].read_text():
                if host.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError("Host failed to start")
                time.sleep(0.05)
            client = start("client")
            client_result = client.wait(timeout=120)
            host_result = host.wait(timeout=40)
            for role in ["host", "client"]:
                output = output_paths[role].read_text()
                if "SCRIPT ERROR:" in output or f"SIGNAL LAB {role}: PASS" not in output:
                    raise RuntimeError(f"{role} did not finish its checks cleanly")
                print(f"signal lab {role}: PASS")
                if os.environ.get("SIGNAL_LAB_TEST_VERBOSE"):
                    print(f"--- {role} log ---\n{output}")
            if client_result or host_result:
                raise RuntimeError("Signal Laboratory peer checks failed")
        except Exception:
            for role, path in output_paths.items():
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


if __name__ == "__main__":
    main()
