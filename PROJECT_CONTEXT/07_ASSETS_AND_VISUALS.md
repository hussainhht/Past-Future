# 07 ASSETS AND VISUALS: Materials, Shaders, Palettes & Assets

This document catalogs all shaders, materials, color palettes, 3D prop assets, audio assets, vector graphics, and third-party licensures in **Past-Future**.

---

## 1. Shaders & Visual Materials

The game relies on custom procedural shaders to produce a stylized painted aesthetic without heavy UV texture memory overhead:

### 1.1 Lab Floor Shader (`shaders/lab_floor.gdshader`)
- **Type**: `shader_type spatial; render_mode unshaded;`
- **Uniforms**: `uniform bool future = false;`
- **Features**:
  - Subdivides the floor plane into a $16 \times 13$ tile grid across normalized UV space.
  - Generates dark grout borders around each tile where normalized UV exceeds $0.98$.
  - Implements an alternating checkerboard brightness variation ($+4.5\%$).
  - Swaps base albedo based on `future`:
    - **Past**: Warm olive/sage (`vec3(0.34, 0.36, 0.29)` $\approx$ `#575c4a`).
    - **Future**: Dark navy/cyan slate (`vec3(0.15, 0.24, 0.27)` $\approx$ `#263d45`).

### 1.2 Painted Prop Shader (`shaders/painted_prop.gdshader`)
- **Type**: `shader_type spatial; render_mode unshaded;`
- **Uniforms**: `uniform vec4 paint_color : source_color;`
- **Features**:
  - Calculates world-space surface normals in vertex shader.
  - Evaluates custom directional face lighting against vector $\begin{bmatrix}-0.6 & 1.0 & 0.8\end{bmatrix}^T$.
  - Remaps face tones between $0.65$ (shadowed ambient face) and $1.0$ (illuminated face), yielding a hand-painted cel-shaded look without dynamic shadow maps.

### 1.3 Solo Temporal Ghost Shader (`shaders/temporal_ghost.gdshader`)
- **Type**: `shader_type spatial; render_mode unshaded, blend_mix, depth_draw_opaque;`
- **Uniforms**: Radius ($4.5\text{ m}$), translucency, edge fade curve, cyan emission (`#86c9d1`).
- **Features**: Generates a soft translucent hologram silhouette for the opposite timeline's character and nearby geometry during solo play.

### 1.4 Temporal Rift Shader (`shaders/temporal_rift.gdshader`)
- **Type**: `shader_type spatial; render_mode unshaded, blend_add;`
- **Features**: Multi-frequency swirling noise distortion and pulsing violet/cyan energy rings around active fractures.

### 1.5 Interaction Highlight Shader (`shaders/interaction_highlight.gdshader`)
- **Type**: `shader_type spatial;`
- **Features**: Fresnel edge glow and pulsing outline applied to the nearest interactive station detected by `InteractionDetector`.

---

## 2. Color Palettes: Past vs. Future

Modular furniture and structural props use palette slots configured via [scripts/world/lab_prop.gd](../scripts/world/lab_prop.gd):

| Prop Element Slot | Past Palette (Pristine Academic) | Future Palette (Decayed Ruins) | Aesthetic Shift |
|---|---|---|---|
| `body` (Chassis/Panels) | `#889181` (Warm Sage Grey) | `#557c86` (Muted Cyan Slate) | Warm metal $\rightarrow$ Cold oxidized alloy |
| `top` (Work Surfaces) | `#bbb693` (Warm Cream Wood) | `#90b7bd` (Bleached Pale Teal) | Clean desk $\rightarrow$ Waterlogged surface |
| `frame` (Legs/Borders) | `#4b5b55` (Dark Olive Slate) | `#304c59` (Deep Charcoal Blue) | Solid frame $\rightarrow$ Weathered dark oxide |
| `drawer` (Storage Fronts)| `#748475` (Muted Green Grey) | `#496d7b` (Dull Blue Slate) | Clean cabinet $\rightarrow$ Aged steel panel |
| `handle` (Metal Fixtures)| `#d6cfaa` (Brass / Polished) | `#adcdd3` (Cold Tarnished Steel)| Polished brass $\rightarrow$ Tarnished metal |
| `paper` (Documents) | `#e3dbb6` (Clean Parchment) | `#becfd0` (Ashen Deteriorated) | Legible notes $\rightarrow$ Burned/stained pages |
| `screen` (Monitors) | `#192f36` (Active CRT-Dark) | `#102a36` (Dead Power Screen) | Powered CRT $\rightarrow$ Unpowered dead glass |
| `signal` (Indicator LEDs)| `#c0ddbb` (Soft Green Glow) | `#80d9e4` (Flickering Cold Cyan)| System OK $\rightarrow$ Emergency auxiliary power |

### Character Palettes
- **Student (Past)**: Ochre mustard jacket (`#b18145`), cream henley shirt (`#f0e2c7`), peach tan skin (`#e1ac7f`), dark brown hair (`#302822`), slate trousers (`#343c46`), brown boots (`#60432e`).
- **Professor (Future)**: Dark navy formal coat (`#1d2b38`), dark charcoal waistcoat, slate shirt, charcoal black trousers, weathered leather boots, gray hair temples, and short beard.

---

## 3. Audio Asset Inventory & Provenance

All game audio is CC0 public domain sourced from Kenney. Provenance and hashes are tracked in [assets/audio/asset_provenance.json](../assets/audio/asset_provenance.json):

```text
assets/audio/
├── ambience/
│   ├── past/ (ventilation.ogg)
│   └── future/ (air_leak.ogg, metal_detail.wav)
├── music/
│   ├── past/ (observing_the_star.ogg)
│   └── future/ (galactic_temple.ogg)
├── footsteps/
│   ├── past_tile/ (step_01.wav through step_06.wav)
│   └── future_concrete/ (step_01.wav through step_05.wav)
├── doors/ (open.wav, close.wav)
├── computer/ (calibrate.wav, equipment.wav, invalid.wav, lock.wav, tune.wav)
├── documents/ (paper.wav)
├── interactions/ (switch.wav)
├── radio/ (activate, connect, deactivate, disconnect, incoming, outgoing, pickup, static.wav)
├── rift/ (energy_loop.ogg, stabilize.wav)
└── ui/ (back, click, close, confirm, error, hover, open.wav)
```

License texts are preserved in `assets/audio/licenses/` (`kenney_impact_sounds.txt`, `kenney_interface_sounds.txt`, `kenney_sci_fi_sounds.txt`).

---

## 4. Third-Party 3D Assets & Licensures

1. **KayKit Character Animations 1.1** (Kay Lousberg, CC0):
   - Location: `assets/third_party/kaykit_character_animations/` (Isolated via `.gdignore`).
   - Provides 77 source clips across 5 categories imported onto both the Student and Professor models.
   - License preserved in `License.txt`.
2. **KayKit Prop Assets**:
   - Reusable low-poly laboratory props in `assets/environments/kaykit_prototype_bits/` and `assets/environments/kaykit_space_base/`.
   - VRAM-compressed texture import settings verified in Godot 4.7.

---

## 5. 2D Vector Assets & UI Resources

- [assets/ui/temporal_background.svg](../assets/ui/temporal_background.svg): High-resolution split temporal clock dial used on main menu.
- [assets/world/spawn_ring.svg](../assets/world/spawn_ring.svg): Floor decal marker indicating spawn coordinates.
- [resources/ui/menu_theme.tres](../resources/ui/menu_theme.tres): Shared UI theme defining button styles (`PrimaryButton`, `SecondaryButton`), panel containers, font variations, and margins across all menus and HUDs.
