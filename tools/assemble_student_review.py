"""Lay out reference comparisons and temporal animation evidence, without repainting.

Run after render_student_review.gd:
    python tools/assemble_student_review.py
Requires Pillow. Inputs/references are unchanged. Model frames are actual Godot renders.
"""
from pathlib import Path
import argparse
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / "assets/characters/student_3d/review"
REFERENCES = ROOT / "assets/characters/references"
BACKGROUND = (19, 23, 30)
TEXT = (225, 226, 230)
MUTED = (158, 167, 180)


def font(size):
    for path in ["C:/Windows/Fonts/segoeui.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def text(canvas, xy, content, size=22, color=TEXT):
    ImageDraw.Draw(canvas).text(xy, content, fill=color, font=font(size))


def open_rgb(path):
    return Image.open(path).convert("RGB")


def make_comparison(view, meta, backend="godot"):
    ref = open_rgb(REFERENCES / view["reference"])
    render = open_rgb(REVIEW / view["path"] if backend=="godot" else REVIEW / "blender" / (view["name"]+".png"))
    assert ref.size == render.size, (ref.size, render.size)
    w, h = ref.size
    sheet = Image.new("RGB", (w * 2, h + 100), BACKGROUND)
    sheet.paste(ref, (0, 62))
    sheet.paste(render, (w, 62))
    text(sheet, (24, 14), f"REFERENCE / {view['reference']}")
    text(sheet, (w + 24, 14), f"{backend.upper()} / {view['name'].upper()}")
    text(sheet, (24, h + 72), "Unretouched render; matched image size and approximate framing. Source camera unknown.", 17, MUTED)
    text(sheet, (w + 24, h + 72), f"Pose: {meta['neutral_clip']} | orthographic camera, 3 degree elevation", 17, MUTED)
    prefix="" if backend=="godot" else backend+"_"
    path = REVIEW / f"comparison_{prefix}{view['name']}.png"
    sheet.save(path)
    return path


def crop_character(image, wide=False):
    # Crop a fixed camera window, not a per-frame bounding box: motion stays visible.
    if wide:
        canvas=Image.new("RGB",(504,572),BACKGROUND)
        crop=image.crop((100,0,924,572)).resize((504,350),Image.Resampling.LANCZOS)
        canvas.paste(crop,(0,111))
        return canvas
    return image.crop((260, 0, 764, 572))


def make_turnaround(meta):
    views = meta["views"]
    width, height = 336, 381
    sheet = Image.new("RGB", (width * 3, (height + 38) * 2 + 55), BACKGROUND)
    text(sheet, (18, 13), "NEUTRAL TURNAROUND / six views", 24)
    for index, view in enumerate(views):
        column, row = index % 3, index // 3
        x, y = column * width, row * (height + 38) + 55
        image = crop_character(open_rgb(REVIEW / view["path"])).resize((width, height), Image.Resampling.LANCZOS)
        sheet.paste(image, (x, y))
        text(sheet, (x + 14, y + height + 4), view["name"].replace("_", " ").upper(), 18, MUTED)
    sheet.save(REVIEW / "turnaround.png")


def make_animation(clip):
    wide=clip["clip"] in ["Death_A","Jump_Full_Long"]
    frames = [crop_character(open_rgb(REVIEW / frame["path"]),wide) for frame in clip["frames"]]
    thumb_w, thumb_h = 210, 238
    header, label = 54, 28
    columns = 6
    records = clip["frames"] + clip["reverse"]
    rows = (len(records) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * thumb_w, header + rows * (thumb_h + label)), BACKGROUND)
    text(sheet, (16, 12), f"KAYKIT / {clip['clip']} / {clip['length']:.3f} seconds", 23)
    for index, record in enumerate(records):
        x, y = (index % columns) * thumb_w, header + (index // columns) * (thumb_h + label)
        frame = crop_character(open_rgb(REVIEW / record["path"]),wide).resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
        sheet.paste(frame, (x, y))
        rear = "REAR " if "rear_" in record["path"] else ""
        text(sheet, (x + 8, y + thumb_h + 2), f"{rear}{record['phase'] * 100:05.1f}%", 16, MUTED)
    sheet.save(REVIEW / f"motion_{clip['clip']}.jpg", quality=92)
    # Sampling at uniform phases and preserving source clip duration provides a
    # compact playback artifact; use the game's studio for full-rate playback.
    preview_frames = [frame.resize((352, 400), Image.Resampling.LANCZOS) for frame in frames]
    boundaries=[round(i*clip["length"]*100/len(frames))*10 for i in range(len(frames)+1)]
    duration=[max(10,b-a) for a,b in zip(boundaries,boundaries[1:])]
    preview_frames[0].save(
        REVIEW / f"playback_{clip['clip']}.gif",
        save_all=True, append_images=preview_frames[1:], duration=duration,
        loop=0, disposal=2, optimize=False,
    )


def make_index(meta):
    comparisons = [v for v in meta["views"] if v["reference"]]
    sections = ['<!doctype html><html lang="en"><meta charset="utf-8">',
                '<title>Student visual review</title><style>',
                'body{background:#13171e;color:#e1e2e6;font:16px system-ui;margin:28px;max-width:1500px}',
                'img{max-width:100%;height:auto}a{color:#c9ab79}.grid{display:flex;flex-wrap:wrap;gap:20px}',
                'figure{margin:0 0 28px}figcaption{padding:10px 0;color:#aeb7c5}',
                '</style><h1>Student visual evidence</h1>',
                '<p>Actual Godot renders. Reference matching and deformation quality require visual review; technical test success is separate.</p>',
                '<h2>Neutral turnaround</h2><img src="turnaround.png" alt="Six neutral character views">']
    for view in comparisons:
        sections.append(f'<h2>{view["name"].title()} reference comparison</h2><a href="comparison_{view["name"]}.png"><img src="comparison_{view["name"]}.png" alt="{view["name"]} comparison"></a>')
        if (REVIEW/"blender"/(view["name"]+".png")).exists():
            sections.append(f'<details><summary>Blender studio lighting comparison</summary><img src="comparison_blender_{view["name"]}.png" alt="Blender {view["name"]} comparison"></details>')
    sections.append('<h2>Animation playback and sampled poses</h2><p>GIFs preserve clip duration with 18 evenly spaced frames. Click a montage to inspect all samples and three rear views.</p><div class="grid">')
    for clip in meta["clips"]:
        name = clip["clip"]
        sections.append(f'<figure><img width="260" src="playback_{name}.gif" alt="{name}"><figcaption>{name} / {clip["length"]:.3f}s<br><a href="motion_{name}.jpg">Temporal pose montage</a></figcaption></figure>')
    sections.append('</div>')
    for path in meta["game"]:
        sections.append(f'<h2>{Path(path).stem.replace("_"," ").title()}</h2><img src="{path}" alt="{path}">')
    sections.append('</html>')
    (REVIEW / "index.html").write_text("\n".join(sections), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--neutral-only", action="store_true")
    args = parser.parse_args()
    meta = json.loads((REVIEW / "capture_manifest.json").read_text())
    for view in meta["views"]:
        if view["reference"]:
            make_comparison(view, meta)
            if (REVIEW/"blender"/(view["name"]+".png")).exists():
                make_comparison(view,meta,"blender")
    make_turnaround(meta)
    if not args.neutral_only:
        for clip in meta["clips"]:
            make_animation(clip)
    make_index(meta)
    print(f"Visual comparisons, turnarounds, and playback artifacts: {REVIEW}")


if __name__ == "__main__":
    main()
