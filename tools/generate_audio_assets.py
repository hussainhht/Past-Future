#!/usr/bin/env python3
"""
Procedural Audio Asset Generator for Past-Future
Generates clean, restrained, high-quality 16-bit PCM WAV assets for game jam audio.
All assets are deterministically generated, 100% royalty-free and original.
"""

import os
import math
import struct
import wave
import random

SAMPLE_RATE = 44100

def write_wav(path: str, samples: list[float], sample_rate: int = SAMPLE_RATE, channels: int = 1):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # Clamp and normalize
    max_amp = max(abs(s) for s in samples) if samples else 1.0
    if max_amp < 1e-5:
        max_amp = 1.0
    
    with wave.open(path, "wb") as wav_file:
        wav_file.setnchannels(channels)
        wav_file.setsampwidth(2) # 16-bit
        wav_file.setframerate(sample_rate)
        
        raw_bytes = bytearray()
        for s in samples:
            val = max(-1.0, min(1.0, s))
            int_val = int(val * 32767.0)
            raw_bytes.extend(struct.pack("<h", int_val))
        wav_file.writeframes(raw_bytes)

def generate_noise(length: int, seed: int = 42) -> list[float]:
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(length)]

def lowpass_filter(samples: list[float], cutoff_hz: float, sample_rate: int = SAMPLE_RATE) -> list[float]:
    rc = 1.0 / (2.0 * math.pi * cutoff_hz)
    dt = 1.0 / sample_rate
    alpha = dt / (rc + dt)
    out = [0.0] * len(samples)
    curr = 0.0
    for i, s in enumerate(samples):
        curr += alpha * (s - curr)
        out[i] = curr
    return out

def highpass_filter(samples: list[float], cutoff_hz: float, sample_rate: int = SAMPLE_RATE) -> list[float]:
    rc = 1.0 / (2.0 * math.pi * cutoff_hz)
    dt = 1.0 / sample_rate
    alpha = rc / (rc + dt)
    out = [0.0] * len(samples)
    curr = 0.0
    prev_in = 0.0
    for i, s in enumerate(samples):
        curr = alpha * (curr + s - prev_in)
        prev_in = s
        out[i] = curr
    return out

def bandpass_filter(samples: list[float], low_hz: float, high_hz: float, sample_rate: int = SAMPLE_RATE) -> list[float]:
    hp = highpass_filter(samples, low_hz, sample_rate)
    return lowpass_filter(hp, high_hz, sample_rate)

# --- Footstep Generation ---
# Laboratory hard-floor footstep:
# Heel transient: fast pitch drop (120 -> 50 Hz) with 15ms exponential decay.
# Sole scuff: bandpassed noise (800 - 2400 Hz) with 35-50ms decay.
# Tile resonance: 450-700 Hz subtle resonance.
def generate_footstep(seed: int, pitch_scale: float = 1.0, duration: float = 0.18) -> list[float]:
    rng = random.Random(seed)
    num_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * num_samples
    
    # 1. Heel impact thump
    start_freq = 110.0 * pitch_scale
    end_freq = 45.0 * pitch_scale
    thump_decay = 0.025
    
    # 2. Sole slap / scuff noise
    raw_noise = [rng.uniform(-1.0, 1.0) for _ in range(num_samples)]
    scuff = bandpass_filter(raw_noise, 700.0 * pitch_scale, 2200.0 * pitch_scale)
    
    # 3. High transient tick (shoe edge against hard floor)
    tick = highpass_filter(raw_noise, 3000.0 * pitch_scale)
    
    # Tile resonance frequency
    res_freq = (520.0 + rng.uniform(-40, 40)) * pitch_scale
    
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        
        # Thump component
        freq = start_freq + (end_freq - start_freq) * min(1.0, t / 0.02)
        thump = math.sin(2.0 * math.pi * freq * t) * math.exp(-t / thump_decay)
        
        # Scuff envelope
        scuff_env = math.exp(-t / (0.045 + rng.uniform(-0.005, 0.005)))
        
        # High tick envelope (first 8 ms)
        tick_env = math.exp(-t / 0.006) if t < 0.02 else 0.0
        
        # Tile resonance ring
        ring = math.sin(2.0 * math.pi * res_freq * t) * math.exp(-t / 0.035) * 0.15
        
        val = (0.55 * thump) + (0.35 * scuff[i] * scuff_env) + (0.25 * tick[i] * tick_env) + ring
        samples[i] = val * 0.75
        
    return samples

