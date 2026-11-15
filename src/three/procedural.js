import * as THREE from 'three'
import { stoneTex, roofTex, cobTex, rockTex, grassTex } from './textures'

// Geometrie procedurală portată din buble.html. Folosită ca variantă implicită
// când în public/models nu există un GLB pentru piesa respectivă.

let sd = 7
const rnd = () => (sd = (sd * 16807) % 2147483647) / 2147483647
export const seeded = (s) => {
  sd = s
  return rnd
}

const M = (c, o = {}) => new THREE.MeshStandardMaterial({ color: c, roughness: 0.6, ...o })
const add = (p, g, m, x = 0, y = 0, z = 0) => {
  const o = new THREE.Mesh(g, m)
  o.position.set(x, y, z)
  o.castShadow = o.receiveShadow = true
  p.add(o)
  return o
}
const cyl = (a, b, h, s = 24) => new THREE.CylinderGeometry(a, b, h, s)
const sph = (r, w = 24, h = 16) => new THREE.SphereGeometry(r, w, h)
const bx = (w, h, d) => new THREE.BoxGeometry(w, h, d)
const tor = (r, t) => new THREE.TorusGeometry(r, t, 8, 32)

// ---- materiale comune ----
export const MAT = {
  cream: M(0xf3e6cf, { map: stoneTex }),
  gold: M(0xf2b630, { metalness: 0.8, roughness: 0.3 }),
  teal: M(0x20a8a6, { metalness: 0.3, roughness: 0.35, map: roofTex }),
  vio: M(0x6d3fc0),
  stone: M(0xd9c7a3, { map: cobTex }),
  brown: M(0x7a4a2a),
  green: M(0x4ea04a),
  glass: M(0xbfeeff, { transparent: true, opacity: 0.3, roughness: 0.1, side: THREE.DoubleSide, depthWrite: false }),
  warm: M(0xffd27a, { emissive: 0xffa030, emissiveIntensity: 1.4 }),
  ped: M(0xcdb690, { map: stoneTex }),
  iv1: M(0x3f9a44),
  iv2: M(0x5cba50),
  gem: M(0x7ffff0, { emissive: 0x20d8c8, emissiveIntensity: 1.6 }),
  sky: M(0x1a1a66, { emissive: 0x5b3fd0, emissiveIntensity: 1.2 }),
  rock: M(0x8a7a8e, { flatShading: true, roughness: 0.9, map: rockTex }),
  grass: M(0x6fbf4a, { roughness: 0.9, map: grassTex }),
  pink: M(0xff6fa8),
  lilac: M(0xb07cff),
}
const { cream, gold, teal, vio, stone, brown, green, glass, warm, ped, iv1, iv2 } = MAT

