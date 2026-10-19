#!/usr/bin/env python3
"""Exercise LAN join, game spawning, host authority, and reconnects on loopback.

Run from any directory: python3 tests/run_lan_smoke.py
Requires Godot on PATH. This does not replace two-computer Wi-Fi testing.
"""

from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time


def main() -> None:
    project = Path(__file__).resolve().parents[1]
    godot = shutil.which("godot") or shutil.which("godot4")
    if not godot:
        raise SystemExit("Put godot or godot4 on PATH before running this check.")
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    processes = []
    with tempfile.TemporaryDirectory(prefix="past-future-lan-") as temp:
        output_paths = {}

        def start(role):
            output_paths[role] = Path(temp) / f"{role}.txt"
            with output_paths[role].open("w") as output:
                process = subprocess.Popen(
                    [godot, "--headless", "--path", str(project),
                     "--script", "res://tests/lan_peer.gd",
                     "--log-file", str(Path(temp) / f"{role}.log"),
                     "--", role, str(port)],
                    stdout=output, stderr=subprocess.STDOUT,
                )
            processes.append(process)
            return process

        try:
            host = start("host")
            deadline = time.monotonic() + 8
            while "HOST_LISTENING" not in output_paths["host"].read_text():
                if host.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError("Host failed to start")
                time.sleep(0.05)
            busy = start("busy")
            if busy.wait(timeout=8) != 0:
                raise RuntimeError("Occupied port check failed")
            client = start("client")
            client_result = client.wait(timeout=25)
            host_result = host.wait(timeout=20)
            if client_result or host_result:
                raise RuntimeError("LAN peer checks failed")
            for role in ["busy", "host", "client"]:
                output = output_paths[role].read_text()
                if "SCRIPT ERROR:" in output or f"LAN {role}: PASS" not in output:
                    raise RuntimeError(f"{role} did not finish its checks cleanly")
                print(f"{role}: PASS")
            print("LAN smoke check passed. Test on two Wi-Fi computers before release.")
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
