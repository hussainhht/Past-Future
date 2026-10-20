"""Check skin binding and exact animation provenance, independent of Godot import.
Run: python3 tests/student_3d_assets.py (requires NumPy).
"""
from pathlib import Path
import json
import sys
import hashlib
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from gltf_tools import GLB, world_matrices
from student_rig import translate_samples
from ground_student_clips import sample


def main(character="student"):
    directory = ROOT / f"assets/characters/{character}_3d"
    model = GLB(directory / f"{character}.glb")
    manifest = json.loads((directory / "manifest.json").read_text())
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
            assert np.allclose(np.linalg.norm(n, axis=1), 1, atol=1e-4), "Normals must be unit length"
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
            assert hashlib.sha256((ROOT / "assets/third_party/kaykit_character_animations" / filename).read_bytes()).hexdigest() == manifest["source_sha256"][filename]
        original = cache[filename]
        source = next(a for a in original.doc["animations"] if a["name"] == animation["name"])
        assert len(animation["channels"]) in (len(source["channels"]), len(source["channels"])+1)
        for a,b in zip(source["channels"], animation["channels"]):
            source_name = original.doc["nodes"][a["target"]["node"]]["name"]
            target_name = doc["nodes"][b["target"]["node"]]["name"]
            assert source_name == target_name and a["target"]["path"] == b["target"]["path"]
        channel_by_sampler = {c["sampler"]: c for c in source["channels"]}
        for sampler_index,(a,b) in enumerate(zip(source["samplers"],animation["samplers"])):
            channel = channel_by_sampler[sampler_index]
            bone = original.doc["nodes"][channel["target"]["node"]]["name"]
            clearance = manifest.get("ground_clearance", {}).get(animation["name"])
            if clearance and bone == "root" and channel["target"]["path"] == "translation":
                times=np.asarray(clearance["times"])
                assert np.array_equal(model.read(b["input"]).ravel(),times.astype(np.float32))
                expected=np.array([sample(original.read(a["input"]).ravel(),original.read(a["output"]),t,"translation") for t in times])
                expected=translate_samples(expected,manifest["retarget"]["root"])
                expected[:,1]+=clearance["vertical_offsets"]
                assert np.allclose(model.read(b["output"]),expected,atol=1e-6)
                assert 0 <= clearance["max_vertical_offset"] < .5
                tracks += 1
                continue
            for key in ["input","output"]:
                expected = original.read(a[key])
                if key == "output" and channel["target"]["path"] == "translation":
                    expected = translate_samples(expected, manifest["retarget"][bone]).astype(np.float32)
                    assert np.allclose(expected,model.read(b[key]),atol=1e-6), "Translation must use documented proportion retarget"
                else:
                    assert np.array_equal(expected,model.read(b[key])), "KayKit times, rotations and scale must remain unchanged"
            assert a.get("interpolation","LINEAR") == b.get("interpolation","LINEAR")
            tracks += 1
    print(f"{character.upper()} 3D ASSETS: PASS ({vertices} skinned vertices, 23 rebuilt bind transforms, 77 clips, {tracks} source/retargeted samplers)")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--character", choices=["student", "professor"], default="student")
    main(parser.parse_args().character)
