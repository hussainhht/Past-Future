"""Draw the Signal Laboratory's original textures: papers, notebook, blackboard, posters, signs, screens.

  python tools/assets/build_lab_textures.py        # writes assets/environment/textures/*.png

Everything is drawn here with Pillow (deterministic seeds). Text is rasterised with the DejaVu or
Liberation fonts shipped by the OS when available; only the rendered pixels are stored. Each image
has a Past version and, where the lab changes, a Future version (aged, stained, cracked or dead).
"""
from pathlib import Path
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "environment" / "textures"
FONT_DIRS = [Path("/usr/share/fonts/truetype/dejavu"), Path("/usr/share/fonts/truetype/liberation"),
             Path("C:/Windows/Fonts")]
FONTS = {"sans": ["DejaVuSans.ttf", "LiberationSans-Regular.ttf", "arial.ttf"],
         "bold": ["DejaVuSans-Bold.ttf", "LiberationSans-Bold.ttf", "arialbd.ttf"],
         "mono": ["DejaVuSansMono.ttf", "LiberationMono-Regular.ttf", "consola.ttf"],
         "monobold": ["DejaVuSansMono-Bold.ttf", "LiberationMono-Bold.ttf", "consolab.ttf"],
         "hand": ["DejaVuSans-Oblique.ttf", "LiberationSans-Italic.ttf", "DejaVuSansMono-Oblique.ttf", "ariali.ttf"],
         "serif": ["DejaVuSerif-Bold.ttf", "LiberationSerif-Bold.ttf", "timesbd.ttf"]}

PAPER = (243, 236, 216)
INK = (38, 52, 86)
PENCIL = (92, 92, 96)
CHALK = (232, 236, 226)


def font(kind, size):
    for name in FONTS[kind]:
        for folder in FONT_DIRS:
            if (folder / name).exists():
                return ImageFont.truetype(str(folder / name), size)
    return ImageFont.load_default()


