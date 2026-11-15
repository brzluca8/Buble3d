import { useMemo, useRef } from 'react'
import * as THREE from 'three'
import { useFrame } from '@react-three/fiber'
import { buildTerrain, buildPlaza, seeded } from './procedural'
import { waterTex, cloudTex } from './textures'
import { ModelSlot } from './ModelSlot'
import { WATERFALLS } from '../data'

// Terenul: insula.glb dacă există, altfel stânca + iarba procedurale.
export function Terrain() {
  const proc = useMemo(() => buildTerrain(), [])
  return <ModelSlot k="insula" fallback={<primitive object={proc} />} />
}

// Piața centrală cu fântână animată, vegetație și felinare.
export function Plaza() {
  const { group, gem } = useMemo(() => buildPlaza(), [])
  useFrame(({ clock }) => {
    const T = clock.elapsedTime
    gem.rotation.y = T
    gem.position.y = 2 + Math.sin(T * 2) * 0.08
  })
  return <primitive object={group} />
}

// Picături: jetul fântânii și stropii cascadelor (un singur Points).
export function Droplets() {
  const { geo, dp } = useMemo(() => {
    const rnd = seeded(19)
    const dp = []
    for (let i = 0; i < 40; i++) dp.push({ k: 0, a: rnd() * 6.28, p: rnd() })
    WATERFALLS.forEach((w) => {
      for (let i = 0; i < 30; i++) dp.push({ k: 1, x: w[0] * 1.05 + (rnd() - 0.5) * 0.8, z: w[1] * 1.05, p: rnd() })
    })
    const geo = new THREE.BufferGeometry()
    geo.setAttribute('position', new THREE.BufferAttribute(new Float32Array(dp.length * 3), 3))
    geo.boundingSphere = new THREE.Sphere(new THREE.Vector3(0, 0, 2), 12)
    return { geo, dp }
  }, [])
  useFrame(({ clock }) => {
    const T = clock.elapsedTime,
      pa = geo.attributes.position
    dp.forEach((d, i) => {
      let x, y, z
      if (d.k === 0) {
        const u = (T * 0.5 + d.p) % 1
        x = Math.cos(d.a) * 1.25 * u
        z = 0.3 + Math.sin(d.a) * 1.25 * u
        y = 1.95 + 2.2 * u * (1 - u) - 1.4 * u * u
      } else {
        const u = (T * 0.9 + d.p) % 1
        x = d.x
        z = d.z
        y = 0.05 - 4.4 * u
      }
      pa.setXYZ(i, x, y, z)
    })
    pa.needsUpdate = true
  })
  return (
    <points geometry={geo}>
      <pointsMaterial size={0.16} color="#ffffff" transparent opacity={0.85} depthWrite={false} />
    </points>
  )
}

// Cascade cu mai multe straturi: perdea din spate, apă principală, fir frontal, ceață la bază.
const LAYERS = [
  { w: 1.5, h: 4.8, speed: 0.35, opacity: 0.35, off: -0.06, color: '#7fd6ff' },
  { w: 1.1, h: 4.5, speed: 0.6, opacity: 0.75, off: 0, color: '#bff0ff' },
  { w: 0.6, h: 4.3, speed: 0.95, opacity: 0.55, off: 0.06, color: '#ffffff' },
]
export function Waterfalls() {
  const falls = useMemo(
    () =>
      WATERFALLS.map((w) => ({
        pos: [w[0] * 1.03, -2.3, w[1] * 1.03],
        rot: Math.atan2(w[0], w[1]),
        mist: [w[0] * 1.08, -4.6, w[1] * 1.08],
        layers: LAYERS.map((L) => {
          const t = waterTex.clone()
          t.repeat.set(1, L.h / 3)
          t.offset.x = Math.random()
          return { ...L, tex: t }
        }),
      })),
    []
  )
  const mists = useRef([])
  useFrame(({ clock }, dt) => {
    const T = clock.elapsedTime
    falls.forEach((f) => f.layers.forEach((L) => (L.tex.offset.y += dt * L.speed)))
    mists.current.forEach((m, i) => {
      if (!m) return
      const s = 1 + Math.sin(T * 1.7 + i) * 0.08
      m.scale.set(3.2 * s, 1.6 * s, 1)
      m.material.opacity = 0.6 + Math.sin(T * 2.3 + i) * 0.1
    })
  })
  return falls.map((f, i) => (
    <group key={i}>
      <group position={f.pos} rotation-y={f.rot}>
        {f.layers.map((L, j) => (
          <mesh key={j} position-z={L.off} renderOrder={2}>
            <planeGeometry args={[L.w, L.h]} />
            <meshBasicMaterial map={L.tex} color={L.color} transparent opacity={L.opacity} side={THREE.DoubleSide} depthWrite={false} />
          </mesh>
        ))}
      </group>
      <sprite ref={(m) => (mists.current[i] = m)} position={f.mist} scale={[3.2, 1.6, 1]} renderOrder={3}>
        <spriteMaterial map={cloudTex} transparent depthWrite={false} opacity={0.7} />
      </sprite>
    </group>
  ))
}
