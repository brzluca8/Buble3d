import * as THREE from 'three'
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js'
import { DRACOLoader } from 'three/examples/jsm/loaders/DRACOLoader.js'
import { MeshoptDecoder } from 'three/examples/jsm/libs/meshopt_decoder.module.js'
import available from 'virtual:model-manifest'
import { MODEL_HEIGHT, ISLAND_DIAMETER } from '../data'

// Fișierele .glb găsite în public/models la pornire (vezi vite.config.js).
export const PUBLIC_MODELS = new Set(available)
export const modelUrl = (k) => `${import.meta.env.BASE_URL}models/${k}.glb`

// Decodoarele Draco/Meshopt vin împachetate cu three (fără CDN).
let draco
export function extendLoader(l) {
  draco ??= new DRACOLoader()
  l.setDRACOLoader(draco)
  l.setMeshoptDecoder(MeshoptDecoder)
}
let loader
export function getLoader() {
  if (!loader) extendLoader((loader = new GLTFLoader()))
  return loader
}

export const isGLB = (buf) => buf && buf.byteLength > 12 && new DataView(buf).getUint32(0, true) === 0x46546c67 // "glTF"

export function parseGLB(buf) {
  return new Promise((res, rej) => {
    if (!isGLB(buf)) return rej(new Error('nu este GLB'))
    getLoader().parse(buf, '', res, rej)
  })
}

// Scalează și centrează modelul: clădirile/mascota după înălțime, cu baza la y=0;
// insula după diametru, păstrând originea verticală (y=0 = nivelul ierbii).
export function normalize(k, scene) {
  const m = scene
  m.position.set(0, 0, 0)
  m.scale.setScalar(1)
  m.updateMatrixWorld(true)
  const bb = new THREE.Box3().setFromObject(m)
  const sz = bb.getSize(new THREE.Vector3())
  if (k === 'insula') m.scale.setScalar(ISLAND_DIAMETER / Math.max(sz.x, sz.z, 0.001))
  else m.scale.setScalar(MODEL_HEIGHT[k] / Math.max(sz.y, 0.001))
  m.updateMatrixWorld(true)
  bb.setFromObject(m)
  const c = bb.getCenter(new THREE.Vector3())
  m.position.set(-c.x, k === 'insula' ? 0 : -bb.min.y, -c.z)
  m.traverse((o) => {
    if (o.isMesh) o.castShadow = o.receiveShadow = true
  })
  return m
}

// Modelele din public/models: încărcate o singură dată; un fișier invalid dă null
// (avertisment în consolă) și piesa rămâne procedurală.
const publicCache = new Map()
export const brokenPublic = new Set()
export function loadPublic(k) {
  if (!publicCache.has(k))
    publicCache.set(
      k,
      fetch(modelUrl(k))
        .then((r) => (r.ok ? r.arrayBuffer() : Promise.reject(new Error('HTTP ' + r.status))))
        .then(parseGLB)
        .catch((e) => {
          console.warn(`[Buble] models/${k}.glb invalid, folosesc varianta procedurală:`, e.message)
          brokenPublic.add(k)
          return null
        })
    )
  return publicCache.get(k)
}

// ---- IndexedDB pentru modelele alese de utilizator ----
const idb = () =>
  new Promise((r) => {
    try {
      const q = indexedDB.open('buble3d', 1)
      q.onupgradeneeded = () => q.result.createObjectStore('m')
      q.onsuccess = () => r(q.result)
      q.onerror = () => r(null)
    } catch {
      r(null)
    }
  })
export async function idbSet(k, v) {
  const d = await idb()
  if (d)
    try {
      d.transaction('m', 'readwrite').objectStore('m').put(v, k)
    } catch {
      /* ignore */
    }
}
export async function idbDel(k) {
  const d = await idb()
  if (d)
    try {
      d.transaction('m', 'readwrite').objectStore('m').delete(k)
    } catch {
      /* ignore */
    }
}
export async function idbGet(k) {
  const d = await idb()
  if (!d) return null
  return new Promise((r) => {
    try {
      const q = d.transaction('m').objectStore('m').get(k)
      q.onsuccess = () => r(q.result)
      q.onerror = () => r(null)
    } catch {
      r(null)
    }
  })
}
