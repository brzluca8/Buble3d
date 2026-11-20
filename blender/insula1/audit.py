"""
Audit (fără modificări): măsoară insula din joc și pe Orion, ca să comparăm claritatea și să găsim cauzele artefactelor.

    python blender/insula1/audit.py -- [--json iesire.json]

Pentru fiecare GLB: texturile (rezoluție), dimensiunile în metri, densitatea texturii (px/m) în două feluri,
triunghiuri, vârfuri, materiale, mesh-uri, componente conectate după sudarea vârfurilor pe poziție,
triunghiuri degenerate, fețe la care normala din fișier e opusă sensului de desenare (în Godot, cu fețele
desenate pe ambele părți, acestea ies întunecate), insule UV și cât din atlas e folosit.
"""
import json
import os
import sys

import bpy
import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[argv.index("--json") + 1] if "--json" in argv else ""


def tex_sizes(ob):
    out = []
    for m in ob.data.materials:
        if m is None or not m.use_nodes:
            continue
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                role = "?"
                for l in n.outputs[0].links:
                    role = l.to_socket.name if l.to_node.type == "BSDF_PRINCIPLED" else l.to_node.type
                out.append((n.image.name, tuple(n.image.size), role))
    return out


def measure(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    res = {"fisier": os.path.relpath(path, ROOT), "meshuri": []}
    all_co, tot_tri, tot_area = [], 0, 0.0
    mats = set()
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH":
            continue
        me = ob.data
        M = np.array(ob.matrix_world)
        n = len(me.polygons)
        co = np.empty(len(me.vertices) * 3, np.float32)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3) @ M[:3, :3].T + M[:3, 3]
        fv = np.empty(n * 3, np.int32)
        me.polygons.foreach_get("vertices", fv)
        fv = fv.reshape(-1, 3)
        ls = np.empty(n, np.int32)
        me.polygons.foreach_get("loop_start", ls)
        P = co[fv]
        cr = np.cross(P[:, 1] - P[:, 0], P[:, 2] - P[:, 0])
        a3 = 0.5 * np.linalg.norm(cr, axis=1)
        fn = cr / np.maximum(2 * a3[:, None], 1e-20)
        # normalele din fișier (pe colțuri), mediate pe față, față de normala după sensul de desenare
        cn = np.array([c.vector[:] for c in me.corner_normals]) if hasattr(me, "corner_normals") else None
        inv = 0
        inv_area = 0.0
        if cn is not None and len(cn) == len(me.loops):
            cn = cn @ M[:3, :3].T
            vn = (cn[ls] + cn[ls + 1] + cn[ls + 2])
            d = np.einsum("ij,ij->i", vn, fn)
            bad = (d < 0) & (a3 > 1e-12)
            inv, inv_area = int(bad.sum()), float(a3[bad].sum())
        degen = int((a3 < 1e-9).sum())
        # componente după sudarea vârfurilor pe poziție (GLB-ul dublează vârfurile la cusăturile UV)
        key = np.round(co / 1e-4).astype(np.int64)
        _, weld = np.unique(key, axis=0, return_inverse=True)
        weld = weld.ravel()
        wf = weld[fv]
        e = np.concatenate([wf[:, [0, 1]], wf[:, [1, 2]], wf[:, [2, 0]]])
        e.sort(1)
        fid = np.tile(np.arange(n), 3)
        k2 = e[:, 0] * (weld.max() + 1) + e[:, 1]
        o = np.argsort(k2, kind="stable")
        same = k2[o][1:] == k2[o][:-1]
        A, B = fid[o][:-1][same], fid[o][1:][same]
        g = coo_matrix((np.ones(len(A)), (A, B)), shape=(n, n))
        ncomp, lab = connected_components(g, directed=False)
        sizes = np.bincount(lab)
        # UV: insule (componente fără sudare) și cât din atlas acoperă
        uv = np.empty(len(me.loops) * 2, np.float32)
        me.uv_layers.active.data.foreach_get("uv", uv) if me.uv_layers else None
        uv = uv.reshape(-1, 2)
        T = np.stack([uv[ls + k] for k in range(3)], 1)
        a_uv = 0.5 * np.abs((T[:, 1, 0] - T[:, 0, 0]) * (T[:, 2, 1] - T[:, 0, 1]) - (T[:, 2, 0] - T[:, 0, 0]) * (T[:, 1, 1] - T[:, 0, 1]))
        texs = tex_sizes(ob)
        W = max([t[1][0] for t in texs if t[2] in ("Base Color",)] or [0])
        dens = float(np.sqrt((a_uv.sum() * W * W) / max(a3.sum(), 1e-9))) if W else 0.0
        e0 = np.concatenate([fv[:, [0, 1]], fv[:, [1, 2]], fv[:, [2, 0]]])
        e0.sort(1)
        k0 = e0[:, 0].astype(np.int64) * len(co) + e0[:, 1]
        o0 = np.argsort(k0, kind="stable")
        s0 = k0[o0][1:] == k0[o0][:-1]
        g0 = coo_matrix((np.ones(int(s0.sum())), (fid[o0][:-1][s0], fid[o0][1:][s0])), shape=(n, n))
        n_isl = connected_components(g0, directed=False)[0]
        res["meshuri"].append(dict(nume=ob.name, triunghiuri=n, varfuri=len(co), varfuri_sudate=int(weld.max() + 1),
                                   materiale=[m.name for m in me.materials if m], texturi=[(t[0], list(t[1]), t[2]) for t in texs],
                                   arie_m2=round(float(a3.sum()), 1), densitate_px_m=round(dens, 1),
                                   componente=int(ncomp), componente_mici_sub_20_tri=int((sizes < 20).sum()),
                                   cea_mai_mare_componenta=int(sizes.max()), degenerate=degen,
                                   fete_normala_inversata=inv, arie_normala_inversata_m2=round(inv_area, 2),
                                   insule_uv=int(n_isl), atlas_folosit_pct=round(100 * float(a_uv.sum()), 1)))
        for m in me.materials:
            if m:
                mats.add(m.name)
        all_co.append(co)
        tot_tri += n
        tot_area += float(a3.sum())
    co = np.concatenate(all_co)
    lo, hi = co.min(0), co.max(0)
    res["dimensiuni_m"] = [round(float(x), 2) for x in (hi - lo)]  # Blender: x, y (adâncime), z (înălțime)
    res["triunghiuri"] = tot_tri
    res["materiale_unice"] = sorted(mats)
    res["arie_m2"] = round(tot_area, 1)
    return res


def main():
    out = {}
    for name, p in [("insula", os.path.join(ROOT, "godot", "assets", "models", "insula1", "insula1.glb")),
                    ("orion", os.path.join(ROOT, "godot", "assets", "models", "orion.glb"))]:
        out[name] = measure(p)
    for name, r in out.items():
        print(f"== {name}: {r['fisier']}  dimensiuni {r['dimensiuni_m']} m  triunghiuri {r['triunghiuri']}  arie {r['arie_m2']} m2")
        for m in r["meshuri"]:
            print("   ", json.dumps(m, ensure_ascii=False))
    if OUT:
        with open(OUT, "w") as f:
            json.dump(out, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
