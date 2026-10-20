# Audio Asset Provenance and Technical Specifications

This document details the licensing, generation methodology, and technical parameters for all audio assets in **Past-Future**.

---

## 1. Provenance Summary

All audio assets in this directory were generated procedurally using Python 3.11 (`tools/generate_audio_assets.py`) using only standard mathematical signal synthesis libraries (`wave`, `struct`, `math`, `random`).

- **License**: Creative Commons Zero 1.0 Universal (CC0 1.0) / Public Domain dedication.
- **Third-Party Copyrights**: None.
- **Third-Party Attribution Requirements**: None.
- **Format**: 16-bit Linear PCM WAV, 44,100 Hz, Single-channel (Mono) for 3D positional/SFX clarity, Normalized with conservative headroom (-6 dB to -3 dB peak for SFX, -14 dB for ambient loops).
- **Generator Script**: `tools/generate_audio_assets.py` (fully deterministic via fixed seeds).

---

## 2. Asset Manifest & Synthesis Details

### 2.1 Character Locomotion (`assets/audio/footsteps/`)

Designed for firm laboratory hard flooring (polished concrete, ceramic lab tile). Each footstep combines an initial heel transient thump, bandpass-filtered sole scuff noise, and high-frequency tile contact resonance.

| File Path | Duration | Seed | Peak Level | Synthesis Characteristics |
|---|---|---|---|---|
| `assets/audio/footsteps/footstep_01.wav` | 0.18 s | 701 | -5.8 dB | Baseline heel thump (110 Hz $\to$ 45 Hz), bandpass scuff (700–2200 Hz), 520 Hz tile ring |
| `assets/audio/footsteps/footstep_02.wav` | 0.19 s | 702 | -6.1 dB | Slightly lower pitch scale (0.94x), deeper transient resonance, extended sole decay |
| `assets/audio/footsteps/footstep_03.wav` | 0.17 s | 703 | -5.6 dB | Brighter pitch scale (1.05x), sharper initial high transient contact |
| `assets/audio/footsteps/footstep_04.wav` | 0.18 s | 704 | -5.9 dB | Mid-tone variant (0.98x), subtle lateral scuff texture |
| `assets/audio/footsteps/footstep_05.wav` | 0.19 s | 705 | -5.7 dB | Energetic variant (1.03x), balanced heel/toe strike profile |

---

### 2.2 User Interface Feedback (`assets/audio/ui/`)

Restrained, non-fatiguing laboratory interface audio cues designed to remain pleasant during repetitive navigation.

| File Path | Duration | Peak Level | Frequency / Envelope Profile |
|---|---|---|---|
| `assets/audio/ui/ui_click.wav` | 28 ms | -6.2 dB | Dual-tone micro transient (2200 Hz & 4400 Hz) with 5 ms exponential decay envelope |
| `assets/audio/ui/ui_hover.wav` | 16 ms | -12.5 dB | Soft 1760 Hz sine wave windowed by a half-sine squared envelope; ultra-subtle |
| `assets/audio/ui/ui_confirm.wav` | 140 ms | -4.8 dB | Ascending two-tone chime: D5 (587.3 Hz) for 40 ms transitioning to A5 (880 Hz) with overtone resonance |
| `assets/audio/ui/ui_back.wav` | 110 ms | -5.4 dB | Descending soft chime: E5 (659.2 Hz) for 35 ms transitioning to A4 (440 Hz) with damped decay |

---

### 2.3 Interaction Feedback (`assets/audio/interaction/`)

Tactile feedback for physical switches, terminal interfaces, and puzzle state changes.

| File Path | Duration | Peak Level | Frequency / Envelope Profile |
|---|---|---|---|
| `assets/audio/interaction/click.wav` | 45 ms | -4.5 dB | Low 280 Hz mechanical impact layered with 1200–3800 Hz bandpass friction noise |
| `assets/audio/interaction/success.wav`| 320 ms | -3.2 dB | Major triad arpeggio chime (C5 523 Hz, E5 659 Hz, G5 784 Hz) with warm decay |
| `assets/audio/interaction/denied.wav` | 180 ms | -4.0 dB | Dual-pulse low rejection buzz (140 Hz fundamental with 280 Hz harmonic, 30 ms decay per pulse) |

---

### 2.4 Environment & World Audio (`assets/audio/environment/`)

Spatialized 3D audio assets configured for in-world object positioning.

| File Path | Duration | Peak Level | Frequency / Envelope Profile |
|---|---|---|---|
| `assets/audio/environment/door_open.wav` | 650 ms | -3.5 dB | 120 Hz mechanical latch release clunk followed by pneumatic air slide whoosh (400–2400 Hz noise) |
| `assets/audio/environment/door_locked.wav` | 160 ms | -3.8 dB | Double mechanical solenoid rejection impact (180 Hz & 220 Hz transient clunks) |
| `assets/audio/environment/computer_beep.wav` | 85 ms | -6.5 dB | Laboratory terminal telemetry chirp (1200 Hz sliding rapidly to 1500 Hz) |
| `assets/audio/environment/switch_toggle.wav` | 40 ms | -5.0 dB | Crisp physical toggle relay engagement (320 Hz thump + highpass 1500 Hz snap) |
| `assets/audio/environment/rift_hum.wav` | 2.0 s loop | -8.0 dB | Deep 55 Hz drone with 110 Hz and 165 Hz harmonics, modulated by a 1.0 Hz slow beating LFO |

---

### 2.5 Timeline Ambiences (`assets/audio/ambience/`)

Continuous, seamlessly loopable atmospheric room tones with circular crossfading at boundaries to guarantee zero click or phase discontinuity.

| File Path | Duration | Peak Level | Atmospheric Identity |
|---|---|---|---|
| `assets/audio/ambience/lab_ambience_past.wav` | 4.0 s loop | -14.2 dB | **Past Timeline**: Stable operational lab. Low 60 Hz electrical hum, 120 Hz harmonic, smooth filtered HVAC air (<320 Hz), and subtle 380 Hz server rack presence |
| `assets/audio/ambience/lab_ambience_future.wav` | 4.0 s loop | -14.8 dB | **Future Timeline**: Abandoned ruin. Deep 42 Hz sub-bass drone with 0.25 Hz slow undulating modulation, cold 280 Hz hollow tube resonance, and distant turbulent air |

---

## 3. Regeneration Instructions

To regenerate all audio assets identically from source:

```powershell
python tools/generate_audio_assets.py
```

