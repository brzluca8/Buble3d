// Combinare statică: unește meshele care nu se mișcă separat, pe material, într-un singur mesh
// per grup. Reduce draw call-urile (esențial pe telefon). Nodurile din `keep` rămân separate.
import * as THREE from 'three';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

// Materiale identice create separat (ex. M(0xff6fa8) de mai multe ori) devin unul singur.
const matKey = (m) => [m.type, m.color?.getHex(), m.emissive?.getHex(), m.emissiveIntensity, m.roughness, m.metalness,
  m.opacity, m.transparent, m.flatShading, m.side, m.map?.uuid, m.depthWrite].join('|');

export function mergeStatic(root, keep = new Set()) {
  root.updateMatrixWorld(true);
  const inv = new THREE.Matrix4().copy(root.matrixWorld).invert();
  const buckets = new Map(), victims = [];
  const visit = (o) => {
    for (const c of [...o.children]) {
      if (keep.has(c) || c.isGroup && c.userData.id) continue; // obiecte animate / alte grupuri-clădire
      if (c.isMesh && !c.isSkinnedMesh && !c.isInstancedMesh && c.geometry.index) {
        // glow-urile (sprite) atașate mesh-ului se mută pe rădăcină cu aceeași poziție
        for (const s of [...c.children]) if (s.isSprite) { s.applyMatrix4(c.matrixWorld.clone().premultiply(inv)); root.add(s); }
        const g = c.geometry.clone().applyMatrix4(c.matrixWorld.clone().premultiply(inv));
        for (const n of Object.keys(g.attributes)) if (!['position', 'normal', 'uv'].includes(n)) g.deleteAttribute(n);
        const k = matKey(c.material);
        if (!buckets.has(k)) buckets.set(k, { m: c.material, gs: [] });
        buckets.get(k).gs.push(g);
        victims.push(c);
      }
      if (!c.isMesh) visit(c);
    }
  };
  visit(root);
  for (const v of victims) v.removeFromParent();
  // grupurile golite rămân în scenă dar fără copii; le scoatem
  const empty = []; root.traverse((o) => { if (o !== root && o.isGroup && !o.children.length && !keep.has(o)) empty.push(o); });
  empty.forEach((o) => o.removeFromParent());
  for (const { m, gs } of buckets.values()) {
    const merged = mergeGeometries(gs, false);
    if (!merged) continue;
    const mesh = new THREE.Mesh(merged, m);
    mesh.castShadow = mesh.receiveShadow = true;
    mesh.userData.merged = true;
    root.add(mesh);
  }
  return victims.length - buckets.size;
}
