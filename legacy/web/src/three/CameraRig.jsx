import { useEffect, useRef } from 'react'
import * as THREE from 'three'
import { useFrame, useThree } from '@react-three/fiber'
import { useGame } from '../store'
import { buildingGroups } from './Building'

// Cameră orbitală: tragere = rotire, ciupire/rotiță = zoom, atingere = selectare clădire.
export function CameraRig() {
  const { gl, camera, size } = useThree()
  const st = useRef({ th: 0.15, ph: 0.95, dist: size.width < size.height ? 34 : 26 })
  const tg = useRef(new THREE.Vector3(0, 0.5, 0))

  useEffect(() => {
    const el = gl.domElement,
      s = st.current,
      P = new Map(),
      rc = new THREE.Raycaster(),
      v2 = new THREE.Vector2()
    let dr = 0,
      pd = 0
    const pdist = () => {
      const a = [...P.values()]
      return Math.hypot(a[0][0] - a[1][0], a[0][1] - a[1][1])
    }
    const pick = (x, y) => {
      const r = el.getBoundingClientRect()
      v2.set(((x - r.left) / r.width) * 2 - 1, -((y - r.top) / r.height) * 2 + 1)
      rc.setFromCamera(v2, camera)
      const hit = rc.intersectObjects([...buildingGroups.values()], true)
      let id = null
      for (const h of hit) {
        let o = h.object
        if (!o.visible) continue
        while (o && !o.userData.buildingId) o = o.parent
        if (o) {
          id = o.userData.buildingId
          break
        }
      }
      useGame.getState().select(id)
    }
    const down = (e) => {
      el.setPointerCapture(e.pointerId)
      P.set(e.pointerId, [e.clientX, e.clientY])
      dr = 0
      if (P.size === 2) pd = pdist()
    }
    const move = (e) => {
      const o = P.get(e.pointerId)
      if (!o) return
      const dx = e.clientX - o[0],
        dy = e.clientY - o[1]
      P.set(e.pointerId, [e.clientX, e.clientY])
      if (P.size === 1) {
        s.th -= dx * 0.006
        s.ph = Math.max(0.6, Math.min(1.3, s.ph - dy * 0.004))
        dr += Math.abs(dx) + Math.abs(dy)
      } else if (P.size === 2) {
        const d = pdist()
        if (d > 0) s.dist = Math.max(16, Math.min(52, (s.dist * pd) / d))
        pd = d
        dr += 9
      }
    }
    const up = (e) => {
      if (P.size === 1 && dr < 8 && P.has(e.pointerId)) pick(e.clientX, e.clientY)
      P.delete(e.pointerId)
    }
    const cancel = (e) => P.delete(e.pointerId)
    const wheel = (e) => {
      e.preventDefault()
      s.dist = Math.max(16, Math.min(52, s.dist * (1 + e.deltaY * 0.001)))
    }
    el.addEventListener('pointerdown', down)
    el.addEventListener('pointermove', move)
    el.addEventListener('pointerup', up)
    el.addEventListener('pointercancel', cancel)
    el.addEventListener('wheel', wheel, { passive: false })
    return () => {
      el.removeEventListener('pointerdown', down)
      el.removeEventListener('pointermove', move)
      el.removeEventListener('pointerup', up)
      el.removeEventListener('pointercancel', cancel)
      el.removeEventListener('wheel', wheel)
    }
  }, [gl, camera])

  useFrame(() => {
    const { th, ph, dist } = st.current,
      t = tg.current
    camera.position.set(t.x + dist * Math.sin(ph) * Math.sin(th), t.y + dist * Math.cos(ph), t.z + dist * Math.sin(ph) * Math.cos(th))
    camera.lookAt(t)
  })
  return null
}