const dome = (p, r, x, y, z = 0, m = teal) => {
  const d = add(p, new THREE.SphereGeometry(r, 24, 12, 0, Math.PI * 2, 0, Math.PI / 2), m, x, y, z)
  add(p, cyl(r * 0.07, r * 0.07, r * 0.5, 8), gold, x, y + r + 0.15, z)
  add(p, sph(r * 0.13, 8, 8), gold, x, y + r + 0.42, z)
  return d
}
const onion = (p, r, x, y, z = 0, m = teal) => {
  const pts = [
    [r, 0],
    [r * 1.06, r * 0.28],
    [r * 0.96, r * 0.62],
    [r * 0.5, r * 0.95],
    [r * 0.14, r * 1.2],
    [0, r * 1.45],
  ].map((a) => new THREE.Vector2(a[0], a[1]))
  add(p, new THREE.LatheGeometry(pts, 28), m, x, y, z)
  add(p, tor(r * 1.06, 0.04), gold, x, y + r * 0.28, z).rotation.x = Math.PI / 2
  add(p, tor(r * 0.96, 0.035), gold, x, y + r * 0.62, z).rotation.x = Math.PI / 2
  add(p, tor(r, 0.05), gold, x, y + 0.02, z).rotation.x = Math.PI / 2
  add(p, cyl(r * 0.04, r * 0.04, r * 0.6, 6), gold, x, y + r * 1.6, z)
  add(p, sph(r * 0.12, 8, 8), gold, x, y + r * 1.92, z)
}
const arch = (p, x, y, z, w = 0.3, h = 0.55, ry = 0, m = warm) => {
  const g = new THREE.Group()
  g.position.set(x, y, z)
  g.rotation.y = ry
  add(g, bx(w, h, 0.08), m)
  add(g, new THREE.CylinderGeometry(w / 2, w / 2, 0.08, 12, 1, false, Math.PI / 2, Math.PI), m, 0, h / 2).rotation.x = Math.PI / 2
  add(g, new THREE.TorusGeometry(w / 2 + 0.03, 0.025, 5, 12, Math.PI), gold, 0, h / 2, 0.045)
  add(g, bx(w + 0.1, 0.05, 0.1), gold, 0, -h / 2, 0.04)
  p.add(g)
}
const cor = (p, w, d, y) => add(p, bx(w + 0.2, 0.1, d + 0.2), ped, 0, y, 0)
const colm = (p, x, z, h) => {
  add(p, cyl(0.12, 0.14, h, 10), cream, x, h / 2, z)
  add(p, cyl(0.19, 0.19, 0.08, 10), gold, x, h, z)
  add(p, cyl(0.19, 0.19, 0.08, 10), gold, x, 0.04, z)
}
const ivy = (p, x, y, z, n = 5) => {
  for (let i = 0; i < n; i++) add(p, sph(0.12 + rnd() * 0.1, 6, 5), i % 2 ? iv1 : iv2, x + (rnd() - 0.5) * 0.6, y - rnd() * 0.9, z + rnd() * 0.1)
}
const flag = (p, x, y, z) => {
  add(p, cyl(0.025, 0.025, 0.9, 5), gold, x, y + 0.45, z)
  add(p, bx(0.5, 0.26, 0.02), vio, x + 0.27, y + 0.75, z)
}

