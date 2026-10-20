"""Author the age-49 professor from the student's proportions and four references.

python3 tools/build_professor.py
Only professor_3d is written. Student geometry and KayKit sources stay untouched.
"""
from collections import defaultdict
import hashlib
import json
import math
import numpy as np

from build_student_kaykit import Student, curve
import student_mesh as mesh
from student_mesh import ROOT, smooth, normalize

OUTPUT = ROOT / "assets/characters/professor_3d"
REFERENCES = ROOT / "assets/characters/references/49"
PALETTE = dict(mesh.PALETTE)
PALETTE.update({
    "jacket": "353c50", "jacket_light": "434a5d", "jacket_dark": "292f40",
    "jacket_seam": "242b3b", "lining": "4a3a32", "cloth_wear": "686b70",
    "shirt": "687982", "shirt_shadow": "4b5d68", "waistcoat": "3c403c",
    "waistcoat_edge": "2c302e", "buttons": "414442", "button_highlight": "666966",
    "pants": "343936", "pants_seam": "444944", "boots": "222729",
    "boot_trim": "303638", "sole": "343734", "laces": "252927",
    "skin": "cc9874", "skin_shadow": "b87e5e", "age_line": "bc8d6d",
    "hair": "363638", "hair_mid": "48484b", "hair_light": "5e5e61",
    "hair_gray": "777a7e", "hair_silver": "999b9b", "beard": "67635e",
    "beard_base": "95816d", "beard_dark": "514e49", "beard_light": "a29e94", "mouth": "855b48",
    "watch": "8d8e87", "watch_face": "b8b2a0", "steel": "8a918e",
    "watch_leather": "614537", "brass": "60645f",
})


