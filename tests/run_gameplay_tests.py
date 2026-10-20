"""Strict real-menu solo and two-process integrated-gameplay verification.

Set GODOT_BIN to the Godot console executable. No sandbox is used by these tests.
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


def verify(output: str, returncode: int, marker: str) -> None:
    if returncode or "ERROR:" in output or "leaked at exit" in output or marker not in output:
        raise RuntimeError(f"Failed: {marker}\n{output}")
    print(next(line for line in output.splitlines() if line.startswith(marker)), flush=True)


def main() -> None:
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
    if not godot:
        raise SystemExit("Set GODOT_BIN to your Godot console executable.")
    if "--peers-only" not in sys.argv:
        result = subprocess.run([godot, "--headless", "--path", str(PROJECT), "--script",
                                 "res://tests/gameplay_integration.gd"],
                                capture_output=True, text=True, timeout=90)
        verify(result.stdout + result.stderr, result.returncode, "GAMEPLAY SOLO: PASS")
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    processes = []
    with tempfile.TemporaryDirectory(prefix="past-future-gameplay-") as directory:
        logs = {}

        def start(role: str) -> subprocess.Popen:
            logs[role] = Path(directory) / f"{role}.txt"
            with logs[role].open("w") as output:
                process = subprocess.Popen([godot, "--headless", "--path", str(PROJECT),
                                            "--script", "res://tests/gameplay_peer.gd",
                                            "--log-file", str(Path(directory) / f"{role}.log"),
                                            "--", role, str(port)],
                                           stdout=output, stderr=subprocess.STDOUT)
            processes.append(process)
            return process

        try:
            host = start("host")
            deadline = time.monotonic() + 15
            while "GAMEPLAY_HOST_LISTENING" not in logs["host"].read_text():
                if host.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError("Menu-hosted game failed to start")
                time.sleep(0.05)
            client = start("client")
            client_result = client.wait(timeout=75)
            host_result = host.wait(timeout=30)
            verify(logs["host"].read_text(), host_result, "GAMEPLAY host: PASS")
            verify(logs["client"].read_text(), client_result, "GAMEPLAY client: PASS")
        except Exception:
            for role, path in logs.items():
                print(f"{role}:\n{path.read_text()}", flush=True)
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
