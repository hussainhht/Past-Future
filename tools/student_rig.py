"""Proportion retargeting of KayKit's medium rig, retaining its bone axes.

Rotations and scale tracks remain exact. Translation tracks are moved from the
source rest location into the new rest location; animated deltas scale with the
bone length. Inverse binds are rebuilt, never copied from a different rest rig.
"""
from copy import deepcopy
import numpy as np
from gltf_tools import world_matrices


def make_rig(source, skin):
    count = max(skin["joints"]) + 1
    nodes = deepcopy(source["nodes"][:count])
    source_world = world_matrices(source)
    targets = {
        "root": (0, 0, 0), "hips": (0, .455, 0),
        "spine": (0, .65, 0), "chest": (0, 1.025, 0),
        "head": (0, 1.295, 0),
    }
    for sign, side in [(1, "l"), (-1, "r")]:
        for name, pos in {
            "upperarm": (.29, 1.16, 0), "lowerarm": (.54, 1.16, -.0139),
            "wrist": (.785, 1.16, 0), "hand": (.855, 1.16, 0),
            "handslot": (.951, 1.1025, 0), "upperleg": (.18, .565, 0),
            "lowerleg": (.18, .315, .008), "foot": (.18, .16, -.0186),
            "toes": (.18, .041, .0964),
        }.items():
            targets[name+"."+side] = (pos[0]*sign, pos[1], pos[2])
    desired = {}
    for i, node in enumerate(nodes):
        desired[i] = source_world[i].copy()
        desired[i][:3, 3] = targets[node["name"]]
    parents = {c: i for i, n in enumerate(nodes) for c in n.get("children", [])}
    retarget = {}
    for i, node in enumerate(nodes):
        parent = parents.get(i)
        local = np.linalg.inv(desired[parent]) @ desired[i] if parent is not None else desired[i]
        before = np.asarray(node.get("translation", [0, 0, 0]), dtype=float)
        after = local[:3, 3]
        node["translation"] = after.tolist()
        ratio = np.linalg.norm(after) / np.linalg.norm(before) if np.linalg.norm(before) > 1e-5 else 1.0
        retarget[node["name"]] = {"source_rest": before.tolist(), "target_rest": after.tolist(), "delta_scale": float(ratio)}
    inverse_binds = np.array([np.linalg.inv(desired[i]).T.reshape(16) for i in skin["joints"]])
    return nodes, inverse_binds, retarget


def translate_samples(values, mapping):
    return (values - np.array(mapping["source_rest"])) * mapping["delta_scale"] + np.array(mapping["target_rest"])
