"""Focused smoke: two real ENet peers, two complete catastrophe/restart cycles."""
from pathlib import Path
import os
import shutil
import socket
import subprocess
import tempfile
import time


def main():
    project = Path(__file__).resolve().parents[1]
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
    if not godot:
        raise SystemExit("Set GODOT_BIN to Godot 4.7.2.")
    common = [godot, "--headless", "--path", str(project), "--script", "res://tests/reactor_meltdown.gd", "--"]
    flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port = str(probe.getsockname()[1])
    with tempfile.TemporaryDirectory(prefix="reactor-meltdown-") as temporary:
        processes, logs = [], {}
        try:
            for role in ("host", "client"):
                path = Path(temporary) / (role + ".log")
                logs[role] = path
                with path.open("w", encoding="utf-8") as stream:
                    processes.append(subprocess.Popen(common + [role, port], stdout=stream, stderr=subprocess.STDOUT, creationflags=flags))
                if role == "host":
                    deadline = time.monotonic() + 12
                    while "MELTDOWN_HOST_LISTENING" not in path.read_text(encoding="utf-8"):
                        if processes[0].poll() is not None or time.monotonic() > deadline:
                            raise RuntimeError("Host failed to start")
                        time.sleep(0.05)
            results = [process.wait(timeout=60) for process in processes]
            outputs = {role: path.read_text(encoding="utf-8") for role, path in logs.items()}
            for role, output in outputs.items():
                print(output)
                if "SCRIPT ERROR:" in output or "ERROR:" in output or f"MELTDOWN {role}: PASS" not in output:
                    raise RuntimeError(role + " failed")
            if any(results):
                raise RuntimeError("A peer failed")
        except Exception:
            for role, path in logs.items():
                print(role + ":\n" + path.read_text(encoding="utf-8"))
            raise
        finally:
            for process in processes:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=5)


if __name__ == "__main__":
    main()
