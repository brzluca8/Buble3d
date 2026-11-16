import { useEffect, useMemo, useRef } from 'react'
import * as THREE from 'three'
import { useFrame } from '@react-three/fiber'
import { useGame } from '../store'
import { BUILDINGS } from '../data'
import { buildBuilding, buildLevelLanterns } from './procedural'
import { ModelSlot } from './ModelSlot'

// Grupurile clădirilor, pentru selectarea prin raycast (CameraRig).
export const buildingGroups = new Map()

export function Building({ b }) {
  const ref = useRef()
  const level = useGame((s) => s.save.b[b.id])
  const proc = useMemo(() => buildBuilding(b.id), [b.id])
  const lanterns = useMemo(() => buildLevelLanterns(level), [level])
  const anim = useRef(1) // 0 → 1: animație „pop" la upgrade
  const base = 1 + 0.07 * (level - 1)

  useEffect(() => {
    buildingGroups.set(b.id, ref.current)
    return () => buildingGroups.delete(b.id)
  }, [b.id])

  useEffect(
    () =>
      useGame.subscribe((s, p) => {
        if (s.pop.n !== p.pop.n && s.pop.id === b.id) anim.current = 0
      }),
    [b.id]
  )

  useFrame((_, dt) => {
    const g = ref.current
    if (anim.current < 1) {
      anim.current = Math.min(1, anim.current + dt / 0.9)
      const t = anim.current - 1,
        e = 1 + 2.7 * t ** 3 + 1.7 * t * t
      g.scale.set(base * (0.8 + 0.2 * e), base * (0.5 + 0.5 * e), base * (0.8 + 0.2 * e))
    } else g.scale.setScalar(base)
  })

  return (
    <group ref={ref} position={[b.x, 0, b.z]} userData={{ buildingId: b.id }}>
      <ModelSlot k={b.id} fallback={<primitive object={proc} />} />
      <primitive object={lanterns} />
    </group>
  )
}

export function Buildings() {
  return BUILDINGS.map((b) => <Building key={b.id} b={b} />)
}

export function SelectionRing() {
  const ref = useRef()
  const sel = useGame((s) => s.sel)
  const b = BUILDINGS.find((x) => x.id === sel)
  useFrame(({ clock }) => {
    if (ref.current) ref.current.scale.setScalar(1 + Math.sin(clock.elapsedTime * 4) * 0.05)
  })
  if (!b) return null
  return (
    <mesh ref={ref} position={[b.x, 0.1, b.z]} rotation-x={Math.PI / 2}>
      <torusGeometry args={[2.2, 0.07, 8, 48]} />
      <meshStandardMaterial color="#ffd86b" emissive="#ffc040" emissiveIntensity={1.6} />
    </mesh>
  )
}

// Scântei aurii la upgrade (un InstancedMesh refolosit).
const N = 78
export function Sparks() {
  const ref = useRef()
  const parts = useMemo(() => Array.from({ length: N }, () => ({ p: new THREE.Vector3(), v: new THREE.Vector3(), l: 0 })), [])
  const next = useRef(0)
  const mtx = useMemo(() => new THREE.Matrix4(), [])
  const q = useMemo(() => new THREE.Quaternion(), [])
  const sc = useMemo(() => new THREE.Vector3(), [])

  useEffect(
    () =>
      useGame.subscribe((s, p) => {
        if (s.pop.n === p.pop.n) return
        const b = BUILDINGS.find((x) => x.id === s.pop.id)
        for (let i = 0; i < 26; i++) {
          const pt = parts[next.current++ % N]
          pt.p.set(b.x, 1.5, b.z)
          pt.v.set((Math.random() - 0.5) * 5, 2 + Math.random() * 4, (Math.random() - 0.5) * 5)
          pt.l = 1
        }
      }),
    [parts]
  )

  useFrame((_, dt) => {
    const im = ref.current
    parts.forEach((pt, i) => {
      if (pt.l > 0) {
        pt.v.y -= 9 * dt
        pt.p.addScaledVector(pt.v, dt)
        pt.l -= dt * 1.2
      }
      const s = Math.max(pt.l, 0)
      mtx.compose(pt.p, q, sc.set(s, s, s))
      im.setMatrixAt(i, mtx)
    })
    im.instanceMatrix.needsUpdate = true
  })

  return (
    <instancedMesh ref={ref} args={[null, null, N]} frustumCulled={false}>
      <sphereGeometry args={[0.09, 6, 6]} />
      <meshStandardMaterial color="#ffd86b" emissive="#ffc040" emissiveIntensity={2} />
    </instancedMesh>
  )
}
