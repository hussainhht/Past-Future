"""Focused Room C suite. --peers-only skips the deterministic scene checks.

Set GODOT_BIN, then python tests/run_level3_tests.py. No assets are downloaded.
"""
from pathlib import Path
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time


def main():
    project = Path(__file__).resolve().parents[1]
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")
    if not godot:
        raise SystemExit("Set GODOT_BIN to your Godot 4.7.2 console executable.")
    common = [godot, "--headless", "--path", str(project)]
    flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
    if "--peers-only" not in sys.argv:
        result = subprocess.run(common + ["--script", "res://tests/level3_core.gd"],
                                capture_output=True, text=True, timeout=120, creationflags=flags)
        print(result.stdout)
        if result.returncode or "SCRIPT ERROR:" in result.stdout + result.stderr or "LEVEL3 CORE: PASS" not in result.stdout:
            raise SystemExit(result.stderr or "Core checks failed")
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    with tempfile.TemporaryDirectory(prefix="past-future-core-") as temp:
        running = []
        paths = {}
        try:
            for role in ("host", "client"):
                path = Path(temp) / (role + ".log")
                paths[role] = path
                with path.open("w", encoding="utf-8") as output:
                    process = subprocess.Popen(common + ["--script", "res://tests/level3_peer.gd",
                        "--", role, str(port)], stdout=output, stderr=subprocess.STDOUT, creationflags=flags)
                running.append(process)
                if role == "host":
                    deadline = time.monotonic() + 12
                    while "CORE_HOST_LISTENING" not in path.read_text(encoding="utf-8"):
                        if process.poll() is not None or time.monotonic() > deadline:
                            raise RuntimeError("Host did not launch")
                        time.sleep(0.05)
            results = [process.wait(timeout=160) for process in running]
            logs = {role: path.read_text(encoding="utf-8") for role, path in paths.items()}
            for role, log in logs.items():
                if "SCRIPT ERROR:" in log or "LEVEL3 PEER FAILED:" in log or f"LEVEL3 {role}: PASS" not in log:
                    raise RuntimeError(role + " failed")
            if any(results):
                raise RuntimeError("A peer returned an error")
            for expected in ("trust", "student_override", "professor_override", "paradox"):
                revisions = []
                for role in ("host", "client"):
                    line = next(line for line in logs[role].splitlines() if line.startswith(f"CORE_CASE {role} {expected} "))
                    revisions.append(line.rsplit("=", 1)[1])
                if revisions[0] != revisions[1]:
                    raise RuntimeError("Peer revisions differ for " + expected)
            for log in logs.values():
                print("\n".join(line for line in log.splitlines() if line.startswith(("CORE_CASE", "LEVEL3"))))
            print("LEVEL3 ENet: PASS (all four endings agree; replay, role security and disconnect)")
        except Exception:
            for role, path in paths.items():
                print(role + ":\n" + path.read_text(encoding="utf-8"))
            raise
        finally:
            for process in running:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()


if __name__ == "__main__":
    main()
