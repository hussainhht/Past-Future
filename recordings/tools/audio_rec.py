"""WASAPI loopback recorder for the playthrough (captures what the games actually play).

usage: python audio_rec.py out.wav stopfile
A silent output stream is kept open so the loopback endpoint keeps delivering frames during silence,
and wall-clock gaps are padded with zeros so the WAV stays aligned with the screen recording.
"""
import sys, time, wave, os, json
import pyaudiowpatch as pa

out, stopfile = sys.argv[1], sys.argv[2]
p = pa.PyAudio()
lb = p.get_default_wasapi_loopback()
rate = int(lb["defaultSampleRate"])
ch = lb["maxInputChannels"]
chunk = 1024

# keep the render endpoint alive with silence
silent = p.open(format=pa.paInt16, channels=2, rate=rate, output=True,
                output_device_index=lb["index"] - 1 if False else None)  # default output device
stream = p.open(format=pa.paInt16, channels=ch, rate=rate, input=True,
                frames_per_buffer=chunk, input_device_index=lb["index"])

w = wave.open(out, "wb")
w.setnchannels(ch)
w.setsampwidth(2)
w.setframerate(rate)
t0 = time.perf_counter()
start_wall = time.time()
frames_written = 0
silence = b"\x00" * (chunk * 2 * 2)
print(json.dumps({"start_wall": start_wall, "rate": rate, "channels": ch}), flush=True)
try:
    while not os.path.exists(stopfile):
        silent.write(silence, exception_on_underflow=False)
        avail = stream.get_read_available()
        if avail > 0:
            data = stream.read(avail, exception_on_overflow=False)
            w.writeframes(data)
            frames_written += len(data) // (2 * ch)
        # pad if the stream fell behind wall clock by more than 100 ms
        expected = int((time.perf_counter() - t0) * rate)
        if expected - frames_written > rate // 10:
            pad = expected - frames_written
            w.writeframes(b"\x00" * (pad * 2 * ch))
            frames_written += pad
        time.sleep(0.005)
finally:
    w.close()
    stream.stop_stream(); stream.close(); silent.close(); p.terminate()
    print(json.dumps({"end_wall": time.time(), "frames": frames_written, "seconds": frames_written / rate}), flush=True)