const BUILDERS = {
  palat(g) {
    add(g, bx(5.4, 0.25, 2.8), ped, 0, 0.12, 0.25)
    add(g, bx(4.6, 1.9, 1.9), cream, 0, 1.2, 0)
    cor(g, 4.6, 1.9, 2.17)
    add(g, cyl(1.35, 1.45, 3.2), cream, 0, 1.85, 0.1)
    add(g, tor(1.4, 0.07), gold, 0, 3, 0.1).rotation.x = Math.PI / 2
    onion(g, 1.4, 0, 3.45, 0.1)
    flag(g, 0, 5.95, 0.1)
    for (const s of [-1, 1]) {
      add(g, cyl(0.8, 0.85, 2.8), cream, s * 2.2, 1.5, 0)
      add(g, tor(0.83, 0.05), gold, s * 2.2, 2.7, 0).rotation.x = Math.PI / 2
      onion(g, 0.9, s * 2.2, 2.85)
      flag(g, s * 2.2, 4.5, 0)
      arch(g, s * 2.2, 1.8, 0.86, 0.3, 0.6)
      arch(g, s * 1.4, 1.4, 0.96, 0.3, 0.55)
      add(g, bx(0.34, 1, 0.05), vio, s * 1.15, 1.4, 0.98)
      arch(g, s * 0.5, 2.3, 1.4, 0.28, 0.5, s * 0.37)
      colm(g, s * 0.75, 1.6, 1.5)
      ivy(g, s * 1.6, 1.7, 1, 6)
      ivy(g, s * 2.2, 1.9, 0.85, 4)
    }
    arch(g, 0, 0.9, 1.55, 0.8, 1.2)
    add(g, sph(0.22, 10, 8), MAT.gem, 0, 2, 1.58)
    for (let i = 0; i < 3; i++) add(g, bx(2.2, 0.1, 0.45), stone, 0, 0.05 + i * 0.1, 2.3 - i * 0.4)
  },
  obs(g) {
    add(g, cyl(1.55, 1.65, 0.3), ped, 0, 0.15, 0)
    add(g, cyl(1.3, 1.4, 1.7), cream, 0, 1.15, 0)
    add(g, tor(1.35, 0.07), gold, 0, 2, 0).rotation.x = Math.PI / 2
    add(g, new THREE.SphereGeometry(1.3, 28, 14, 0, Math.PI * 2, 0, Math.PI / 2), vio, 0, 2, 0)
    add(g, bx(0.5, 1.1, 0.1), MAT.sky, 0, 2.65, 1.15).rotation.x = -0.5
    for (let i = 0; i < 16; i++) {
      const a = rnd() * 6.28,
        b = 0.15 + rnd() * 1.1
      add(g, sph(0.04, 5, 4), warm, Math.sin(b) * Math.cos(a) * 1.32, 2 + Math.cos(b) * 1.32, Math.sin(b) * Math.sin(a) * 1.32)
    }
    add(g, cyl(0.18, 0.24, 2.2, 16), gold, 0.45, 3, 0.7).rotation.set(-0.9, 0, -0.45)
    add(g, bx(2.4, 1.1, 1.2), cream, 0, 0.55, 1.75)
    arch(g, 0, 0.5, 2.36, 0.6, 0.8)
    for (let i = 0; i < 5; i++) add(g, bx(0.5, 0.08, 0.8), i % 2 ? vio : cream, -1 + i * 0.5, 1.1, 2.35).rotation.x = 0.45
    for (const s of [-1, 1]) arch(g, s * 0.95, 1.5, 0.97, 0.28, 0.5, s * 0.7)
    ivy(g, -1.3, 1.7, 0.9, 5)
  },
  turn(g) {
    add(g, cyl(1, 1.1, 0.3), ped, 0, 0.15, 0)
    add(g, cyl(0.8, 0.95, 3.6), cream, 0, 2.1, 0)
    for (const y of [1.5, 2.9]) add(g, tor(0.99 - y * 0.0417, 0.06), gold, 0, y, 0).rotation.x = Math.PI / 2
    add(g, cyl(1.05, 1.05, 0.1), gold, 0, 3.9, 0)
    onion(g, 1, 0, 3.95)
    flag(g, 0, 5.8, 0)
    arch(g, 0, 0.85, 0.97, 0.5, 0.9, 0, brown)
    add(g, bx(0.5, 1.1, 0.05), vio, 0, 1.95, 0.9)
    arch(g, 0, 3, 0.86, 0.26, 0.55)
    ivy(g, 0.5, 2.2, 0.8, 6)
  },
  mag(g) {
    add(g, bx(3, 0.2, 2.4), ped, 0, 0.1, 0)
    add(g, bx(2.8, 1.6, 2.2), cream, 0, 1, 0)
    cor(g, 2.8, 2.2, 1.82)
    add(g, cyl(0, 2.2, 1.2, 4), teal, 0, 2.4, 0).rotation.y = Math.PI / 4
    add(g, sph(0.12, 8, 8), gold, 0, 3.05, 0)
    for (let i = 0; i < 6; i++) add(g, bx(0.47, 0.08, 1), i % 2 ? vio : cream, -1.2 + i * 0.48, 1.55, 1.55).rotation.x = 0.45
    add(g, bx(1.7, 0.85, 0.1), warm, 0, 0.85, 1.12)
    add(g, bx(1.8, 0.06, 0.12), gold, 0, 1.3, 1.12)
    add(g, bx(1.8, 0.06, 0.12), gold, 0, 0.4, 1.12)
    arch(g, 1.12, 0.7, 1.13, 0.3, 0.8, 0, brown)
    add(g, cyl(0.2, 0.15, 0.3, 8), brown, -1.2, 0.15, 1.7)
    add(g, sph(0.3, 8, 6), green, -1.2, 0.5, 1.7)
    add(g, sph(0.1, 6, 5), MAT.pink, -1.1, 0.75, 1.75)
    add(g, bx(0.4, 0.4, 0.4), brown, 1.2, 0.2, 1.7)
    ivy(g, -1.42, 1.5, 0, 5)
  },
  sera(g) {
    add(g, cyl(1.8, 1.9, 0.3), ped, 0, 0.15, 0)
    const gl = add(g, new THREE.SphereGeometry(1.65, 28, 14, 0, Math.PI * 2, 0, Math.PI / 2), glass, 0, 0.3, 0)
    gl.castShadow = false
    for (let i = 0; i < 4; i++) add(g, new THREE.TorusGeometry(1.65, 0.035, 6, 24, Math.PI), gold, 0, 0.3, 0).rotation.y = (i * Math.PI) / 4
    add(g, tor(1.65, 0.045), gold, 0, 0.3, 0).rotation.x = Math.PI / 2
    add(g, tor(1.35, 0.035), gold, 0, 1.25, 0).rotation.x = Math.PI / 2
    add(g, tor(0.7, 0.035), gold, 0, 1.8, 0).rotation.x = Math.PI / 2
    add(g, sph(0.1, 8, 8), gold, 0, 1.98, 0)
    add(g, sph(0.28, 10, 8), warm, 0, 0.75, 0)
    for (let i = 0; i < 10; i++) {
      const a = i * 0.63,
        r = 0.5 + (i % 3) * 0.4,
        x = Math.cos(a) * r,
        z = Math.sin(a) * r
      add(g, sph(0.28 + (i % 2) * 0.1, 8, 6), i % 2 ? iv1 : iv2, x, 0.55 + (i % 3) * 0.2, z)
      add(g, sph(0.1, 6, 5), i % 3 ? MAT.pink : MAT.lilac, x, 0.85 + (i % 3) * 0.2, z)
    }
    arch(g, 0, 0.75, 1.66, 0.5, 0.8, 0, brown)
  },
}

