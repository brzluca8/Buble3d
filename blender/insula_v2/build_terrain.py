"""
Insula 1 v2: terenul și stâncile (fără AI).

    python build_terrain.py

Pornește de la insula v1 (doar ca referință de niveluri) și construiește o insulă curată:
  - suprafața de sus: plasă polară cu densitate uniformă (~0,22 m), din harta de înălțimi curățată:
    inel de iarbă sub căsuțe (căsuțele rămân exact la înălțimile din joc), platoul castelului, piața,
    albia râului în jurul castelului, laguna, dealul cu cascadă;
  - pereți de stâncă în straturi și blocuri, margine rotunjită, con dedesubt (cu cristal la vârf);
  - zidul de piatră al platoului castelului;
  - culori de vârf: R = ocluzie ambientală (coaptă cu raze), G = piatră/cărare, B = nisip, A = mușchi.
Scrie: godot/assets/models/insula1_v2/teren.glb, godot/insula_v2/data/teren_info.gd și
blender/insula_v2/_build/teren.npz (pentru împrăștierea vegetației).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
from scipy import ndimage as ndi  # noqa: E402

import layout  # noqa: E402
import terrain  # noqa: E402
from common import OUT_DATA, OUT_MODELS, gd_vec3, log, smooth, tiles_blender  # noqa: E402

RES = terrain.RES
BUILD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_build")
os.makedirs(BUILD, exist_ok=True)
os.makedirs(OUT_MODELS, exist_ok=True)
os.makedirs(OUT_DATA, exist_ok=True)
rng = np.random.default_rng(11)

WL_RIVER = -1.42
WL_LAGOON = -2.64
PLATEAU_Z = 0.5
MC = np.array([layout.MOUND["x"], layout.MOUND["y"]])
SPACING = 0.22


def polyline_dist(px, py, pts, closed):
    """distance from points to a polyline, the arc-length parameter of the closest point, and the segment index"""
    P = np.stack([px, py], -1)
    segs = list(range(len(pts) if closed else len(pts) - 1))
    best = np.full(px.shape, 1e9)
    best_s = np.zeros(px.shape)
    best_i = np.zeros(px.shape, int)
    best_t = np.zeros(px.shape)
    cum = [0.0]
    for i in segs:
        a, b = pts[i], pts[(i + 1) % len(pts)]
        cum.append(cum[-1] + float(np.linalg.norm(b - a)))
    for k, i in enumerate(segs):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        ab = b - a
        L2 = float(ab @ ab) + 1e-12
        t = np.clip(((P - a) @ ab) / L2, 0, 1)
        q = a + t[..., None] * ab
        d = np.linalg.norm(P - q, axis=-1)
        m = d < best
        best = np.where(m, d, best)
        best_s = np.where(m, cum[k] + t * math.sqrt(L2), best_s)
        best_i = np.where(m, i, best_i)
        best_t = np.where(m, t, best_t)
    return best, best_s, best_i, best_t


# ============================================================================= 1. heightfield
def design(r):
    zb, col = r["zb"], r["col"]
    g = terrain.Grid(r["lo"], r["hi"], zb.shape)
    H, W = zb.shape
    cy, cx = np.mgrid[0:H, 0:W]
    X, Y = g.xy(cx + 0.5, cy + 0.5)
    valid = zb > -1e8
    F = terrain.build_fields(r)
    body = F["body"]
    base = ndi.gaussian_filter(F["height"], 0.5 * RES)
    th = np.arctan2(Y - MC[1], X - MC[0])
    rr = np.hypot(X - MC[0], Y - MC[1])

    # --- river geometry around the castle (theta from 30 deg counter-clockwise to -90 deg)
    a0, a1 = math.radians(28), math.radians(272)  # unwrapped: 28 .. 272 deg  (272 = -88)
    thu = np.mod(th - a0, 2 * np.pi) + a0  # in [a0, a0 + 2pi)
    water_r = F["water"] & (zb > -2.0)
    tr_ = np.mod(np.arctan2(Y[water_r] - MC[1], X[water_r] - MC[0]) - a0, 2 * np.pi) + a0
    rw = rr[water_r]
    bins = np.radians(np.arange(28, 273, 6))
    r_in, r_out = [], []
    for b in bins:
        s = np.abs(tr_ - b) < math.radians(5)
        if s.sum() > 15:
            r_in.append(np.percentile(rw[s], 5))
            r_out.append(np.percentile(rw[s], 95))
        else:
            r_in.append(np.nan)
            r_out.append(np.nan)
    r_in, r_out = np.array(r_in), np.array(r_out)
    ok = ~np.isnan(r_in)
    r_in = np.interp(bins, bins[ok], r_in[ok])
    r_out = np.interp(bins, bins[ok], r_out[ok])
    r_in = ndi.gaussian_filter1d(r_in, 2, mode="nearest")
    r_out = ndi.gaussian_filter1d(r_out, 2, mode="nearest")
    r_c = (r_in + r_out) / 2 + 0.2  # widen outward a little: the target's moat is wider
    half_w = np.clip((r_out - r_in) / 2 + 0.25, 0.95, 1.25)
    river_pts = np.stack([MC[0] + r_c * np.cos(bins), MC[1] + r_c * np.sin(bins)], -1)
    # resample the centreline every ~0.5 m
    seg = np.linalg.norm(np.diff(river_pts, axis=0), axis=1)
    cum = np.concatenate([[0], np.cumsum(seg)])
    s_new = np.linspace(0, cum[-1], int(cum[-1] / 0.5) + 1)
    river_pts = np.stack([np.interp(s_new, cum, river_pts[:, 0]), np.interp(s_new, cum, river_pts[:, 1])], -1)
    river_hw = np.interp(s_new, cum, half_w)
    river_len = float(cum[-1])
    # mound radius as a function of theta: just inside the river on the river side, 3.0 m on the plaza side
    def mound_r(t):
        tu = np.mod(t - a0, 2 * np.pi) + a0
        inside = (tu >= a0) & (tu <= a1)
        rin = np.interp(tu, bins, r_c - np.interp(bins, bins, half_w)) - 0.12
        blend = smooth(math.radians(12), 0, np.minimum(np.abs(tu - a0), np.abs(tu - a1)))
        return np.where(inside, rin, 3.05) * (1 - blend) + 3.05 * blend
    R_m = mound_r(th)

    # --- 1. ring band under the tiles
    tiles, tile_r = tiles_blender()
    d_ring, s_ring, i_ring, t_ring = polyline_dist(X, Y, tiles[:, :2], closed=True)
    h_a = tiles[i_ring, 2]
    h_b = tiles[(i_ring + 1) % len(tiles), 2]
    h_ring = h_a + (h_b - h_a) * smooth(0.0, 1.0, t_ring) - 0.12
    w_ring = smooth(1.85, 1.15, d_ring)
    hf = base * (1 - w_ring) + h_ring * w_ring

    # --- 2. plaza (inside the ring, right of the castle): level, cobbled
    plaza_c = np.array([4.3, -0.2])
    d_plaza = np.hypot(X - plaza_c[0], Y - plaza_c[1])
    w_plaza = smooth(3.4, 2.6, d_plaza) * (1 - w_ring)
    hf = hf * (1 - w_plaza) + (-0.38) * w_plaza

    # --- 3. castle mound: flat plateau with a hard edge (the stone wall mesh covers the drop)
    in_mound = rr < R_m
    # the plateau is a separate drum mesh (cobbled top, stone wall, parapet, front stairs); under it the terrain
    # stays low and smooth so that no terrain triangle pokes through the wall
    w_mound = smooth(0.45, -0.1, rr - R_m)
    hf = hf * (1 - w_mound) + (WL_RIVER - 0.4) * w_mound

    # --- 4. river channel
    d_riv, s_riv, i_riv, t_riv = polyline_dist(X, Y, river_pts, closed=False)
    hw_here = np.interp(s_riv, s_new, river_hw)
    ends = (s_riv <= 1e-6) | (s_riv >= river_len - 1e-6)
    q = d_riv / hw_here
    in_river = (q < 1.0) & (rr > R_m + 0.25)
    bed = WL_RIVER - 0.55 * (1 - q ** 2)
    bank = smooth(1.0, 1.0 + 0.9 / hw_here, q)  # 0 at the water edge -> 1 at 0.9 m out
    river_h = np.where(q < 1, bed, WL_RIVER + 0.05 + (hf - WL_RIVER - 0.05) * bank)
    w_riv = np.where(q < 1 + 0.9 / hw_here, 1.0, 0.0) * (rr > R_m + 0.25)
    hf = np.where(w_riv > 0, np.minimum(hf, river_h) * w_riv + hf * (1 - w_riv), hf)

    # --- 5. lagoon basin (front-left, below the workshop / dock)
    lag = F["water"] & (zb < -2.0)
    lag = ndi.binary_closing(lag, iterations=4)
    lag = ndi.binary_fill_holes(ndi.binary_dilation(lag, iterations=int(0.15 * RES)))
    lag = ndi.gaussian_filter(lag.astype(np.float32), 0.3 * RES) > 0.5
    d_in = ndi.distance_transform_edt(lag) / RES
    d_out = ndi.distance_transform_edt(~lag) / RES
    lag_h = np.where(lag, WL_LAGOON - 0.08 - 0.7 * smooth(0, 1.4, d_in), WL_LAGOON + 0.06 + 0.9 * smooth(0, 0.8, d_out))
    w_lag = smooth(0.9, 0.0, d_out)
    hf = np.where(w_lag > 0, np.minimum(hf, lag_h) * w_lag + hf * (1 - w_lag), hf)

    # --- 6. hill behind the ring: rounded rocky plateau, small pool at its foot
    hill = layout.HILL
    d_hill = np.hypot((X - hill["x"]) * 0.85, Y - hill["y"] - 0.4)
    hill_h = 0.9 + 1.3 * smooth(3.6, 2.9, d_hill) + 1.2 * smooth(2.3, 1.7, d_hill) + 0.3 * smooth(1.6, 0.0, d_hill)
    w_hill = smooth(4.2, 3.4, d_hill) * (1 - smooth(1.6, 0.9, d_ring))
    hf = np.maximum(hf, hf * (1 - w_hill) + hill_h * w_hill)
    pool_c = np.array([0.55, 7.25])
    d_pool = np.hypot(X - pool_c[0], Y - pool_c[1])
    POOL_Z = 0.62
    hf = np.where(d_pool < 0.75, np.minimum(hf, POOL_Z - 0.25 * (1 - (d_pool / 0.75) ** 2)), hf)

    # --- 7. pads under the hero props
    pads = {}
    for p in layout.HERO:
        if p["name"] in ("pod", "barca", "debarcader", "castel"):
            continue
        d = np.hypot(X - p["x"], Y - p["y"])
        m = d < p["r"]
        z = float(np.median(hf[m]))
        w = smooth(p["r"] + 0.5, p["r"] - 0.1, d) * (1 - w_ring)
        hf = hf * (1 - w) + z * w
        pads[p.get("id", p["name"])] = z
    bt = layout.BIG_TREE
    d = np.hypot(X - bt["x"], Y - bt["y"])
    z_bt = float(np.median(hf[d < 1.2]))
    hf = hf * (1 - smooth(1.6, 0.8, d) * (1 - w_ring)) + z_bt * smooth(1.6, 0.8, d) * (1 - w_ring)

    # --- masks
    path = np.zeros_like(hf)
    path = np.maximum(path, w_plaza)
    path = np.maximum(path, smooth(0.15, -0.1, rr - R_m) * 1.0)  # castle plateau: stone
    front = (np.abs(X - 0.2) < 1.1) & (Y < -2.0) & (Y > -4.9)  # approach from the stairs to the front tiles
    path = np.maximum(path, ndi.gaussian_filter(front.astype(np.float32), 0.25 * RES))
    path *= 1 - smooth(1.05, 0.75, d_ring) * 0.0
    sand = np.maximum(smooth(0.45, 0.0, d_out) * smooth(-1.6, -2.4, hf), lag.astype(np.float32))
    sand = np.maximum(sand, smooth(1.0, 0.55, d_pool))
    water_any = (in_river | lag | (d_pool < 0.7))
    near_w = ndi.distance_transform_edt(~water_any) / RES
    moss = smooth(0.9, 0.0, near_w) * 0.6
    return dict(grid=g, X=X, Y=Y, hf=hf, body=body, path=np.clip(path, 0, 1), sand=np.clip(sand, 0, 1),
                moss=np.clip(moss, 0, 1), mound_r=mound_r, river_pts=river_pts, river_hw=river_hw,
                river_len=river_len, lagoon=lag, pool=(pool_c, 0.75, POOL_Z), pads=pads, z_bigtree=z_bt,
                hill_top=float(hill_h.max()), in_river=in_river, d_ring=d_ring)


# ============================================================================= 2. mesh
def outline(D, n=360):
    """island outline as radius R(theta) around the mound centre: at least 1.7 m outside the tile ring,
    at most 4.2 m; within that, the v1 island shape (opened so palm fronds and thin bits do not count)"""
    g = D["grid"]
    body = ndi.binary_opening(D["body"], structure=terrain.disk(1.0))
    tiles, _ = tiles_blender()
    th = np.linspace(-np.pi, np.pi, n, endpoint=False)
    R = np.zeros(n)
    R_ring = np.zeros(n)
    loop = np.vstack([tiles[:, :2], tiles[:1, :2]])
    for i, t in enumerate(th):
        rs = np.arange(0, 16, 0.05)
        x, y = MC[0] + rs * math.cos(t), MC[1] + rs * math.sin(t)
        inside = g.sample(body.astype(np.float32), x, y) > 0.5
        last = np.where(inside)[0]
        R[i] = rs[last.max()] if len(last) else 1.0
        # where does this ray cross the tile loop (farthest crossing)?
        d = np.array([float(polyline_dist(np.array([xx]), np.array([yy]), loop, False)[0][0]) for xx, yy in zip(x[::4], y[::4])])
        R_ring[i] = rs[::4][np.argmin(d + 100 * (rs[::4] < 3.0))]
    R_ring = ndi.gaussian_filter1d(R_ring, 3, mode="wrap")
    R = np.clip(ndi.gaussian_filter1d(R, 3, mode="wrap"), R_ring + 1.7, R_ring + 4.2)
    R = ndi.gaussian_filter1d(R, 4, mode="wrap")
    D["_R_ring"] = (th, R_ring)
    return th, R


def sample_h(D, x, y):
    return D["grid"].sample(D["hf"], x, y)


def build_mesh(D):
    th_o, R_o = outline(D)

    def R_at(t):
        return np.interp(np.mod(t + np.pi, 2 * np.pi) - np.pi, th_o, R_o, period=2 * np.pi)

    Rmax = R_o.max()
    verts, cols, faces = [], [], []
    rings = []  # list of (start index, count, thetas)
    # --- top: concentric rings at fractions of R(theta)
    n_r = int(Rmax / SPACING)
    fr = np.linspace(0.025, 1.0, n_r)
    verts.append((MC[0], MC[1], float(sample_h(D, MC[0], MC[1]))))
    for f in fr:
        n = max(8, int(2 * np.pi * f * np.mean(R_o) / SPACING))
        t = np.linspace(-np.pi, np.pi, n, endpoint=False) + (0.5 * (len(rings) % 2)) * (2 * np.pi / n)
        Rt = R_at(t)
        x, y = MC[0] + f * Rt * np.cos(t), MC[1] + f * Rt * np.sin(t)
        z = sample_h(D, x, y)
        # rounded rim: the last 0.45 m drop a little
        edge = (1 - f) * Rt
        z = z - 0.22 * smooth(0.45, 0.0, edge)
        start = len(verts)
        verts += list(zip(x, y, z))
        rings.append((start, n, np.mod(t + np.pi, 2 * np.pi)))
    # centre fan
    s0, n0, _ = rings[0]
    for k in range(n0):
        faces.append((0, s0 + k, s0 + (k + 1) % n0))
    # stitch rings
    def stitch(a, b):
        sa, na, ta = a
        sb, nb, tb = b
        oa, ob = np.argsort(ta), np.argsort(tb)
        ia = ib = 0
        tri = []
        A = [sa + i for i in oa] + [sa + oa[0]]
        B = [sb + i for i in ob] + [sb + ob[0]]
        TA = list(ta[oa]) + [ta[oa[0]] + 2 * np.pi]
        TB = list(tb[ob]) + [tb[ob[0]] + 2 * np.pi]
        while ia < na or ib < nb:
            if ib >= nb or (ia < na and TA[ia + 1] < TB[ib + 1]):
                tri.append((A[ia], B[ib], A[ia + 1]))  # counter-clockwise from above -> normal up
                ia += 1
            else:
                tri.append((A[ia], B[ib], B[ib + 1]))
                ib += 1
        return tri
    for a, b in zip(rings[:-1], rings[1:]):
        faces += stitch(a, b)
    top_count = len(verts)
    # --- walls: rings below the rim, layered (strata) and blocky, shrinking into a cone
    s_rim, n_rim, t_rim = rings[-1]
    rim = np.array(verts[s_rim:s_rim + n_rim])
    z_rim = rim[:, 2]
    t_w = np.mod(t_rim, 2 * np.pi) - np.pi
    R_rim = np.hypot(rim[:, 0] - MC[0], rim[:, 1] - MC[1])
    arc = np.cumsum(np.r_[0, np.hypot(np.diff(rim[:, 0], append=rim[0, 0]), np.diff(rim[:, 1], append=rim[0, 1]))[:-1]])
    # blocky columns: piecewise-constant radial offsets every ~1.1 m of arc, lightly smoothed
    block = np.floor(arc / 1.1).astype(int)
    blk_off = rng.uniform(-0.28, 0.22, block.max() + 2)
    col_off = ndi.gaussian_filter1d(blk_off[block], 0.6, mode="wrap")
    z_top = float(z_rim.min())
    bottom = z_top - 9.5
    strata_z = [z_top - 0.25]
    while strata_z[-1] > bottom + 3.5:
        strata_z.append(strata_z[-1] - rng.uniform(0.75, 1.25))
    levels = []
    for k, zs in enumerate(strata_z):
        off = rng.uniform(-0.18, 0.12)
        levels.append((zs + 0.08, off))
        levels.append((zs - 0.08, off - rng.uniform(0.05, 0.14)))  # ledge: the band below steps inward
    wall_rings = []
    # separate first wall ring just under and slightly outside the grass rim: hard grass/rock edge, no shared normals
    # ring 0: exact copy of the grass rim (separate vertices -> hard edge, no gap); ring 1: small overhanging lip
    start0 = len(verts)
    verts += list(zip(rim[:, 0], rim[:, 1], z_rim))
    start = len(verts)
    verts += list(zip(rim[:, 0] + 0.07 * np.cos(t_w), rim[:, 1] + 0.07 * np.sin(t_w), z_rim - 0.14))
    for i in range(n_rim):
        a, b = start0 + i, start0 + (i + 1) % n_rim
        c, d = start + i, start + (i + 1) % n_rim
        faces.append((a, c, b))
        faces.append((b, c, d))
    prev = (start, n_rim)
    for k, (zw, off) in enumerate(levels):
        depth = (z_top - zw) / (z_top - bottom)
        shrink = 1 - 0.18 * depth - 0.72 * smooth(0.35, 1.0, depth) ** 1.2
        jitter = col_off * (1 - 0.6 * depth) + off
        rr = np.maximum(R_rim * shrink + jitter, 0.3)
        x = MC[0] + rr * np.cos(t_w)
        y = MC[1] + rr * np.sin(t_w)
        wob = ndi.gaussian_filter1d(rng.normal(0, 0.22, n_rim), 3, mode="wrap") * min(1.0, 0.3 + depth * 3)
        z = z_rim - (z_top - zw) - 0.1 + wob
        start = len(verts)
        verts += list(zip(x, y, z))
        wall_rings.append(start)
        for i in range(n_rim):
            a, b = prev[0] + i, prev[0] + (i + 1) % n_rim
            c, d = start + i, start + (i + 1) % n_rim
            faces.append((a, c, b))
            faces.append((b, c, d))
        prev = (start, n_rim)
    # cone tip
    tip = len(verts)
    verts.append((MC[0] + 0.3, MC[1] - 0.6, float(np.mean(z_rim)) - (z_top - bottom) - 1.2))
    for i in range(n_rim):
        faces.append((prev[0] + i, tip, prev[0] + (i + 1) % n_rim))
    V = np.array(verts, np.float64)
    Fc = np.array(faces, np.int64)
    depth = np.zeros(len(V))
    for k, st in enumerate([s_rim + 0] + []):
        pass
    # depth below the local rim for wall vertices (rings of n_rim after the top)
    wstart = top_count  # first wall ring = the copied rim
    nw = (len(V) - 1 - wstart) // n_rim
    for k in range(nw):
        sl = slice(wstart + k * n_rim, wstart + (k + 1) * n_rim)
        depth[sl] = z_rim - V[sl, 2]
    D["_wall_depth"] = depth
    log("[mesh] terrain %d verts, %d triangles (top %d verts)" % (len(V), len(Fc), top_count))
    tri = V[Fc]
    fn = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    top = np.all(Fc < top_count, axis=1)
    up_ratio = float((fn[top][:, 2] > 0).mean())
    cen = tri.mean(1)
    outward = np.sum(fn[~top][:, :2] * (cen[~top][:, :2] - MC), axis=1) > 0
    log("[mesh] top faces pointing up: %.1f%%, wall faces pointing out: %.1f%%" % (100 * up_ratio, 100 * outward.mean()))
    assert up_ratio > 0.98, "terrain top faces are flipped"
    return V, Fc, top_count, dict(z_top=z_top, bottom=bottom, tip=V[tip])


def plateau_drum(D, n=220):
    """castle plateau as its own mesh: cobbled top disc (z = PLATEAU_Z), stone wall down into the river / plaza,
    a low parapet with a gap at the front and four steps down to the approach path.
    Returns verts, faces and a per-vertex material id (0 = cobble top, 1 = stone wall)."""
    t = np.linspace(-np.pi, np.pi, n, endpoint=False)
    R = D["mound_r"](t) + 0.25
    ct, st_ = np.cos(t), np.sin(t)
    ox, oy = MC[0] + R * ct, MC[1] + R * st_
    ground = np.array([min(float(sample_h(D, xx + o * c, yy + o * s_)) for o in (0.1, 0.35, 0.7, 1.0))
                       for xx, yy, c, s_ in zip(ox, oy, ct, st_)])
    ground = ndi.gaussian_filter1d(ndi.minimum_filter1d(ground, 9, mode="wrap"), 2.0, mode="wrap")
    zb_ = np.minimum(ground - 0.35, PLATEAU_Z - 0.5)
    verts, faces, mat = [], [], []

    def ring(rad, z):
        st0 = len(verts)
        for k in range(n):
            verts.append((MC[0] + rad[k] * ct[k], MC[1] + rad[k] * st_[k], z[k] if np.ndim(z) else z))
        return st0

    def band(a, b, m, skip=None):
        for k in range(n):
            if skip is not None and skip[k]:
                continue
            k1 = (k + 1) % n
            faces.append((a + k, b + k, b + k1))
            faces.append((a + k, b + k1, a + k1))
            mat.extend([m, m])

    r_out = R
    r_in = R - 0.12
    b0 = ring(r_out, zb_)                         # wall bottom (outside)
    b1 = ring(r_out, np.full(n, PLATEAU_Z - 0.04))  # rounded top edge
    b3 = ring(r_in, np.full(n, PLATEAU_Z))
    band(b0, b1, 1)
    band(b1, b3, 1)
    # cobbled top: concentric rings to the centre
    prev = b3
    for f in (0.8, 0.6, 0.4, 0.2):
        cur = ring(r_in * f, np.full(n, PLATEAU_Z))
        band(prev, cur, 0)
        prev = cur
    c = len(verts)
    verts.append((MC[0], MC[1], PLATEAU_Z))
    for k in range(n):
        faces.append((prev + k, c, prev + (k + 1) % n))
        mat.append(0)
    # front stairs: four blocks from the plateau down to the approach path
    tf = -np.pi / 2
    dirx, diry = math.cos(tf), math.sin(tf)
    px, py = -diry, dirx  # sideways
    r0 = float(D["mound_r"](np.array([tf]))[0]) + 0.25
    z_low = float(sample_h(D, MC[0] + dirx * (r0 + 1.8), MC[1] + diry * (r0 + 1.8)))
    steps = 5
    for k in range(steps):
        z_top_k = PLATEAU_Z - (PLATEAU_Z - z_low) * (k + 1) / (steps + 0.5)
        d0, d1 = r0 - 0.05 + k * 0.36, r0 + 0.31 + k * 0.36
        hw = 0.85
        cx0, cy0 = MC[0] + dirx * d0, MC[1] + diry * d0
        cx1, cy1 = MC[0] + dirx * d1, MC[1] + diry * d1
        zb2 = z_low - 0.3
        box = [(cx0 + px * hw, cy0 + py * hw), (cx0 - px * hw, cy0 - py * hw),
               (cx1 - px * hw, cy1 - py * hw), (cx1 + px * hw, cy1 + py * hw)]
        st0 = len(verts)
        for (bx, by) in box:
            verts.append((bx, by, zb2))
        for (bx, by) in box:
            verts.append((bx, by, z_top_k))
        for a_, b_, c_, d_ in ((4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            faces.append((st0 + a_, st0 + b_, st0 + c_))
            faces.append((st0 + a_, st0 + c_, st0 + d_))
            mat.extend([1, 1])
    return np.array(verts), np.array(faces), np.array(mat)


# ============================================================================= 3. vertex colours + AO
def bake_vertex_data(D, V, Fc, top_count, extra_occluders):
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    g = D["grid"]
    x, y = V[:, 0], V[:, 1]
    path = g.sample(D["path"], x, y)
    sand = g.sample(D["sand"], x, y)
    moss = g.sample(D["moss"], x, y)
    is_top = np.arange(len(V)) < top_count
    path *= is_top
    sand *= is_top
    # normals
    nrm = np.zeros_like(V)
    tri = V[Fc]
    fn = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    for k in range(3):
        np.add.at(nrm, Fc[:, k], fn)
    nrm /= np.maximum(np.linalg.norm(nrm, axis=1)[:, None], 1e-9)
    # moss on the upper wall (just under the grass edge)
    wall = ~is_top
    z_rim_local = V[:, 2]
    moss = np.maximum(moss, wall * smooth(1.3, 0.15, D["_wall_depth"]) * 0.8)
    # AO: hemisphere rays against the terrain + props + walls
    allv = [V]
    allf = [Fc]
    off = len(V)
    for ov, of in extra_occluders:
        allv.append(ov)
        allf.append(of + off)
        off += len(ov)
    bvh = BVHTree.FromPolygons(np.concatenate(allv).tolist(), np.concatenate(allf).tolist())
    dirs = []
    golden = math.pi * (3 - math.sqrt(5))
    NR = 28
    for i in range(NR):
        zc = 1 - (i + 0.5) / NR
        rad = math.sqrt(1 - zc * zc)
        dirs.append((math.cos(golden * i) * rad, math.sin(golden * i) * rad, zc))
    dirs = np.array(dirs)
    ao = np.ones(len(V))
    for vi in range(len(V)):
        n = nrm[vi]
        # orient the hemisphere around the vertex normal
        up = np.array([0, 0, 1.0]) if abs(n[2]) < 0.9 else np.array([1.0, 0, 0])
        tx = np.cross(up, n)
        tx /= np.linalg.norm(tx)
        ty = np.cross(n, tx)
        o = Vector(V[vi] + n * 0.02)
        occ = 0.0
        for d in dirs:
            w = tx * d[0] + ty * d[1] + n * d[2]
            hit = bvh.ray_cast(o, Vector(w), 2.5)
            if hit[0] is not None:
                occ += (1 - hit[3] / 2.5) ** 0.7
        ao[vi] = 1 - occ / NR
    ao = np.clip(ao, 0, 1) ** 1.3
    C = np.stack([ao, np.clip(path, 0, 1), np.clip(sand, 0, 1), np.clip(moss, 0, 1)], 1)
    return C


def make_object(name, V, Fc, C=None, recalc=False):
    import bmesh
    import bpy
    me = bpy.data.meshes.new(name)
    me.from_pydata(V.tolist(), [], Fc.tolist())
    me.update()
    if recalc:  # make all faces point outward (consistent winding)
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
    for p in me.polygons:
        p.use_smooth = True
    if C is not None:
        ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        ca.data.foreach_set("color", C.astype(np.float32).ravel())
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    mat = bpy.data.materials.new(name + "_mat")
    me.materials.append(mat)
    return ob


def main():
    import bpy
    r = terrain.raster_v1()
    D = design(r)
    V, Fc, top_count, info = build_mesh(D)
    D["_z_top"] = info["z_top"]
    WV, WF, WM = plateau_drum(D)
    # rough occluders for AO: hero prop volumes (cylinders) at their places
    occ = [(WV, WF)]
    for p in layout.HERO:
        if p["name"] in ("barca", "pod"):
            continue
        z0 = D["pads"].get(p.get("id", p["name"]), PLATEAU_Z if p["name"] == "castel" else 0.0)
        hgt = {"castel": 4.5, "moara": 3.6, "portal": 2.6, "piata": 2.4, "atelier": 2.6, "debarcader": 0.4}[p["name"]]
        n = 16
        t = np.linspace(0, 2 * np.pi, n, endpoint=False)
        rr = p["r"] * 0.85
        ring0 = np.stack([p["x"] + rr * np.cos(t), p["y"] + rr * np.sin(t), np.full(n, z0)], 1)
        ring1 = ring0 + [0, 0, hgt]
        vv = np.concatenate([ring0, ring1, [[p["x"], p["y"], z0 + hgt]]])
        ff = []
        for i in range(n):
            j = (i + 1) % n
            ff += [(i, j, n + j), (i, n + j, n + i), (n + i, n + j, 2 * n)]
        occ.append((vv, np.array(ff)))
    log("[ao] baking ...")
    C = bake_vertex_data(D, V, Fc, top_count, occ)
    log("[ao] done; AO min %.2f median %.2f" % (C[:, 0].min(), np.median(C[:, 0])))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    t_ob = make_object("Teren", V, Fc, C)
    # drum: vertex colour R = AO-ish (darker low down), G = 1 on the cobbled top (path), A = moss near the water
    WC = np.zeros((len(WV), 4))
    WC[:, 0] = np.clip(0.55 + 0.45 * smooth(WL_RIVER - 0.3, PLATEAU_Z + 0.2, WV[:, 2]), 0, 1)
    top_v = np.zeros(len(WV), bool)
    top_v[np.unique(WF[WM == 0])] = True
    WC[:, 1] = 1.0  # stone everywhere: cobble where flat, rock/stone wall where steep
    WC[:, 3] = smooth(WL_RIVER + 0.6, WL_RIVER, WV[:, 2]) * 0.8
    w_ob = make_object("Platou", WV, WF, WC, recalc=True)
    for ob in (t_ob, w_ob):
        ob.select_set(True)
    path = os.path.join(OUT_MODELS, "teren.glb")
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_yup=True, export_apply=True,
                              export_vertex_color="ACTIVE", export_normals=True, export_materials="PLACEHOLDER")
    log("[glb]", path, f"{os.path.getsize(path) / 1e6:.2f} MB")
    # data for the scatter / water / props scripts
    np.savez_compressed(os.path.join(BUILD, "teren.npz"), hf=D["hf"], lo=D["grid"].lo, hi=D["grid"].hi,
                        path=D["path"], sand=D["sand"], body=D["body"], in_river=D["in_river"], lagoon=D["lagoon"],
                        d_ring=D["d_ring"], V=V, F=Fc, top_count=top_count, river_pts=D["river_pts"],
                        river_hw=D["river_hw"])
    write_info(D, info)


def write_info(D, info):
    rp = D["river_pts"]
    lines = ["# Insula 1 v2: date despre teren și apă (generat de blender/insula_v2/build_terrain.py).",
             "# Coordonate Godot: metri, Y în sus, Z spre cameră.", "extends RefCounted", "",
             f"const NIVEL_RAU := {WL_RIVER:.3f}", f"const NIVEL_LAGUNA := {WL_LAGOON:.3f}",
             f"const PLATOU_CASTEL := {PLATEAU_Z:.3f}", f"const VARF_CON := {gd_vec3(info['tip'])}", ""]
    lines.append("# râul: linia de mijloc, de la izvor (dreapta-sus) la iazul din fața castelului; jumătatea lățimii")
    lines.append("const RAU_PUNCTE: Array[Vector3] = [")
    lines += [f"\t{gd_vec3((p[0], p[1], WL_RIVER))}," for p in rp]
    lines.append("]")
    lines.append("const RAU_LATIME: Array[float] = [" + ", ".join(f"{2 * w:.2f}" for w in D["river_hw"]) + "]")
    # lagoon outline (polygon, counter-clockwise from above)
    from skimage import measure
    cs = measure.find_contours(D["lagoon"].astype(np.float32), 0.5)
    c = max(cs, key=len)
    g = D["grid"]
    xs, ys = g.xy(c[:, 1] + 0.5, c[:, 0] + 0.5)
    step = max(1, len(xs) // 48)
    poly = np.stack([xs[::step], ys[::step]], 1)
    lines.append("const LAGUNA_CONTUR: Array[Vector3] = [")
    lines += [f"\t{gd_vec3((p[0], p[1], WL_LAGOON))}," for p in poly]
    lines.append("]")
    pc, pr, pz = D["pool"]
    lines.append(f"const IAZ_DEAL := {gd_vec3((pc[0], pc[1], pz))}")
    lines.append(f"const IAZ_DEAL_RAZA := {pr:.2f}")
    # waterfalls: top point, bottom point, width
    falls = []
    hill = layout.HILL
    falls.append(("deal", (pc[0] + 0.05, pc[1] + 0.95, D["hill_top"] - 0.15), (pc[0], pc[1] + 0.25, pz), 0.9))
    lp = D["river_pts"][len(D["river_pts"]) // 3]
    falls.append(("rau_stanga", (lp[0] - 1.6, lp[1] + 0.9, 0.62), (lp[0] - 0.55, lp[1] + 0.3, WL_RIVER), 0.75))
    falls.append(("fata_dreapta", (5.0, -8.55, -0.9), (5.6, -9.4, -9.0), 1.5))
    lag_front = poly[np.argmin(poly[:, 1])]
    falls.append(("laguna", (lag_front[0], lag_front[1] - 0.05, WL_LAGOON), (lag_front[0], lag_front[1] - 0.7, -10.0), 1.1))
    lines.append("# cascade: nume, sus, jos, lățime")
    lines.append("const CASCADE := [")
    for n, a, b, w in falls:
        lines.append(f'\t["{n}", {gd_vec3(a)}, {gd_vec3(b)}, {w:.2f}],')
    lines.append("]")
    lines.append("# înălțimea solului sub clădirile mari")
    lines.append("const BAZE := {")
    for k, v in D["pads"].items():
        lines.append(f'\t"{k}": {v:.3f},')
    lines.append(f'\t"castel": {PLATEAU_Z:.3f},')
    lines.append(f'\t"copac_mare": {D["z_bigtree"]:.3f},')
    lines.append("}")
    with open(os.path.join(OUT_DATA, "teren_info.gd"), "w") as f:
        f.write("\n".join(lines) + "\n")
    log("[data] teren_info.gd")


if __name__ == "__main__":
    main()
