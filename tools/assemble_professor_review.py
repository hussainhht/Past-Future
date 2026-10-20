"""Arrange actual Godot renders and untouched references into review sheets.

python3 tools/assemble_professor_review.py (requires Pillow).
No model or reference source image is modified.
"""
from pathlib import Path
import html
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DIRECTORY = ROOT / "assets/characters/professor_3d"
REVIEW = DIRECTORY / "review"
REFERENCES = ROOT / "assets/characters/references/49"
BACKGROUND = "#15171e"
FONT = ImageFont.load_default(size=21)
SMALL = ImageFont.load_default(size=17)


def cell(path, title, width=512):
    image = Image.open(path).convert("RGB")
    image.thumbnail((width, 286), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (width, 326), BACKGROUND)
    canvas.paste(image, ((width - image.width) // 2, 40 + (286 - image.height) // 2))
    ImageDraw.Draw(canvas).text((14, 10), title, font=SMALL, fill="#d4d9e1")
    return canvas


def main():
    report = json.loads((REVIEW / "capture_manifest.json").read_text())
    views = report["views"]
    overview = Image.new("RGB", (1536, 712), BACKGROUND)
    ImageDraw.Draw(overview).text((22, 18), "THE PROFESSOR / AGE 49 / ACTUAL GODOT RENDERS", font=FONT, fill="#bbc7dc")
    for index, view in enumerate(views):
        overview.paste(cell(REVIEW / view["path"], view["name"].replace("_", " ").upper()),
                       ((index % 3) * 512, 60 + (index // 3) * 326))
        if view["reference"]:
            comparison = Image.new("RGB", (1024, 326), BACKGROUND)
            comparison.paste(cell(REFERENCES / view["reference"], "REFERENCE / " + view["name"].upper()), (0,0))
            comparison.paste(cell(REVIEW / view["path"], "MODEL / GODOT"), (512,0))
            comparison.save(REVIEW / f"comparison_{view['name']}.png")
    overview.save(DIRECTORY / "preview.png")
    overview.save(REVIEW / "turnaround.png")
    entries = []
    for clip in report["clips"]:
        frames = [Image.open(REVIEW / frame["path"]).convert("RGB") for frame in clip["frames"]]
        if not frames:
            continue
        delay = max(10, round(100 * clip["length"] / len(frames)) * 10)
        frames[0].save(REVIEW / f"playback_{clip['clip']}.gif", save_all=True,
                       append_images=frames[1:], loop=0, duration=delay, optimize=True)
        montage = Image.new("RGB", (1536, 652), BACKGROUND)
        samples = clip["frames"][::3][:6]
        for i, frame in enumerate(samples):
            montage.paste(cell(REVIEW / frame["path"], f"{clip['clip']} / {frame['phase']:.2f}"),
                          ((i % 3) * 512, (i // 3) * 326))
        montage.save(REVIEW / f"motion_{clip['clip']}.jpg", quality=90)
        name = html.escape(clip["clip"])
        entries.append(f'<section><h2>{name}</h2><img src="playback_{name}.gif" alt="{name} playback">'
                       f'<details><summary>Sampled poses</summary><img src="motion_{name}.jpg" alt="{name} poses"></details></section>')
    comparisons = "".join(f'<img src="comparison_{v["name"]}.png" alt="{v["name"]} comparison">'
                          for v in views if v["reference"])
    (REVIEW / "index.html").write_text('''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>Professor / age 49</title>
<style>body{background:#15171e;color:#d4d9e1;font:17px system-ui;max-width:1200px;margin:40px auto;padding:0 20px}img{display:block;max-width:100%;margin:16px auto}section{margin:36px 0}summary{cursor:pointer}p{line-height:1.6}</style>
<h1>The Professor / Age 49</h1><p>Actual Godot renders of the skinned model, compared with the original references.
The student remains unchanged. This is a stylized reconstruction; hair locks, cloth wrinkles, and facial contours are approximate.</p>
<img src="turnaround.png" alt="Six-view model turnaround"><h2>Reference comparisons</h2>'''
                        + comparisons + "<h2>Animation playback</h2>" + "".join(entries) + "</html>")
    print(f"PROFESSOR REVIEW: {REVIEW / 'index.html'}")


if __name__ == "__main__":
    main()