export function buildBuilding(id) {
  seeded(7 + id.length * 31)
  const g = new THREE.Group()
  BUILDERS[id](g)
  return g
}

export function lantern(p, x, z) {
  add(p, cyl(0.06, 0.08, 0.8, 8), gold, x, 0.4, z)
  add(p, sph(0.15, 8, 8), warm, x, 0.9, z)
}

// Felinarele adăugate la fiecare nivel de clădire (max 4).
export const LEVEL_SPOTS = [
  [-1.6, 2.6],
  [1.6, 2.6],
  [-2.9, 1.2],
  [2.9, 1.2],
]
export function buildLevelLanterns(level) {
  const g = new THREE.Group()
  for (let i = 0; i < level - 1 && i < LEVEL_SPOTS.length; i++) lantern(g, LEVEL_SPOTS[i][0], LEVEL_SPOTS[i][1])
  return g
}

// ---- terenul insulei (stâncă + iarbă + cristale) ----
export function buildTerrain() {
  seeded(7)
  const isl = new THREE.Group()
  const rg = new THREE.CylinderGeometry(7, 1.8, 6.5, 14, 5),
    pa = rg.attributes.position
  // Perturbă vârfurile partajate identic, ca să nu apară crăpături între fețe.
  const off = new Map()
  for (let i = 0; i < pa.count; i++)
    if (pa.getY(i) < 3) {
      const k = `${pa.getX(i).toFixed(3)},${pa.getY(i).toFixed(3)},${pa.getZ(i).toFixed(3)}`
      if (!off.has(k)) off.set(k, [(rnd() - 0.5) * 0.8, (rnd() - 0.5) * 0.4, (rnd() - 0.5) * 0.8])
      const o = off.get(k)
      pa.setXYZ(i, pa.getX(i) + o[0], pa.getY(i) + o[1], pa.getZ(i) + o[2])
    }
  rg.computeVertexNormals()
  add(isl, rg, MAT.rock, 0, -3.75, 0)
  add(isl, cyl(7.2, 7, 0.5, 40), MAT.grass, 0, -0.25, 0)
  const crystal = M(0x5fe0e0, { emissive: 0x2bb8b0, emissiveIntensity: 1.3 })
  for (let i = 0; i < 5; i++) {
    const a = i * 1.3 + 0.4,
      k = add(isl, new THREE.ConeGeometry(0.35, 1.4, 5), crystal, Math.cos(a) * 2.2, -5.2, Math.sin(a) * 2.2)
    k.rotation.x = Math.PI
  }
  // rădăcini / liane pe margine și bolovani
  for (let i = 0; i < 16; i++) {
    const a = i * 0.4 + rnd() * 0.3
    add(isl, cyl(0.025, 0.015, 1 + rnd() * 1.6, 4), iv1, Math.cos(a) * 6.6, -0.9 - rnd() * 0.3, Math.sin(a) * 6.6)
  }
  for (let i = 0; i < 7; i++) {
    const a = rnd() * 6.28
    add(isl, new THREE.IcosahedronGeometry(0.4 + rnd() * 0.4, 0), MAT.rock, Math.cos(a) * 6.7, 0.15, Math.sin(a) * 6.7)
  }
  return isl
}