# --- UI SFX Generation ---
def generate_ui_click() -> list[float]:
    duration = 0.028
    num_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * num_samples
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        # Crisp dual-tone micro transient
        f1 = 2200.0
        f2 = 4400.0
        env = math.exp(-t / 0.005)
        samples[i] = (0.6 * math.sin(2.0 * math.pi * f1 * t) + 0.4 * math.sin(2.0 * math.pi * f2 * t)) * env * 0.4
    return samples

def generate_ui_hover() -> list[float]:
    duration = 0.016
    num_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * num_samples
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        # Extremely soft subtle blip
        env = math.sin(math.pi * (t / duration)) ** 2
        samples[i] = math.sin(2.0 * math.pi * 1760.0 * t) * env * 0.18
    return samples

def generate_ui_confirm() -> list[float]:
    duration = 0.14
    num_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * num_samples
    t_split = 0.04
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        if t < t_split:
            f = 587.33 # D5
            env = math.exp(-t / 0.04)
            s = math.sin(2.0 * math.pi * f * t) + 0.2 * math.sin(2.0 * math.pi * f * 2.0 * t)
        else:
            t2 = t - t_split
            f = 880.00 # A5
            env = math.exp(-t2 / 0.07)
            s = math.sin(2.0 * math.pi * f * t2) + 0.25 * math.sin(2.0 * math.pi * f * 2.0 * t2)
        samples[i] = s * env * 0.35
    return samples

def generate_ui_back() -> list[float]:
    duration = 0.11
    num_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * num_samples
    t_split = 0.035
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        if t < t_split:
            f = 659.25 # E5
            env = math.exp(-t / 0.035)
            s = math.sin(2.0 * math.pi * f * t)
        else:
            t2 = t - t_split
            f = 440.00 # A4
            env = math.exp(-t2 / 0.06)
            s = math.sin(2.0 * math.pi * f * t2)
        samples[i] = s * env * 0.32
    return samples

# --- Interaction SFX Generation ---
def generate_interaction_click() -> list[float]:
    duration = 0.045
    num_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * num_samples
    rng = random.Random(101)
    noise = bandpass_filter([rng.uniform(-1, 1) for _ in range(num_samples)], 1200, 3800)
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        # Solid tactile latch
        thump = math.sin(2.0 * math.pi * 280.0 * t) * math.exp(-t / 0.012)
        click = noise[i] * math.exp(-t / 0.008)
        samples[i] = (0.5 * thump + 0.5 * click) * 0.5
    return samples

def generate_interaction_success() -> list[float]:
    duration = 0.32
    num_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * num_samples
    # C major triad arpeggio chord: C5 (523.25), E5 (659.25), G5 (783.99)
    notes = [523.25, 659.25, 783.99]
    delays = [0.0, 0.04, 0.08]
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        val = 0.0
        for freq, delay in zip(notes, delays):
            if t >= delay:
                dt = t - delay
                env = math.exp(-dt / 0.12)
                val += (math.sin(2.0 * math.pi * freq * dt) + 0.3 * math.sin(2.0 * math.pi * freq * 2.0 * dt)) * env * 0.3
        samples[i] = val * 0.55
    return samples

def generate_interaction_denied() -> list[float]:
    duration = 0.18
    num_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * num_samples
    # Low double buzz
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        # Two short low buzz pulses at t=0 and t=0.08
        if t < 0.06:
            dt = t
            env = math.exp(-dt / 0.03)
        elif t >= 0.08 and t < 0.14:
            dt = t - 0.08
            env = math.exp(-dt / 0.03)
        else:
            env = 0.0
        buzz = (math.sin(2.0 * math.pi * 140.0 * t) + 0.5 * math.sin(2.0 * math.pi * 280.0 * t)) * env
        samples[i] = buzz * 0.4
    return samples

