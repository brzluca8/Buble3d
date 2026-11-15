import { useMemo, useRef } from 'react'
import * as THREE from 'three'
import { useFrame } from '@react-three/fiber'
import { Clouds as DreiClouds, Cloud } from '@react-three/drei'
import { cloudDataURL } from './textures'
import { buildFarIsland, seeded } from './procedural'

// Nori volumetrici (drei <Clouds>, sprite-uri instanțiate) cu textură generată local.
export function Clouds({ quality }) {
  const list = useMemo(() => {
    const rnd = seeded(23)
    const n = quality === 'inalta' ? 14 : 8
    return Array.from({ length: n }, (_, i) => {
      const low = i < n * 0.6
      return {
        seed: i + 1,
        pos: low
          ? [(rnd() - 0.5) * 60, -9 + rnd() * 3.5, -8 + rnd() * 22]
          : [(rnd() - 0.5) * 80, -3 + rnd() * 10, -24 - rnd() * 20],
        bounds: low ? [8, 1.6, 4] : [10, 2.5, 3],
        volume: low ? 6 : 8,
        segments: quality === 'inalta' ? 14 : 8,
        color: i % 3 ? '#ffffff' : '#e4ecff',
        speed: 0.3 + rnd() * 0.5,
      }
    })
  }, [quality])
  const refs = useRef([])
  useFrame((_, dt) => {
    refs.current.forEach((g) => {
      if (!g) return
      g.position.x += dt * 0.5
      if (g.position.x > 45) g.position.x = -45
    })
  })
  return (
    <DreiClouds texture={cloudDataURL} material={THREE.MeshLambertMaterial} limit={list.length * 16} frustumCulled={false}>
      {list.map((c, i) => (
        <group key={c.seed} ref={(g) => (refs.current[i] = g)} position={c.pos}>
          <Cloud seed={c.seed} segments={c.segments} bounds={c.bounds} volume={c.volume} color={c.color} speed={0.1} growth={3} opacity={0.85} fade={30} />
        </group>
      ))}
    </DreiClouds>
  )
}

const FAR = [
  [-13, 5, -16],
  [14, 6, -14],
  [18, 0, -24],
]
export function FarIslands() {
  const islands = useMemo(() => FAR.map(() => buildFarIsland()), [])
  const refs = useRef([])
  useFrame(({ clock }) => {
    refs.current.forEach((g, i) => {
      if (g) g.position.y = FAR[i][1] + Math.sin(clock.elapsedTime * 0.6 + i) * 0.35
    })
  })
  return islands.map((o, i) => <primitive key={i} ref={(g) => (refs.current[i] = g)} object={o} position={FAR[i]} />)
}
