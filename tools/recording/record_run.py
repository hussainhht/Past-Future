"""Orchestrates one full recorded playthrough: loopback audio + screen capture + two game instances.

usage: python record_run.py [--no-record] [extra ap args...]
Outputs (docs/internal/gameplay_recording/raw/): screen.mp4 (1920x540 capture of both windows), audio.wav, timeline.json
"""
import subprocess, sys, time, os, json, signal, pathlib

ROOT = pathlib.Path(r"C:\Users\hanwd\OneDrive\Desktop\past-future")
GODOT = r"C:\Users\hanwd\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe"
FFMPEG = r"C:\ffmpeg\bin\ffmpeg.exe"
RAW = ROOT / "docs" / "internal" / "gameplay_recording" / "raw"
LOGS = ROOT / "docs" / "internal" / "gameplay_recording" / "logs"
RAW.mkdir(parents=True, exist_ok=True)
LOGS.mkdir(parents=True, exist_ok=True)

args = sys.argv[1:]
record = "--no-record" not in args
args = [a for a in args if a != "--no-record"]

subprocess.run(["taskkill", "/F", "/IM", "Godot_v4.7.2-stable_win64.exe"], capture_output=True)
time.sleep(2)
for f in LOGS.glob("*"):
    try:
        f.unlink()
    except OSError:
        pass

timeline = {}
procs = []
stopfile = LOGS / "stop_audio"
if record:
    aud = subprocess.Popen([sys.executable, str(ROOT / "tools/recording/audio_rec.py"), str(RAW / "audio.wav"), str(stopfile)],
                           stdout=subprocess.PIPE, text=True)
    info = json.loads(aud.stdout.readline())
    timeline["audio_start_wall"] = info["start_wall"]
    time.sleep(1.0)
    timeline["ffmpeg_launch_wall"] = time.time()
    ff = subprocess.Popen([FFMPEG, "-y", "-hide_banner", "-loglevel", "warning", "-f", "gdigrab", "-framerate", "30", "-draw_mouse", "0",
                           "-offset_x", "0", "-offset_y", "0", "-video_size", "1920x540", "-use_wallclock_as_timestamps", "1", "-i", "desktop",
                           "-c:v", "libx264", "-preset", "veryfast", "-crf", "17", "-pix_fmt", "yuv420p", "-vsync", "cfr", "-r", "30",
                           str(RAW / "screen.mp4")], stdin=subprocess.PIPE, stderr=open(LOGS / "ffmpeg.err", "w"))
    time.sleep(2.0)

common = [GODOT, "--path", str(ROOT), "--resolution", "960x540", "--borderless", "--always-on-top"]
user = ["--", "--ap-script=playthrough", "--ap-quit_when_done=1"] + args
timeline["host_launch_wall"] = time.time()
host = subprocess.Popen(common + ["--position", "0,0"] + user + ["--ap-role=host"], stdout=open(LOGS / "host.out", "w"), stderr=open(LOGS / "host.err", "w"))
time.sleep(1.0)
timeline["client_launch_wall"] = time.time()
client = subprocess.Popen(common + ["--position", "960,0"] + user + ["--ap-role=client"], stdout=open(LOGS / "client.out", "w"), stderr=open(LOGS / "client.err", "w"))

deadline = time.time() + 3000
while time.time() < deadline and (host.poll() is None or client.poll() is None):
    time.sleep(2)
timeline["games_exit_wall"] = time.time()
time.sleep(1.5)
for p in (host, client):
    if p.poll() is None:
        p.kill()
if record:
    try:
        ff.stdin.write(b"q")
        ff.stdin.flush()
    except Exception:
        pass
    try:
        ff.wait(timeout=30)
    except subprocess.TimeoutExpired:
        ff.kill()
    stopfile.write_text("stop")
    out, _ = aud.communicate(timeout=30)
    timeline["audio_end"] = out.strip()
    timeline["ffmpeg_stop_wall"] = time.time()
(RAW / "timeline.json").write_text(json.dumps(timeline, indent=1))
print(json.dumps(timeline, indent=1))
