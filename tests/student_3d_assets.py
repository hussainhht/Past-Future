"""Check skin binding and exact animation provenance, independent of Godot import.
Run: python3 tests/student_3d_assets.py (requires NumPy).
"""
from pathlib import Path
import json
import sys
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from gltf_tools import GLB, world_matrices


def main():
    model = GLB(ROOT / "assets/characters/student_3d/student.glb")
    manifest = json.loads((ROOT / "assets/characters/student_3d/manifest.json").read_text())
    doc = model.doc
    skin = doc["skins"][0]
    assert len(skin["joints"]) == 23
    world = world_matrices(doc)
    inverse_binds = model.read(skin["inverseBindMatrices"])
    for index, node in enumerate(skin["joints"]):
        assert np.allclose(world[node] @ inverse_binds[index].reshape(4,4).T, np.eye(4), atol=2e-5), "Rest pose must not distort the mesh"
    vertices = 0
    for mesh in doc["meshes"]:
        assert "Mannequin" not in mesh["name"]
        for primitive in mesh["primitives"]:
            attr = primitive["attributes"]
            p = model.read(attr["POSITION"])
            n = model.read(attr["NORMAL"])
            j = model.read(attr["JOINTS_0"])
            w = model.read(attr["WEIGHTS_0"])
            vertices += len(p)
            assert np.isfinite(p).all() and np.isfinite(n).all()
            assert np.allclose(w.sum(axis=1), 1, atol=1e-6)
            assert np.all(w >= 0) and j.max() < len(skin["joints"])
            assert model.read(primitive["indices"]).max() < len(p)
    assert vertices == manifest["vertices"]
    assert len(doc["animations"]) == 77
    cache = {}
    tracks = 0
    for animation in doc["animations"]:
        filename = manifest["animation_sources"][animation["name"]]
        if filename not in cache:
            cache[filename] = GLB(ROOT / "assets/third_party/kaykit_character_animations" / filename)
        original = cache[filename]
        source = next(a for a in original.doc["animations"] if a["name"] == animation["name"])
        assert len(source["channels"]) == len(animation["channels"])
        for a,b in zip(source["channels"], animation["channels"]):
            source_name = original.doc["nodes"][a["target"]["node"]]["name"]
            target_name = doc["nodes"][b["target"]["node"]]["name"]
            assert source_name == target_name and a["target"]["path"] == b["target"]["path"]
        for a,b in zip(source["samplers"],animation["samplers"]):
            for key in ["input","output"]:
                assert np.array_equal(original.read(a[key]),model.read(b[key])), "KayKit keyframes must remain unchanged"
            assert a.get("interpolation","LINEAR") == b.get("interpolation","LINEAR")
            tracks += 1
    print(f"STUDENT 3D ASSETS: PASS ({vertices} skinned vertices, 23 bind transforms, 77 clips, {tracks} exact source samplers)")


if __name__ == "__main__":
    main()
