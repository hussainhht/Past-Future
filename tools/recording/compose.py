"""Compose the final 1920x1080 MP4 from the raw screen capture (both game windows side by side) and the
loopback audio. Captions are generated from the real timestamps in the host automation log."""
import subprocess, pathlib, re, sys

ROOT = pathlib.Path(r"C:\Users\hanwd\OneDrive\Desktop\past-future")
RAW = ROOT / "docs" / "internal" / "gameplay_recording" / "raw"
OUT = ROOT / "docs" / "internal" / "gameplay_recording" / "THE_OTHER_ME_FULL_GAMEPLAY.mp4"
FF = r"C:\ffmpeg\bin\ffmpeg.exe"

TRIM = 4.3          # first video second kept (both game windows are already on screen)
AUDIO_LEAD = 1.31   # audio recorder started this long before the screen capture
HOST_TO_VIDEO = 6.4  # host log time 0 == this many seconds into screen.mp4 (measured: main menu first visible)
END = float(sys.argv[1]) if len(sys.argv) > 1 else 440.0

log = (ROOT / "docs/internal/gameplay_recording/logs/host.log").read_text(encoding="utf-8").splitlines()


def t_of(pattern):
    for line in log:
        if re.search(pattern, line):
            return float(re.match(r"\[\s*([\d.]+)", line).group(1))
    raise SystemExit("milestone not found: " + pattern)


m = {
    "l1": t_of(r"=== LEVEL 1"), "radios": t_of(r"screenshot 13_radios"), "link": t_of(r"RADIO LINK ESTABLISHED"),
    "l2": t_of(r"=== LEVEL 2"), "cell": t_of(r"EMERGENCY CELL CHARGED"), "archive": t_of(r"ARCHIVE REPAIRED"),
    "rec": t_of(r"RECORDING:"), "open": t_of(r"CORE ENTRANCE OPEN"), "solved": t_of(r"LEVEL 2 PUZZLE SOLVED"),
    "l3": t_of(r"=== LEVEL 3"), "armed": t_of(r"REACTOR ARMED"), "end": t_of(r"ENDING REACHED"),
}
m["l2done"] = m["l3"]
caps = [
    (0.0, m["l1"], "MAIN MENU  -  Student hosts, Professor joins over ENet (127.0.0.1, UDP 7000)"),
    (m["l1"], m["radios"], "LEVEL 1  -  SIGNAL LABORATORY  -  explore, read the research notes, collect both radios"),
    (m["radios"], m["link"], "LEVEL 1  -  Student turns the dials to 67 MHz / 70 percent  -  Professor watches the live receiver"),
    (m["link"], m["l2"], "LEVEL 1  -  RADIO LINK ESTABLISHED  -  radio dialogue, then both players leave through the security door"),
    (m["l2"], m["cell"], "LEVEL 2  -  MAINTENANCE CORRIDOR  -  Student isolates SERVICE, Professor charges the emergency cell"),
    (m["cell"], m["archive"], "LEVEL 2  -  Student stores cases underground, Professor recovers parts and repairs the archive"),
    (m["archive"], m["rec"], "LEVEL 2  -  archive record read  -  both bypass ends repaired  -  recording exported"),
    (m["rec"], m["solved"], "LEVEL 2  -  access code 3142 entered  -  manual release turned  -  anchor latched"),
    (m["solved"], m["l3"], "LEVEL 2 COMPLETE  -  chapter summary  -  host continues with the pause menu (Skip to Level 3)"),
    (m["l3"], m["armed"], "LEVEL 3  -  THE FINAL FRACTURE  -  both players read the evidence before arming the reactor"),
    (m["armed"], m["end"], "LEVEL 3  -  150-second reactor challenge  -  coils, receiver, anchor, origin core, phase switches"),
    (m["end"], 9999.0, "ENDING  -  THE LAST GOODBYE (TRUST)  -  Student: GROUND THE CORE  /  Professor: RELEASE THE ECHO"),
]

shift = HOST_TO_VIDEO - TRIM
dur = END - TRIM
filters = ["color=c=0x0a0e13:s=1920x1080:r=30[bg]", "[0:v]format=yuv420p[v]", "[bg][v]overlay=0:270:shortest=1[base]"]
font = "C\\:/Windows/Fonts/arialbd.ttf"
fontr = "C\\:/Windows/Fonts/arial.ttf"
last = "base"


def dt(src, dst, textfile, x, y, size, color, extra="", font_=font):
    return f"[{src}]drawtext=fontfile='{font_}':textfile={textfile}:x={x}:y={y}:fontsize={size}:fontcolor={color}{extra}[{dst}]"


(RAW / "t_title.txt").write_text("THE OTHER ME  -  FULL GAMEPLAY PLAYTHROUGH  (main menu to ending, two players)", encoding="utf-8")
(RAW / "t_past.txt").write_text("PAST  -  THE STUDENT  -  host / player 1", encoding="utf-8")
(RAW / "t_future.txt").write_text("FUTURE  -  THE PROFESSOR  -  client / player 2", encoding="utf-8")
(RAW / "t_foot.txt").write_text("Real gameplay: two Godot 4.7.2 instances on one PC, networked over ENet. Input is injected as genuine keyboard and mouse events by a QA harness.", encoding="utf-8")
filters.append(dt(last, "a1", "t_title.txt", "(w-text_w)/2", 70, 40, "0xe8e2c8"))
filters.append(dt("a1", "a2", "t_past.txt", "(960-text_w)/2", 215, 30, "0xe4bf7f"))
filters.append(dt("a2", "a3", "t_future.txt", "960+(960-text_w)/2", 215, 30, "0x89ccd4"))
filters.append(dt("a3", "a4", "t_foot.txt", "(w-text_w)/2", 1010, 22, "0x8a959c", font_=fontr))
last = "a4"
for i, (a, b, text) in enumerate(caps):
    fn = f"t_cap{i}.txt"
    (RAW / fn).write_text(text, encoding="utf-8")
    s, e = max(0.0, a + shift), b + shift
    nxt = f"c{i}"
    filters.append(dt(last, nxt, fn, "(w-text_w)/2", 820, 32, "0xffffff", f":enable='between(t,{s:.2f},{e:.2f})'"))
    last = nxt
filters.append(f"[{last}]fps=30,format=yuv420p[vout]")
filters.append(f"[1:a]aresample=48000,loudnorm=I=-19:TP=-2:LRA=9,aformat=sample_rates=48000:channel_layouts=stereo[aout]")

cmd = [FF, "-y", "-hide_banner", "-loglevel", "warning", "-stats",
       "-ss", f"{TRIM}", "-t", f"{dur:.2f}", "-i", "screen.mp4",
       "-ss", f"{TRIM + AUDIO_LEAD:.2f}", "-t", f"{dur:.2f}", "-i", "audio.wav",
       "-filter_complex", ";".join(filters), "-map", "[vout]", "-map", "[aout]",
       "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
       "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "-t", f"{dur:.2f}", str(OUT)]
print("milestones:", m)
subprocess.run(cmd, cwd=str(RAW), check=True)
print("wrote", OUT)