def paper(w, h, seed, base=PAPER):
    rng = random.Random(seed)
    image = Image.new("RGB", (w, h), base)
    px = image.load()
    for _ in range(w * h // 18):
        x, y = rng.randrange(w), rng.randrange(h)
        d = rng.randint(-7, 4)
        r, g, b = px[x, y]
        px[x, y] = (r + d, g + d, b + d)
    return image


def handwriting(draw, xy, text, size, seed, color=INK, kind="hand"):
    """Slightly wavering lines of text, so notes read as written rather than typed."""
    rng = random.Random(seed)
    x, y = xy
    for line in text.split("\n"):
        cx = x + rng.randint(-3, 3)
        for word in line.split(" "):
            f = font(kind, size + rng.randint(-1, 1))
            draw.text((cx, y + rng.randint(-2, 2)), word, font=f, fill=color)
            cx += draw.textlength(word + " ", font=f)
        y += int(size * 1.45)


def age(image, seed, strength=1.0, cracks=0):
    """Yellow, fade, stain and crease an image: the same sheet after 31 years."""
    rng = random.Random(seed)
    w, h = image.size
    tint = Image.new("RGB", (w, h), (196, 186, 150))
    image = Image.blend(image, tint, 0.28 * strength)
    stains = Image.new("L", (w, h), 0)
    sd = ImageDraw.Draw(stains)
    for _ in range(int(5 * strength) + 2):
        cx, cy, r = rng.randrange(w), rng.randrange(h), rng.randint(w // 14, w // 5)
        sd.ellipse((cx - r, cy - r, cx + r, cy + r), fill=rng.randint(40, 110))
        sd.ellipse((cx - r + 6, cy - r + 6, cx + r - 6, cy + r - 6), fill=rng.randint(10, 40))
    stains = stains.filter(ImageFilter.GaussianBlur(w / 60))
    brown = Image.new("RGB", (w, h), (120, 92, 58))
    image = Image.composite(brown, image, stains)
    edge = Image.new("L", (w, h), 0)
    ed = ImageDraw.Draw(edge)
    for i in range(24):
        ed.rectangle((i, i, w - 1 - i, h - 1 - i), outline=int(150 * (1 - i / 24) * strength))
    edge = edge.filter(ImageFilter.GaussianBlur(6))
    image = Image.composite(Image.new("RGB", (w, h), (92, 80, 60)), image, edge)
    draw = ImageDraw.Draw(image)
    for _ in range(2):
        x0 = rng.randrange(w)
        draw.line((x0, 0, x0 + rng.randint(-40, 40), h), fill=(214, 206, 180), width=2)
    for _ in range(cracks):
        x, y = rng.randrange(w), rng.randrange(h)
        for _ in range(rng.randint(5, 9)):
            nx, ny = x + rng.randint(-60, 60), y + rng.randint(-60, 60)
            draw.line((x, y, nx, ny), fill=(30, 30, 30), width=rng.randint(1, 3))
            x, y = nx, ny
    return image


def save(image, name):
    OUT.mkdir(parents=True, exist_ok=True)
    image.save(OUT / name, optimize=True)
    return OUT / name


# --- Documents -----------------------------------------------------------------------------

def notes():
    image = paper(512, 680, 11)
    d = ImageDraw.Draw(image)
    for y in range(90, 680, 34):
        d.line((24, y, 488, y), fill=(178, 196, 214), width=1)
    d.line((70, 0, 70, 680), fill=(214, 150, 150), width=2)
    d.text((86, 40), "Calibration notes - array MK II", font=font("bold", 22), fill=INK)
    handwriting(d, (86, 96), "carrier must sit inside\n100.0 - 199.9 MHz band\nfine dial moves 0.1\n"
                "receiver bank B -> other end?\nProf: 'one frequency only.\nwrong carrier = static'\n"
                "echo again at 23:40 ...\nsame room. same voice?", 21, 3)
    for i in range(5):
        x = 300 + i * 34
        d.arc((x, 520, x + 34, 560), 180 if i % 2 else 0, 360 if i % 2 else 180, fill=INK, width=2)
    d.text((300, 570), "resonance?", font=font("hand", 18), fill=PENCIL)
    return image


def graph():
    image = paper(512, 680, 12, (240, 238, 226))
    d = ImageDraw.Draw(image)
    for i in range(0, 512, 16):
        d.line((i, 0, i, 680), fill=(196, 214, 204) if i % 80 else (160, 190, 176), width=1)
    for j in range(0, 680, 16):
        d.line((0, j, 512, j), fill=(196, 214, 204) if j % 80 else (160, 190, 176), width=1)
    d.line((60, 600, 470, 600), fill=INK, width=3)
    d.line((60, 600, 60, 120), fill=INK, width=3)
    points = [(60 + x, 600 - 420 * math.exp(-((x - 230) / 46) ** 2) - 30 * math.sin(x / 9) * 0.3) for x in range(0, 410, 4)]
    d.line(points, fill=(170, 60, 50), width=3)
    d.text((70, 70), "Echo strength vs carrier", font=font("bold", 20), fill=INK)
    d.text((380, 612), "MHz", font=font("sans", 18), fill=INK)
    handwriting(d, (300, 160), "peak!\nbut where?", 20, 9, (170, 60, 50))
    return image


def memo():
    image = paper(512, 680, 13, (246, 243, 232))
    d = ImageDraw.Draw(image)
    d.rectangle((30, 30, 482, 110), outline=INK, width=2)
    d.text((44, 40), "DEPARTMENT OF PHYSICS", font=font("bold", 22), fill=INK)
    d.text((44, 74), "Signal Laboratory 01  -  internal memo", font=font("sans", 17), fill=INK)
    body = ("To: all research students\n\nThe signal array door seals itself\nwhile the array is calibrating.\n"
            "It releases only once the carrier is\nstable and an answer comes back on\nthe receiver bank.\n\n"
            "Do not retune the array during a\ncontainment test. Do not discuss the\nresonance results outside this room.\n\n"
            "                       - The Professor")
    d.multiline_text((44, 140), body, font=font("mono", 17), fill=(40, 40, 46), spacing=8)
    return image


def notebook(future):
    image = Image.new("RGB", (1024, 640), PAPER)
    image.paste(paper(512, 640, 21), (0, 0))
    image.paste(paper(512, 640, 22), (512, 0))
    d = ImageDraw.Draw(image)
    for y in range(80, 640, 30):
        d.line((30, y, 490, y), fill=(182, 200, 216))
        d.line((540, y, 1000, y), fill=(182, 200, 216))
    d.line((511, 0, 511, 640), fill=(170, 160, 140), width=4)
    if not future:
        d.text((40, 30), "Research log  -  signal array", font=font("bold", 22), fill=INK)
        handwriting(d, (40, 86), "Day 12. The array answers itself.\nAn echo arrives before I transmit,\n"
                    "from this exact console.\nThe receiver bank says the source\nis 'downstream'.\n\n"
                    "The echo only locks on ONE carrier.\nI need someone on the other end\nto read it back to me.", 20, 31)
        d.text((560, 30), "Transmitter", font=font("bold", 22), fill=INK)
        d.rectangle((580, 90, 960, 300), outline=INK, width=3)
        for i, label in enumerate(("-10", "-1", "-0.1", "+0.1", "+1", "+10")):
            d.rectangle((590 + i * 61, 240, 640 + i * 61, 286), outline=INK, width=2)
            d.text((596 + i * 61, 252), label, font=font("sans", 15), fill=INK)
        d.text((620, 120), "1 _ _ . _  MHz", font=font("monobold", 40), fill=INK)
        handwriting(d, (560, 330), "tune, then TRANSMIT.\nwrong carrier = static.\nthe door stays sealed\nuntil the echo locks.", 20, 32)
    else:
        d.text((40, 30), "If you are reading this", font=font("bold", 22), fill=INK)
        handwriting(d, (40, 86), "you came back. Good.\n\nThe main receiver died with the core.\n"
                    "Bank B still has a backup cell.\nThe breaker is the grey box\non the wall by the console.\n\n"
                    "Restore it and the log will boot.\nRead him the carrier.", 20, 41)
        handwriting(d, (560, 60), "He is in this room.\nHe always was.\n\n31 years and the door\nnever opened.\n\n"
                    "Don't tell him why\nI started it.", 22, 42, (120, 40, 40))
        image = age(image, 43, 1.0)
    return image


def blackboard(future):
    rng = random.Random(51)
    image = Image.new("RGB", (1024, 512), (46, 74, 60))
    px = image.load()
    for _ in range(40000):
        x, y = rng.randrange(1024), rng.randrange(512)
        r, g, b = px[x, y]
        d = rng.randint(-6, 8)
        px[x, y] = (r + d, g + d, b + d)
    d = ImageDraw.Draw(image)
    lines = ["E = h f", "lambda = c / f", "psi(t) = A sin(2 pi f t + phi)", "f0 = ??? MHz"]
    for i, text in enumerate(lines):
        handwriting(d, (40, 30 + i * 80), text, 40, 60 + i, CHALK, "hand")
    pts = [(560 + x, 170 + 70 * math.sin(x / 26)) for x in range(0, 400, 3)]
    d.line(pts, fill=CHALK, width=4)
    d.ellipse((760, 330, 980, 470), outline=(240, 220, 150), width=4)
    handwriting(d, (790, 375), "RESONANCE", 30, 70, (240, 220, 150))
    d.line((540, 300, 740, 300), fill=CHALK, width=3)
    handwriting(d, (560, 310), "echo arrives BEFORE pulse", 26, 71, CHALK)
    if future:
        smudge = Image.new("L", (1024, 512), 0)
        sd = ImageDraw.Draw(smudge)
        for box in ((20, 20, 520, 220), (520, 120, 1000, 260), (740, 320, 1000, 490)):
            sd.rounded_rectangle(box, 40, fill=210)
        smudge = smudge.filter(ImageFilter.GaussianBlur(28))
        image = Image.composite(Image.new("RGB", (1024, 512), (62, 84, 72)), image, smudge)
        d = ImageDraw.Draw(image)
        handwriting(d, (60, 300), "THE FRACTURE WAS", 46, 81, (236, 236, 228), "bold")
        handwriting(d, (60, 380), "NOT AN ACCIDENT", 46, 82, (236, 236, 228), "bold")
        handwriting(d, (640, 40), "31 yrs", 40, 83, (200, 160, 220))
        image = age(image, 84, 0.35, cracks=3)
    return image


def poster_array():
    image = paper(512, 700, 91, (236, 230, 212))
    d = ImageDraw.Draw(image)
    d.rectangle((0, 0, 512, 90), fill=(87, 92, 74))
    d.text((24, 16), "TEMPORAL SIGNAL ARRAY", font=font("bold", 30), fill=(240, 226, 199))
    d.text((24, 56), "MK II  -  block schematic", font=font("sans", 18), fill=(228, 191, 127))
    boxes = {"EMITTER": (40, 160), "RESONATOR": (290, 160), "CORE": (165, 330), "RECEIVER B": (290, 500), "CONSOLE": (40, 500)}
    for label, (x, y) in boxes.items():
        d.rounded_rectangle((x, y, x + 180, y + 80), 10, outline=(40, 52, 60), width=3, fill=(244, 238, 222))
        d.text((x + 14, y + 26), label, font=font("bold", 20), fill=(40, 52, 60))
    for a, b in (("EMITTER", "RESONATOR"), ("RESONATOR", "CORE"), ("EMITTER", "CORE"), ("CORE", "RECEIVER B"), ("CONSOLE", "EMITTER"), ("RECEIVER B", "CONSOLE")):
        (x0, y0), (x1, y1) = boxes[a], boxes[b]
        d.line((x0 + 90, y0 + 40, x1 + 90, y1 + 40), fill=(140, 105, 193), width=3)
    d.text((24, 620), "carrier band 100.0 - 199.9 MHz   |   do not retune during containment", font=font("sans", 14), fill=(40, 52, 60))
    return image


def poster_safety():
    image = paper(512, 700, 92, (240, 234, 214))
    d = ImageDraw.Draw(image)
    d.polygon([(256, 40), (400, 280), (112, 280)], fill=(217, 164, 65), outline=(40, 40, 40))
    d.text((236, 120), "!", font=font("bold", 120), fill=(40, 40, 40))
    d.text((40, 310), "LAB SAFETY", font=font("bold", 44), fill=(112, 68, 44))
    rules = ["1  Never retune the array during", "   a containment test.", "2  Report every temporal echo.",
             "3  The door seals during calibration.", "4  Keep the core room locked.", "5  Two people. Always two."]
    for i, rule in enumerate(rules):
        d.text((40, 380 + i * 42), rule, font=font("sans", 22), fill=(40, 40, 40))
    return image


def poster_resonance():
    image = paper(512, 700, 93, (232, 236, 228))
    d = ImageDraw.Draw(image)
    d.text((30, 26), "RESONANCE MODES", font=font("bold", 34), fill=(48, 76, 89))
    for k in range(4):
        y0 = 120 + k * 140
        d.line((40, y0 + 60, 470, y0 + 60), fill=(120, 140, 150), width=1)
        pts = [(40 + x, y0 + 60 - 45 * math.sin((k + 1) * math.pi * x / 430)) for x in range(0, 431, 3)]
        d.line(pts, fill=[(170, 60, 50), (60, 120, 90), (140, 105, 193), (48, 76, 89)][k], width=4)
        d.text((40, y0), f"n = {k + 1}", font=font("sans", 18), fill=(48, 76, 89))
    return image


def sign_lab():
    image = Image.new("RGB", (1024, 256), (87, 92, 74))
    d = ImageDraw.Draw(image)
    d.rectangle((10, 10, 1013, 245), outline=(228, 191, 127), width=4)
    d.ellipse((34, 58, 174, 198), outline=(228, 191, 127), width=6)
    d.text((70, 92), "PF", font=font("serif", 54), fill=(240, 226, 199))
    d.text((210, 52), "SIGNAL LABORATORY 01", font=font("bold", 58), fill=(240, 226, 199))
    d.text((212, 140), "Department of Physics  -  Temporal Communications", font=font("sans", 30), fill=(228, 191, 127))
    return image


def sign_warning():
    image = Image.new("RGB", (512, 256), (232, 196, 90))
    d = ImageDraw.Draw(image)
    for i in range(-256, 512, 48):
        d.polygon([(i, 0), (i + 24, 0), (i + 24 + 40, 40), (i + 40, 40)], fill=(40, 40, 40))
    d.text((24, 64), "EXPERIMENT IN PROGRESS", font=font("bold", 34), fill=(40, 40, 40))
    d.text((24, 120), "Door seals during array", font=font("sans", 28), fill=(40, 40, 40))
    d.text((24, 160), "calibration.", font=font("sans", 28), fill=(40, 40, 40))
    for i in range(-256, 512, 48):
        d.polygon([(i, 216), (i + 24, 216), (i + 24 + 40, 256), (i + 40, 256)], fill=(40, 40, 40))
    return image


def clock(cracked):
    image = Image.new("RGB", (512, 512), (236, 230, 214))
    d = ImageDraw.Draw(image)
    d.ellipse((16, 16, 496, 496), outline=(40, 40, 40), width=10)
    for i in range(60):
        a = math.radians(i * 6)
        r0 = 208 if i % 5 else 188
        d.line((256 + r0 * math.sin(a), 256 - r0 * math.cos(a), 256 + 226 * math.sin(a), 256 - 226 * math.cos(a)),
               fill=(40, 40, 40), width=6 if i % 5 == 0 else 2)
    for h in range(1, 13):
        a = math.radians(h * 30)
        text = str(h)
        f = font("bold", 42)
        tw = d.textlength(text, font=f)
        d.text((256 + 150 * math.sin(a) - tw / 2, 256 - 150 * math.cos(a) - 26), text, font=f, fill=(40, 40, 40))
    d.text((206, 330), "PHYSICS", font=font("sans", 22), fill=(112, 68, 44))
    if cracked:
        image = age(image, 101, 0.6, cracks=5)
    return image


def monitor(kind):
    w, h = 512, 384
    if kind in ("dead", "cracked"):
        image = Image.new("RGB", (w, h), (10, 16, 20))
        d = ImageDraw.Draw(image)
        d.polygon([(30, 20), (220, 20), (120, 200)], fill=(18, 28, 34))
        if kind == "cracked":
            rng = random.Random(7)
            for _ in range(9):
                x, y = 300 + rng.randint(-20, 20), 160 + rng.randint(-20, 20)
                for _ in range(6):
                    nx, ny = x + rng.randint(-90, 90), y + rng.randint(-70, 70)
                    d.line((x, y, nx, ny), fill=(120, 140, 150), width=2)
                    x, y = nx, ny
        return image
    image = Image.new("RGB", (w, h), (8, 30, 26))
    d = ImageDraw.Draw(image)
    for x in range(0, w, 32):
        d.line((x, 0, x, h), fill=(16, 60, 50))
    for y in range(0, h, 32):
        d.line((0, y, w, y), fill=(16, 60, 50))
    if kind == "wave":
        pts = [(x, h / 2 + 90 * math.sin(x / 22) * math.exp(-((x - 256) / 200) ** 2)) for x in range(0, w, 2)]
        d.line(pts, fill=(140, 255, 200), width=4)
        d.text((14, 10), "CH1  CARRIER  SCAN", font=font("monobold", 22), fill=(140, 255, 200))
        d.text((14, h - 34), "ECHO: SEARCHING", font=font("mono", 20), fill=(228, 191, 127))
    else:
        rng = random.Random(5)
        d.text((14, 10), "RESONANCE LOG", font=font("monobold", 22), fill=(140, 255, 200))
        for i in range(10):
            d.text((14, 48 + i * 30), f"{rng.randint(100, 199)}.{rng.randint(0, 9)}  {'#' * rng.randint(2, 14)}",
                   font=font("mono", 20), fill=(110, 220, 180))
    return image


def keypad_display():
    image = Image.new("RGB", (256, 128), (12, 30, 26))
    d = ImageDraw.Draw(image)
    d.rectangle((6, 6, 249, 121), outline=(60, 120, 100), width=3)
    for x in range(14, 240, 22):
        d.line((x, 20, x, 108), fill=(18, 44, 38))
    return image


def book_spines():
    image = Image.new("RGB", (512, 256), (60, 60, 60))
    d = ImageDraw.Draw(image)
    colours = [(112, 68, 44), (61, 107, 90), (198, 154, 62), (62, 90, 122), (156, 59, 46), (87, 92, 74), (240, 226, 199), (48, 76, 89)]
    rng = random.Random(8)
    x = 0
    while x < 512:
        width = rng.randint(28, 52)
        colour = rng.choice(colours)
        d.rectangle((x, 0, x + width - 2, 255), fill=colour)
        d.rectangle((x + 4, 40, x + width - 6, 70), fill=(236, 230, 214))
        d.rectangle((x + 4, 200, x + width - 6, 206), fill=(228, 191, 127))
        x += width
    return image


def build():
    written = []
    for name, image in [
        ("paper_notes.png", notes()), ("paper_graph.png", graph()), ("paper_memo.png", memo()),
        ("notebook_past.png", notebook(False)), ("notebook_future.png", notebook(True)),
        ("blackboard_past.png", blackboard(False)), ("blackboard_future.png", blackboard(True)),
        ("poster_array.png", poster_array()), ("poster_safety.png", poster_safety()), ("poster_resonance.png", poster_resonance()),
        ("sign_lab.png", sign_lab()), ("sign_warning.png", sign_warning()),
        ("clock_face.png", clock(False)), ("clock_face_cracked.png", clock(True)),
        ("monitor_wave.png", monitor("wave")), ("monitor_data.png", monitor("data")),
        ("monitor_dead.png", monitor("dead")), ("monitor_cracked.png", monitor("cracked")),
        ("keypad_display.png", keypad_display()), ("book_spines.png", book_spines()),
    ]:
        written.append(save(image, name))
    for source, target, seed, cracks in [("paper_notes.png", "paper_notes_aged.png", 111, 0), ("paper_graph.png", "paper_graph_aged.png", 112, 0),
                                         ("paper_memo.png", "paper_memo_aged.png", 113, 0), ("poster_array.png", "poster_array_aged.png", 114, 1),
                                         ("poster_safety.png", "poster_safety_aged.png", 115, 1), ("poster_resonance.png", "poster_resonance_aged.png", 116, 2),
                                         ("sign_lab.png", "sign_lab_aged.png", 117, 2), ("sign_warning.png", "sign_warning_aged.png", 118, 1)]:
        written.append(save(age(Image.open(OUT / source).convert("RGB"), seed, 1.0, cracks), target))
    return written


if __name__ == "__main__":
    files = build()
    print(f"wrote {len(files)} textures to {OUT.relative_to(ROOT)}")
    sys.exit(0)