# --- Environment SFX Generation ---
def generate_door_open() -> list[float]:
    duration = 0.65
    num_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * num_samples
    rng = random.Random(202)
    noise = bandpass_filter([rng.uniform(-1, 1) for _ in range(num_samples)], 400, 2400)
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        # Initial mechanical release clunk (0 - 0.08s)
        clunk = math.sin(2.0 * math.pi * 120.0 * t) * math.exp(-t / 0.03) if t < 0.08 else 0.0
        # Smooth pneumatic slide whoosh
        whoosh_env = math.sin(math.pi * (t / duration)) ** 1.5
        motor_hum = math.sin(2.0 * math.pi * 180.0 * t) * whoosh_env * 0.25
        samples[i] = (0.45 * clunk + 0.35 * noise[i] * whoosh_env + motor_hum) * 0.6
    return samples

def generate_door_locked() -> list[float]:
    duration = 0.16
    num_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * num_samples
    rng = random.Random(303)
    noise = bandpass_filter([rng.uniform(-1, 1) for _ in range(num_samples)], 800, 3200)
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        # Double mechanical latch impact
        t1 = t
        t2 = t - 0.05
        e1 = math.exp(-t1 / 0.018)
        e2 = math.exp(-t2 / 0.018) if t2 >= 0 else 0.0
        solenoid = (math.sin(2.0 * math.pi * 180.0 * t1) * e1 + math.sin(2.0 * math.pi * 220.0 * max(0.0, t2)) * e2)
        click = (noise[i] * (e1 * 0.5 + e2 * 0.5))
        samples[i] = (0.6 * solenoid + 0.4 * click) * 0.55
    return samples

def generate_computer_beep() -> list[float]:
    duration = 0.085
    num_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * num_samples
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        # Chirp 1200 Hz -> 1500 Hz
        freq = 1200.0 + (300.0 * (t / duration))
        env = math.sin(math.pi * (t / duration)) ** 0.5
        samples[i] = math.sin(2.0 * math.pi * freq * t) * env * 0.25
    return samples

def generate_switch_toggle() -> list[float]:
    duration = 0.04
    num_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * num_samples
    rng = random.Random(404)
    noise = highpass_filter([rng.uniform(-1, 1) for _ in range(num_samples)], 1500)
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        thump = math.sin(2.0 * math.pi * 320.0 * t) * math.exp(-t / 0.008)
        snap = noise[i] * math.exp(-t / 0.006)
        samples[i] = (0.5 * thump + 0.5 * snap) * 0.5
    return samples

def generate_rift_hum() -> list[float]:
    duration = 2.0 # Loopable
    num_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * num_samples
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        # Low frequency drone 55 Hz with slow beating LFO
        lfo = 1.0 + 0.25 * math.sin(2.0 * math.pi * 1.0 * t) # 1.0 Hz beating
        f1 = 55.0
        f2 = 110.0
        f3 = 165.0
        val = (0.5 * math.sin(2.0 * math.pi * f1 * t) +
               0.3 * math.sin(2.0 * math.pi * f2 * t) +
               0.15 * math.sin(2.0 * math.pi * f3 * t)) * lfo * 0.35
        samples[i] = val
    return samples

# --- Seamless Ambient Loops ---
def generate_seamless_loop(duration: float, generator_fn, crossfade_sec: float = 0.25) -> list[float]:
    # Generate extra length and crossfade the tail into head for bit-perfect seamless loop
    cf_samples = int(crossfade_sec * SAMPLE_RATE)
    base_samples = int(duration * SAMPLE_RATE)
    total_samples = base_samples + cf_samples
    
    raw = generator_fn(total_samples)
    out = raw[:base_samples]
    
    # Crossfade the tail (raw[base_samples : total_samples]) onto the start (out[0 : cf_samples])
    for i in range(cf_samples):
        fade = i / cf_samples
        tail_sample = raw[base_samples + i]
        head_sample = out[i]
        out[i] = head_sample * fade + tail_sample * (1.0 - fade)
        
    return out

def generate_lab_ambience_past() -> list[float]:
    duration = 4.0
    def gen(num_samples: int) -> list[float]:
        rng = random.Random(505)
        raw_noise = [rng.uniform(-1, 1) for _ in range(num_samples)]
        vent = lowpass_filter(raw_noise, 320.0)
        out = [0.0] * num_samples
        for i in range(num_samples):
            t = i / SAMPLE_RATE
            # 60 Hz transformer hum + subtle harmonic 120 Hz
            hum = 0.35 * math.sin(2.0 * math.pi * 60.0 * t) + 0.15 * math.sin(2.0 * math.pi * 120.0 * t)
            # Gentle server room fan tone
            server = 0.08 * math.sin(2.0 * math.pi * 380.0 * t)
            # Combined with low ventilation air
            val = (hum * 0.25) + (vent[i] * 0.45) + (server * 0.15)
            out[i] = val * 0.22 # Quiet background ambience
        return out
    return generate_seamless_loop(duration, gen, 0.3)

