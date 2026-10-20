"""Godot rules, real-scene integration, and two real ENet radio peers.

Set GODOT_BIN or put godot on PATH. Fails on engine/script errors, bad exit
codes, missing success markers, and timeouts. Does not edit project settings.
"""
from pathlib import Path
import os
import shutil
import socket
import subprocess
import tempfile
import time


PROJECT = Path(__file__).resolve().parents[1]


def verify(output: str, returncode: int, marker: str) -> None:
    if returncode or "ERROR:" in output or "leaked at exit" in output or marker not in output:
        raise RuntimeError(f"Failed: {marker}\n{output}")
    print(next(line for line in output.splitlines() if line.startswith(marker)))


def main() -> None:
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
    if not godot:
        raise SystemExit("Set GODOT_BIN to your Godot console executable.")
    for script, marker in [("frequency_puzzle.gd", "FREQUENCY RULES: PASS"),
                           ("frequency_puzzle_integration.gd", "FREQUENCY INTEGRATION: PASS")]:
        result = subprocess.run([godot, "--headless", "--path", str(PROJECT),
                                 "--script", f"res://tests/{script}"],
                                capture_output=True, text=True, timeout=60)
        verify(result.stdout + result.stderr, result.returncode, marker)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    peers = []
    with tempfile.TemporaryDirectory(prefix="temporal-radio-") as directory:
        logs = {}

        def start(role: str) -> subprocess.Popen:
            logs[role] = Path(directory) / f"{role}.txt"
            with logs[role].open("w") as output:
                peer = subprocess.Popen([godot, "--headless", "--path", str(PROJECT),
                                         "--script", "res://tests/frequency_peer.gd",
                                         "--log-file", str(Path(directory) / f"{role}.log"),
                                         "--", role, str(port)], stdout=output, stderr=subprocess.STDOUT)
            peers.append(peer)
            return peer

        try:
            host = start("host")
            deadline = time.monotonic() + 15
            while "RADIO_HOST_LISTENING" not in logs["host"].read_text():
                if host.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError("Radio host failed to start")
                time.sleep(0.05)
            client = start("client")
            client_result = client.wait(timeout=60)
            host_result = host.wait(timeout=30)
            verify(logs["host"].read_text(), host_result, "FREQUENCY host: PASS")
            verify(logs["client"].read_text(), client_result, "FREQUENCY client: PASS")
        except Exception:
            for role, path in logs.items():
                print(f"{role}:\n{path.read_text()}")
            raise
        finally:
            for peer in peers:
                if peer.poll() is None:
                    peer.terminate()
                    try:
                        peer.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        peer.kill()
                        peer.wait()


if __name__ == "__main__":
    main()
