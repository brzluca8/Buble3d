import { Suspense, use, useEffect, useMemo, useRef } from 'react'
import * as THREE from 'three'
import { useFrame } from '@react-three/fiber'
import { clone as skeletonClone } from 'three/examples/jsm/utils/SkeletonUtils.js'
import { useGame } from '../store'
import { PUBLIC_MODELS, normalize, loadPublic } from './models'

// Obiect GLB, cu animații opționale. `clip` (ref) alege clipul după nume: 'idle', 'walk'...
function GLBObject({ object, animations, clip }) {
  const mixer = useMemo(() => (animations?.length ? new THREE.AnimationMixer(object) : null), [object, animations])
  const cur = useRef(null)
  useEffect(() => () => mixer?.stopAllAction(), [mixer])
  useFrame((_, dt) => {
    if (!mixer) return
    const re = new RegExp(clip?.current || 'idle', 'i')
    const want = animations.find((a) => re.test(a.name)) || animations.find((a) => /idle/i.test(a.name)) || animations[0]
    if (want !== cur.current) {
      if (cur.current) mixer.clipAction(cur.current).fadeOut(0.25)
      mixer.clipAction(want).reset().fadeIn(0.25).play()
      cur.current = want
    }
    mixer.update(dt)
  })
  return <primitive object={object} />
}

// Model din public/models (Suspense: cât se încarcă, se vede varianta procedurală).
function PublicGLB({ k, clip, fallback }) {
  const gltf = use(loadPublic(k))
  const object = useMemo(() => gltf && normalize(k, skeletonClone(gltf.scene)), [k, gltf])
  if (!object) return fallback
  return <GLBObject object={object} animations={gltf.animations} clip={clip} />
}

/**
 * Piesă înlocuibilă: model încărcat de utilizator (IndexedDB) → public/models/<k>.glb → procedural.
 */
export function ModelSlot({ k, fallback, clip }) {
  const user = useGame((s) => s.userModels[k])
  if (user) return <GLBObject key={user.scene.uuid} object={user.scene} animations={user.animations} clip={clip} />
  if (PUBLIC_MODELS.has(k))
    return (
      <Suspense fallback={fallback}>
        <PublicGLB k={k} clip={clip} fallback={fallback} />
      </Suspense>
    )
  return fallback
}