def generate_lab_ambience_future() -> list[float]:
    duration = 4.0
    def gen(num_samples: int) -> list[float]:
        rng = random.Random(606)
        raw_noise = [rng.uniform(-1, 1) for _ in range(num_samples)]
        air = bandpass_filter(raw_noise, 100.0, 480.0)
        out = [0.0] * num_samples
        for i in range(num_samples):
            t = i / SAMPLE_RATE
            # Dark hollow drone (42 Hz) with slow 0.25 Hz modulation
            mod = 1.0 + 0.3 * math.sin(2.0 * math.pi * 0.25 * t)
            sub = 0.45 * math.sin(2.0 * math.pi * 42.0 * t) * mod
            # Distant cold resonance (280 Hz hollow tube ring)
            cold_res = 0.12 * math.sin(2.0 * math.pi * 280.0 * t) * (1.0 + 0.4 * math.sin(2.0 * math.pi * 0.5 * t))
            val = (sub * 0.35) + (cold_res * 0.2) + (air[i] * 0.5)
            out[i] = val * 0.20 # Quiet eerie atmosphere
        return out
    return generate_seamless_loop(duration, gen, 0.3)

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    audio_dir = os.path.join(base_dir, "assets", "audio")
    
    print("Generating Past-Future Audio Assets...")
    
    # 1. Footsteps (5 variations)
    footstep_dir = os.path.join(audio_dir, "footsteps")
    variations = [
        (1, 1.00, 0.18),
        (2, 0.94, 0.19),
        (3, 1.05, 0.17),
        (4, 0.98, 0.18),
        (5, 1.03, 0.19),
    ]
    for idx, pitch, dur in variations:
        path = os.path.join(footstep_dir, f"footstep_0{idx}.wav")
        samples = generate_footstep(seed=700 + idx, pitch_scale=pitch, duration=dur)
        write_wav(path, samples)
        print(f"Created {path}")

    # 2. UI SFX
    ui_dir = os.path.join(audio_dir, "ui")
    write_wav(os.path.join(ui_dir, "ui_click.wav"), generate_ui_click())
    write_wav(os.path.join(ui_dir, "ui_hover.wav"), generate_ui_hover())
    write_wav(os.path.join(ui_dir, "ui_confirm.wav"), generate_ui_confirm())
    write_wav(os.path.join(ui_dir, "ui_back.wav"), generate_ui_back())
    print(f"Created UI assets in {ui_dir}")

    # 3. Interaction SFX
    interaction_dir = os.path.join(audio_dir, "interaction")
    write_wav(os.path.join(interaction_dir, "interaction_click.wav"), generate_interaction_click())
    write_wav(os.path.join(interaction_dir, "interaction_success.wav"), generate_interaction_success())
    write_wav(os.path.join(interaction_dir, "interaction_denied.wav"), generate_interaction_denied())
    print(f"Created Interaction assets in {interaction_dir}")

    # 4. Environment SFX
    env_dir = os.path.join(audio_dir, "environment")
    write_wav(os.path.join(env_dir, "door_open.wav"), generate_door_open())
    write_wav(os.path.join(env_dir, "door_locked.wav"), generate_door_locked())
    write_wav(os.path.join(env_dir, "computer_beep.wav"), generate_computer_beep())
    write_wav(os.path.join(env_dir, "switch_toggle.wav"), generate_switch_toggle())
    write_wav(os.path.join(env_dir, "rift_hum.wav"), generate_rift_hum())
    print(f"Created Environment assets in {env_dir}")

    # 5. Ambience
    amb_dir = os.path.join(audio_dir, "ambience")
    write_wav(os.path.join(amb_dir, "lab_ambience_past.wav"), generate_lab_ambience_past())
    write_wav(os.path.join(amb_dir, "lab_ambience_future.wav"), generate_lab_ambience_future())
    print(f"Created Ambience assets in {amb_dir}")

    print("All audio assets successfully generated!")

if __name__ == "__main__":
    main()