// ---- piața centrală, fântână, vegetație, felinare ----
export function buildPlaza() {
  seeded(11)
  const isl = new THREE.Group()
  const ring = add(isl, new THREE.RingGeometry(2.3, 3.3, 48), stone, 0, 0.02, 0.3)
  ring.rotation.x = -Math.PI / 2
  add(isl, bx(1.8, 0.04, 4.6), stone, 0, 0.02, 5.1)
  add(isl, cyl(1.6, 1.7, 0.5), stone, 0, 0.25, 0.3)
  add(isl, cyl(1.35, 1.35, 0.1), M(0x5fd8ff, { emissive: 0x2aa0d0, emissiveIntensity: 0.6, transparent: true, opacity: 0.85 }), 0, 0.5, 0.3)
  add(isl, cyl(0.18, 0.25, 1.1, 12), stone, 0, 1, 0.3)
  add(isl, cyl(0.75, 0.5, 0.2), stone, 0, 1.5, 0.3)
  const gem = add(isl, new THREE.IcosahedronGeometry(0.25), MAT.gem, 0, 2, 0.3)

  const leafA = M(0x4fae4a, { flatShading: true }),
    leafB = M(0x66c458, { flatShading: true }),
    pine = M(0x2f7a45)
  const tree = (x, z, s, cy) => {
    const g = new THREE.Group()
    g.position.set(x, 0, z)
    add(g, cyl(0.1 * s, 0.15 * s, 1 * s, 6), brown, 0, 0.5 * s, 0)
    if (cy) add(g, new THREE.ConeGeometry(0.45 * s, 2.2 * s, 8), pine, 0, 1.6 * s, 0)
    else {
      add(g, new THREE.IcosahedronGeometry(0.7 * s, 1), leafA, 0, 1.4 * s, 0)
      add(g, new THREE.IcosahedronGeometry(0.5 * s, 1), leafB, 0.3 * s, 1.9 * s, 0.1 * s)
    }
    isl.add(g)
  }
  for (let i = 0; i < 20; i++) {
    const a = rnd() * 6.28,
      r = 5.7 + rnd() * 0.9,
      x = Math.cos(a) * r,
      z = Math.sin(a) * r
    if (Math.abs(x) < 2 && z > 0) continue
    if (Math.abs(Math.abs(x) - 4.4) < 1.2 && z > 4.5) continue
    tree(x, z, 0.8 + rnd() * 0.5, i % 4 === 0)
  }
  // flori: o geometrie instanțiată pe culoare (mai puține apeluri de desenare)
  const fc = [0xff6fa8, 0xb07cff, 0x7fa8ff, 0xffffff]
  const pos = [[], [], [], []]
  for (let i = 0; i < 70; i++) {
    const a = rnd() * 6.28,
      r = 5.9 + rnd() * 0.9,
      x = Math.cos(a) * r,
      z = Math.sin(a) * r
    if (Math.abs(x) < 1.5 && z > 0) continue
    pos[i % 4].push([x, 0.12, z])
  }
  const fg = sph(0.12, 6, 5),
    mtx = new THREE.Matrix4()
  pos.forEach((list, k) => {
    const im = new THREE.InstancedMesh(fg, M(fc[k], { emissive: fc[k], emissiveIntensity: 0.15 }), list.length)
    list.forEach((p, i) => im.setMatrixAt(i, mtx.makeTranslation(p[0], p[1], p[2])))
    im.castShadow = true
    isl.add(im)
  })
  ;[
    [-1.4, 3.3],
    [1.4, 3.3],
    [-1.4, 6],
    [1.4, 6],
  ].forEach((p) => lantern(isl, p[0], p[1]))
  return { group: isl, gem }
}