class Professor(Student):
    def __init__(self):
        super().__init__()
        mesh.PALETTE.clear()
        mesh.PALETTE.update(PALETTE)

    def keep_parts(self, predicate, recolor=None):
        """Retain reusable student parts with their existing skin weights."""
        old, parts = self.geometry, self.parts
        self.geometry = defaultdict(lambda: {"vertices": [], "faces": [], "weights": []})
        self.parts = []
        offsets = {}
        for part in parts:
            color = part["material"]
            face_start = offsets.get(color, 0)
            offsets[color] = face_start + part["triangles"]
            if not predicate(part):
                continue
            g = old[color]
            new_color = recolor(part, g) if recolor else color
            target = self.geometry[new_color]
            start = part["vertex_start"]
            end = start + part["vertex_count"]
            new_start = len(target["vertices"])
            target["vertices"].extend(g["vertices"][start:end])
            target["weights"].extend(g["weights"][start:end])
            target["faces"].extend([[i - start + new_start for i in f]
                                    for f in g["faces"][face_start:offsets[color]]])
            self.parts.append(dict(part, vertex_start=new_start, material=new_color))

    def surface(self, name, vertices, faces, color, weights, weld=False):
        # Open tears can leave isolated vertices; keep only the used surface.
        ids = sorted({i for f in faces for i in f})
        lookup, unique, positions = {}, [], {}
        for old in ids:
            key = tuple(np.round(vertices[old], 7)) if weld else old
            if key not in positions:
                positions[key] = len(unique)
                unique.append(vertices[old])
            lookup[old] = positions[key]
        mapped = [[lookup[i] for i in f] for f in faces]
        self.add(name, unique, [f for f in mapped if len(set(f)) == 3], color, weights)

    def coat_weights(self, p):
        if p[1] >= .65:
            return self.body_weights(p)
        leg = "upperleg.l" if p[0] >= 0 else "upperleg.r"
        blend = .48 * (1 - smooth(.39, .65, p[1])) * smooth(.02, .19, abs(p[0]))
        return {"hips": 1 - blend, leg: blend}

    def jacket(self):
        # A true open, thick coat shell, extending to mid thigh. The rear vent
        # and front opening remain gaps in the geometry rather than painted lines.
        self.coat_sections = curve([
            (.36, .322, .223, 0, -.007), (.40, .331, .229, 0, -.006),
            (.56, .325, .224, 0, -.006), (.72, .313, .217, 0, -.005),
            (.89, .325, .223, 0, -.008), (1.08, .343, .206, 0, -.012),
            (1.18, .300, .174, 0, -.01), (1.235, .145, .11, 0, 0),
        ], 4)
        for inward, half in [(i, h) for i in [False, True] for h in [0, 1]]:
            vertices, faces = [], []
            for y, rx, rz, cx, cz in self.coat_sections:
                vent = .12 * (1 - smooth(.36, .53, y))
                angles = np.linspace(.30, math.pi - vent, 41) if half == 0 else np.linspace(math.pi + vent, math.tau - .30, 41)
                for a in angles:
                    x = rx * math.copysign(abs(math.sin(a)) ** (2 / 2.8), math.sin(a))
                    z = rz * math.copysign(abs(math.cos(a)) ** (2 / 2.8), math.cos(a))
                    factor = .955 if inward else 1
                    vertices.append([cx + x * factor, y, cz + z * factor])
            n = len(angles)
            for row in range(len(self.coat_sections) - 1):
                for col in range(n - 1):
                    a = row * n + col
                    fs = [(a, a + 1, a + 1 + n), (a, a + 1 + n, a + n)]
                    faces.extend([tuple(reversed(f)) for f in fs] if inward else fs)
            self.surface("Coat / inner lining" if inward else "Coat / long open shell and rear vent",
                     vertices, faces, "lining" if inward else "jacket", self.coat_weights)
        body = self.body_weights
        for s in [-1, 1]:
            self.ribbon("Coat / long front facing", [
                (s * .151, .37, .207), (s * .149, .56, .220),
                (s * .145, .80, .222), (s * .15, 1.02, .207),
                (s * .19, 1.13, .162)], .037, .018, "jacket_light", self.coat_weights)
            self.patch("Coat / notched lapel", [
                (s * .065, 1.245, .100), (s * .176, 1.205, .158),
                (s * .258, 1.144, .176), (s * .193, 1.134, .210),
                (s * .227, 1.091, .218), (s * .10, .91, .251),
                (s * .118, 1.095, .207)], .022, "jacket_light", body)
            self.box("Coat / lower patch pocket", (s * .239, .592, .196),
                     (.145, .193, .027), "jacket_dark", self.coat_weights, .017)
            self.box("Coat / lower pocket face", (s * .239, .589, .211),
                     (.13, .174, .016), "jacket", self.coat_weights, .014)
            self.ribbon("Coat / pocket opening welt", [(s * .18, .675, .227),
                        (s * .289, .675, .203)], .015, .008, "jacket_light", self.coat_weights)
            self.tube("Coat / shoulder seam", [(s * .155, 1.215, -.115),
                      (s * .255, 1.184, -.147), (s * .31, 1.151, -.13)],
                      .0025, "jacket_seam", body, normal=(0, 0, -1))
        for y in [.535, .677, .818]:
            self.oval("Coat / horn button", (-.157, y, .244), (.019, .021, .009),
                      "buttons", self.coat_weights, 18, 8)
            self.oval("Coat / button highlight", (-.161, y + .004, .252),
                      (.007, .009, .002), "button_highlight", self.coat_weights, 10, 6)
        self.tube("Coat / back center seam", [(0, .51, -.237), (0, .74, -.229),
                  (0, .96, -.23), (0, 1.19, -.18)], .0023, "jacket_seam", body, normal=(0, 0, -1))
        # Low-contrast irregular dust clusters, concentrated at hem and elbows.
        rng = np.random.default_rng(49)
        for i in range(160):
            y = rng.uniform(.375, .54) if i < 125 else rng.uniform(1.07, 1.16)
            a = rng.uniform(.43, math.tau - .43)
            rx = np.interp(y, self.coat_sections[:, 0], self.coat_sections[:, 1])
            rz = np.interp(y, self.coat_sections[:, 0], self.coat_sections[:, 2])
            cz = np.interp(y, self.coat_sections[:, 0], self.coat_sections[:, 4])
            x = rx * math.copysign(abs(math.sin(a)) ** (2 / 2.8), math.sin(a))
            z = cz + rz * math.copysign(abs(math.cos(a)) ** (2 / 2.8), math.cos(a))
            p = np.array([x, y, z]) + normalize([x / rx ** 2, 0, (z - cz) / rz ** 2]) * .0018
            tangent = normalize([math.cos(a), 0, -math.sin(a)])
            r = rng.uniform(.0012, .004)
            self.add("Coat / subtle hem weathering", [p - tangent * r,
                     p + tangent * r, p + [0, r * 1.8, 0]], [(0, 1, 2)],
                     "cloth_wear", self.coat_weights)

    def hair(self):
        super().hair()
        def gray_existing(part, g):
            if part["name"] in ["Hair / temple left", "Hair / temple right", "Hair / side nape"]:
                return "hair_gray"
            if part["name"] == "Hair / rear layered lock":
                start = part["vertex_start"]
                center = np.mean(np.asarray(g["vertices"][start:start+part["vertex_count"]]), axis=0)
                if center[1] < 1.70 and .16 < abs(center[0]) < .25:
                    return "hair_gray"
            return part["material"]
        self.keep_parts(lambda p: True, gray_existing)
        # Broad salt-and-pepper temple ribbons sit on top of the original swept
        # locks. Smaller streaks continue through the rear/nape in all views.
        for s in [-1, 1]:
            for i in range(4):
                z = .20 - i * .075
                self.leaf("Hair / silver temple lock", [
                    (s * .28, 1.995 - i * .045, z),
                    (s * .362, 1.86 - i * .045, z + .025),
                    (s * .376, 1.70 - i * .035, z - .035),
                    (s * .32, 1.57 - i * .012, z - .06)],
                    .025 + .008 * (i % 2), .010, "hair_silver" if i == 0 else "hair_gray",
                    normal=(s, 0, 0))
            for i in range(3):
                self.leaf("Hair / gray rear side sweep", [
                    (s * (.29 - i * .027), 1.85, -.19 - i * .025),
                    (s * (.34 - i * .025), 1.65, -.27 - i * .012),
                    (s * (.25 - i * .025), 1.40, -.24 - i * .008)],
                    .021, .009, "hair_gray", normal=(s, 0, -1))
        self.leaf("Hair / silver forelock streak", [(-.20, 2.05, .205),
                  (-.061, 2.091, .323), (.045, 2.01, .367), (.082, 1.89, .35)],
                  .019, .008, "hair_gray")
        for i in range(5):
            x = (i - 2) * .10
            self.leaf("Hair / nape silver streak", [(x - .04, 1.76, -.345),
                      (x, 1.60, -.35), (x + .025, 1.39, -.288)],
                      .017, .009, "hair_silver" if i % 2 else "hair_gray", normal=(0, 0, -1))
        for material in ["hair_gray", "hair_silver"]:
            for p in self.geometry[material]["vertices"]:
                p[:] = (np.asarray(p) + normalize([p[0], (p[1] - 1.72) * .55, p[2] + .035]) * .026).tolist()

    def face(self):
        super().face()
        # Keep facial landmarks and bone binding; change the smile to a guarded
        # closed mouth and broaden the lower jaw only slightly with middle age.
        face = next(p for p in self.parts if p["name"] == "Skin / rounded jaw cheeks forehead")
        g = self.geometry[face["material"]]
        for p in g["vertices"][face["vertex_start"]:face["vertex_start"] + face["vertex_count"]]:
            p[0] *= 1 + .035 * (1 - smooth(1.38, 1.63, p[1]))
        mouth = next(p for p in self.parts if p["name"] == "Face / closed mouth")
        for p in self.geometry["mouth"]["vertices"][mouth["vertex_start"]:mouth["vertex_start"] + mouth["vertex_count"]]:
            p[1] = 1.475 - .075 * abs(p[0]) + (p[1] - 1.476) * .15
        head = self.rigid("head")
        self.tube("Face / guarded lower lip", [(-.032, 1.461, .311),
                  (0, 1.465, .318), (.032, 1.461, .311)], .0026, "skin_shadow", head)
        for part in self.parts:
            if part["name"] == "Face / thick sculpted brow":
                for p in self.geometry[part["material"]]["vertices"][part["vertex_start"]:part["vertex_start"]+part["vertex_count"]]:
                    p[1] -= .014 * (1 - smooth(.08, .24, abs(p[0])))
        for y, width in [(1.844, .065), (1.87, .08), (1.895, .065)]:
            # Recess the forehead details behind the fringe rather than letting
            # the raised curves sit in front of the hairline.
            self.tube("Face / restrained forehead line", [(-width, y, .283),
                      (0, y + .004, .292), (width, y, .283)], .0016, "age_line", head)
        for s in [-1, 1]:
            for i in range(2):
                self.tube("Face / crow's foot", [(s * .197, 1.641 - i * .013, .305),
                          (s * .235, 1.633 - i * .021, .294)], .0016, "age_line", head)
            self.tube("Face / tired lower eyelid", [(s * .12, 1.587, .322),
                      (s * .16, 1.583, .324), (s * .196, 1.595, .312)], .0018, "age_line", head)
        self.beard(face)

    def beard(self, face):
        # Copy actual jaw/cheek surface triangles to form a close beard layer,
        # so the stubble follows the face rather than floating over an ellipsoid.
        color = face["material"]
        start = face["vertex_start"]
        end = start + face["vertex_count"]
        original = self.geometry[color]
        triangles = [f for f in original["faces"] if all(start <= i < end for i in f)]
        verts = np.asarray(original["vertices"])
        points, faces = [], []
        def clip(poly, distance):
            result = []
            for a,b in zip(poly, poly[1:] + poly[:1]):
                da,db = distance(a),distance(b)
                if da >= 0:
                    result.append(a)
                if (da >= 0) != (db >= 0):
                    result.append(a + (b-a) * da / (da-db))
            return result
        for f in triangles:
            poly = [v.copy() for v in verts[f]]
            poly = clip(poly, lambda p: 1.438 + .12 * smooth(.12, .32, abs(p[0])) - p[1])
            poly = clip(poly, lambda p: p[1] - 1.29) if poly else []
            poly = clip(poly, lambda p: p[2] + .055) if poly else []
            if len(poly) < 3:
                continue
            start = len(points)
            for p in poly:
                points.append(p + normalize([p[0], (p[1] - 1.55) * .55, p[2] - .005]) * .0025)
            for i in range(1,len(poly)-1):
                if np.linalg.norm(np.cross(poly[i]-poly[0],poly[i+1]-poly[0])) > 1e-12:
                    faces.append((start,start+i,start+i+1))
        self.surface("Beard / close jaw and cheek surface", points, faces, "beard_base", self.rigid("head"), weld=True)
        rng = np.random.default_rng(4901)
        candidates = np.asarray(points)
        for p in candidates[rng.choice(len(candidates), min(780, len(candidates)), replace=False)]:
            out = normalize([p[0], (p[1] - 1.55) * .55, p[2]])
            across = normalize(np.cross(out, [0, 1, 0]))
            along = normalize(np.cross(across, out))
            r = rng.uniform(.0015, .0028)
            length = rng.uniform(.004, .009)
            ring = [p + r * (math.cos(a) * across + math.sin(a) * along)
                    for a in np.linspace(0, math.tau,5,endpoint=False)]
            vertices = ring + [p + out * length - np.array([0, .002, 0])]
            self.add("Beard / short salt and pepper stubble", vertices,
                     [(i, (i + 1) % 5, 5) for i in range(5)],
                     rng.choice(["beard", "beard_dark", "beard_light"], p=[.5, .28, .22]), self.rigid("head"))
        for s in [-1, 1]:
            self.lock("Beard / short moustache", [(s * .006, 1.519, .336),
                      (s * .037, 1.511, .336), (s * .073, 1.491, .319)],
                      [.007, .009, .002], [.003, .004, .001], "beard")

    def limbs(self):
        super().limbs()
        self.keep_parts(lambda p: not p["name"].startswith((
            "Jacket", "Sleeve fold", "Rolled cloth cuff", "Cuff fold edge",
            "Boot / crossed lace", "Boot / return lace", "Boot / eyelet", "Boot / tongue")),
            lambda p,g: "watch_leather" if p["name"].startswith("Watch / leather wrist strap") else p["material"])
        for s, side in [(1, "l"), (-1, "r")]:
            arm = self.arm_weights(side)
            # Skin beneath torn cloth, plus genuinely open small sleeve tears.
            sections = [(s * x, rz, ry, 0, 1.16)
                        for x, ry, rz in [(.26, .085, .083), (.50, .081, .08), (.76, .076, .073)]]
            if s < 0:
                sections.reverse()
            self.loft("Skin / covered upper arm " + side, sections, "skin", arm, 24, axis="x")
            specs = curve([(.22,.123,.12),(.31,.146,.139),(.42,.127,.12),
                           (.56,.116,.109),(.67,.113,.106),(.765,.105,.099)],8)
            n = 64
            vertices, faces = [], []
            for row, (x, ry, rz) in enumerate(specs):
                for j in range(n):
                    a = j * math.tau / n
                    ragged = .010 * (math.sin(a * 7) + .45 * math.sin(a * 13)) if row == len(specs) - 1 else 0
                    vertices.append([s * (x + ragged), 1.16 + ry * math.cos(a), rz * math.sin(a)])
            for row in range(len(specs) - 1):
                for j in range(n):
                    x = (specs[row][0] + specs[row + 1][0]) / 2
                    angle = (j + .5) * math.tau / n
                    # Right sleeve damage is visible in front and right views.
                    if side == "r" and ((x - .40) / .034) ** 2 + (min(angle, math.tau - angle) / .31) ** 2 < 1:
                        continue
                    if side == "r" and ((x - .55) / .018) ** 2 + ((angle - .9) / .18) ** 2 < 1:
                        continue
                    a = row * n + j
                    b = row * n + (j + 1) % n
                    fs = [(a, b, b + n), (a, b + n, a + n)]
                    faces.extend([tuple(reversed(f)) for f in fs] if s < 0 else fs)
            self.surface("Coat / worn sleeve " + side, vertices, faces, "jacket", arm)
            for x, mat, radius in [(.754, "lining", .104), (.728, "jacket_light", .11)]:
                sections = [(s * (x - .012), radius, radius, 0, 1.16),
                            (s * (x + .012), radius, radius, 0, 1.16)]
                if s < 0:
                    sections.reverse()
                self.loft("Coat / worn cuff " + side, sections, mat, arm, 32, axis="x")

    def accessories(self):
        # The reference professor has no satchel, crossbody strap, or ID card.
        body = self.body_weights
        self.box("Coat / pen breast pocket", (.221, 1.025, .198),
                 (.106, .123, .025), "jacket_dark", body, .01)
        self.box("Coat / pen pocket face", (.221, 1.014, .215),
                 (.096, .092, .017), "jacket", body, .008)
        for x, height, col in [(.203, .12, "steel"), (.235, .103, "button_highlight")]:
            self.box("Research / pen barrel", (x, 1.086, .228), (.012, height, .012), col, body, .003)
            self.tube("Research / pen clip", [(x + .006, 1.135, .234),
                      (x + .010, 1.108, .243), (x + .010, 1.07, .241)], .0023, "steel", body)

    def create(self):
        hips = self.rigid("hips")
        body = self.body_weights
        self.loft("Trousers / pelvis", [(.53,.20,.105,0,0),(.565,.266,.15,0,0),
                  (.68,.276,.168,0,0)], "pants", hips, 40, power=3)
        self.loft("Shirt / slate button-up", [(.66,.26,.176,0,0),(.82,.275,.19,0,0),
                  (1.03,.266,.187,0,0),(1.17,.248,.153,0,0),(1.24,.113,.088,0,0)], "shirt", body, 40)
        self.jacket()
        # Waistcoat has a deep V at the neck and two pointed lower fronts.
        for s in [-1, 1]:
            self.ribbon("Coat / collar stand", [(s*.035,1.218,.13),
                        (s*.11,1.265,.107),(s*.15,1.273,.02),
                        (s*.119,1.26,-.105),(0,1.25,-.12)], .052,.019,"jacket",body)
            self.patch("Waistcoat / tailored front", [
                (s*.025,1.05,.218),(s*.115,1.174,.168),(s*.215,1.10,.187),
                (s*.185,.66,.218),(s*.058,.605,.236),(0,.665,.249),
                (0,.925,.247)], .018, "waistcoat", body)
            self.tube("Waistcoat / V neckline binding", [(s*.116,1.173,.189),
                      (s*.061,1.064,.235),(0,.94,.267)], .006, "waistcoat_edge", body)
            self.patch("Shirt / pointed collar", [(s*.012,1.205,.12),
                       (s*.083,1.25,.094),(s*.12,1.195,.153),(s*.077,1.117,.199)],
                       .012, "shirt", body)
            self.tube("Shirt / collar seam", [(s*.083,1.246,.11),
                      (s*.112,1.196,.164),(s*.076,1.121,.212)], .0022, "shirt_shadow", body)
        for y in [.72,.815,.91]:
            self.oval("Waistcoat / center button", (0,y,.271),(.017,.018,.009), "buttons",body,18,8)
            self.oval("Waistcoat / button rim",(-.004,y+.003,.279),(.006,.008,.002),"button_highlight",body,10,6)
        self.ribbon("Shirt / button placket", [(0,1.177,.161),(0,1.075,.226),
                    (0,1.02,.239)], .022,.008,"shirt_shadow",body)
        self.oval("Shirt / throat button", (0,1.071,.242),(.007,.008,.004),"buttons",body,12,6)
        self.face()
        self.limbs()
        self.accessories()
        from fit_professor_face import fit_authored_face
        fit_authored_face(self)
        from fit_professor_clothes import fit_authored_clothing
        fit_authored_clothing(self)

    def export(self):
        super().export(output=OUTPUT, model_name="professor", reference_dir=REFERENCES,
                       authoring_script="tools/build_professor.py")
        path = OUTPUT / "manifest.json"
        manifest = json.loads(path.read_text())
        manifest.update(age=49, role="Professor", baseline="Age-18 Student proportions and KayKit rig",
                        reference_directory="assets/characters/references/49",
                        baseline_model_sha256=hashlib.sha256((OUTPUT.parent/"student_3d/student.glb").read_bytes()).hexdigest())
        path.write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    character = Professor()
    character.create()
    character.export()
