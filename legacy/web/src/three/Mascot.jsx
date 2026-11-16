import { useEffect, useMemo, useRef } from 'react'
import * as THREE from 'three'
import { useFrame } from '@react-three/fiber'
import { useGame } from '../store'
import { BUILDINGS } from '../data'
import { buildMascot } from './procedural'
import { ModelSlot } from './ModelSlot'

// Mascota merge spre clădirea selectată și sare la upgrade / întoarcere din Buble Blast.
// Dacă mascot.glb are animații, se folosesc clipurile „idle", „walk", „jump" (după nume).
export function Mascot() {
  const ref = useRef()
  const { group: proc, mouth } = useMemo(() => buildMascot(), [])
  const target = useRef(new THREE.Vector3(0, 0, 5))
  const jump = useRef(0)
  const ry = useRef(0)
  const clip = useRef('idle')

  useEffect(
    () =>
      useGame.subscribe((s, p) => {
        if (s.sel !== p.sel && s.sel) {
          const b = BUILDINGS.find((x) => x.id === s.sel)
          target.current.set(b.x + (b.x > 0 ? -1.9 : 1.9), 0, b.z + 2.5)
          jump.current = 0.5
        }
        if (s.jump !== p.jump) jump.current = 1
      }),
    []
  )

  useFrame(({ clock }, dt) => {
    const ms = ref.current,
      T = clock.elapsedTime
    const dx = target.current.x - ms.position.x,
      dz = target.current.z - ms.position.z,
      mv = Math.hypot(dx, dz) > 0.1
    ms.position.x += dx * Math.min(1, dt * 2.2)
    ms.position.z += dz * Math.min(1, dt * 2.2)
    const want = mv ? Math.atan2(dx, dz) : 0
    ry.current += (want - ry.current) * Math.min(1, dt * 5)
    ms.rotation.y = ry.current
    let y = mv ? Math.abs(Math.sin(T * 10)) * 0.12 : Math.sin(T * 2) * 0.03
    if (jump.current > 0) {
      y += Math.sin((1 - jump.current) * Math.PI) * 1.2
      jump.current -= dt * 1.4
    }
    ms.position.y = y
    mouth.scale.y = 0.5 + Math.max(jump.current, 0) * 1.5
    clip.current = jump.current > 0 ? 'jump' : mv ? 'walk|run' : 'idle'
  })

  return (
    <group ref={ref} position={[0, 0, 5]}>
      <ModelSlot k="mascot" fallback={<primitive object={proc} />} clip={clip} />
    </group>
  )
}