// ---- insule îndepărtate ----
export function buildFarIsland() {
  const g = new THREE.Group()
  add(g, new THREE.ConeGeometry(2, 3, 7), MAT.rock, 0, -1.5, 0).rotation.x = Math.PI
  add(g, cyl(2.1, 2, 0.3), MAT.grass, 0, 0.1, 0)
  add(g, bx(1, 0.8, 1), cream, 0, 0.6, 0)
  dome(g, 0.7, 0, 1, 0)
  g.traverse((o) => {
    if (o.isMesh) o.castShadow = o.receiveShadow = false
  })
  return g
}

// ---- mascota procedurală ----
export function buildMascot() {
  const ms = new THREE.Group()
  const wh = M(0xfff6e8, { roughness: 0.5 }),
    dk = M(0x2a1a3a),
    shine = M(0xffffff, { emissive: 0xffffff }),
    blush = M(0xff9fb5),
    lens = M(0x2bd4c8, { metalness: 0.5, roughness: 0.2 }),
    leather = M(0xa8703a)
  const body = add(ms, sph(0.7, 24, 16), wh, 0, 0.75, 0)
  body.scale.set(1, 0.95, 0.92)
  for (const s of [-1, 1]) {
    add(ms, sph(0.1, 8, 8), dk, s * 0.23, 0.82, 0.58)
    add(ms, sph(0.03, 6, 6), shine, s * 0.2, 0.86, 0.66)
    add(ms, sph(0.1, 8, 8), blush, s * 0.4, 0.68, 0.52).scale.set(1, 0.6, 0.4)
    add(ms, sph(0.18, 12, 8), lens, s * 0.25, 1.1, 0.5).scale.set(1, 0.8, 0.4)
    add(ms, tor(0.18, 0.04), gold, s * 0.25, 1.1, 0.52)
    add(ms, sph(0.17, 8, 8), wh, s * 0.72, 0.6, 0.1)
    add(ms, sph(0.2, 8, 8), wh, s * 0.3, 0.1, 0.1)
  }
  const mouth = add(ms, sph(0.1, 8, 6), M(0xd8475a), 0, 0.62, 0.64)
  mouth.scale.set(1, 0.5, 0.5)
  add(ms, new THREE.TorusGeometry(0.5, 0.11, 8, 24), vio, 0, 0.45, 0).rotation.x = Math.PI / 2
  add(ms, bx(0.2, 0.5, 0.08), vio, 0.35, 0.25, 0.55).rotation.z = 0.3
  add(ms, bx(0.6, 0.7, 0.3), brown, 0, 0.7, -0.62)
  add(ms, tor(0.5, 0.03), gold, 0, 1.05, 0.05).rotation.x = Math.PI / 2
  add(ms, new THREE.SphereGeometry(0.76, 20, 10, 0, Math.PI * 2, 0, Math.PI * 0.3), brown, 0, 0.75, -0.02)
  add(ms, tor(0.615, 0.05), leather, 0, 1.2, -0.02).rotation.x = Math.PI / 2
  for (const s of [-1, 1]) add(ms, sph(0.2, 8, 6), brown, s * 0.62, 0.95, -0.02).scale.set(0.5, 1, 0.8)
  return { group: ms, mouth }
}
