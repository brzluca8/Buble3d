import * as THREE from 'three'

// Texturi generate pe canvas (portate din buble.html). Create o singură dată.
const rn = (a, b) => a + Math.random() * (b - a)

function cvsCanvas(w, h, f) {
  const c = document.createElement('canvas')
  c.width = w
  c.height = h
  f(c.getContext('2d'), w, h)
  return c
}

function cvs(w, h, f, { repeat = true, srgb = true } = {}) {
  const t = new THREE.CanvasTexture(cvsCanvas(w, h, f))
  if (repeat) t.wrapS = t.wrapT = THREE.RepeatWrapping
  if (srgb) t.colorSpace = THREE.SRGBColorSpace
  t.anisotropy = 4
  return t
}

export const stoneTex = cvs(256, 256, (x, w, h) => {
  for (let r = 0; r < 8; r++)
    for (let c = -1; c < 5; c++) {
      const v = rn(232, 255) | 0
      x.fillStyle = `rgb(${v},${v - 3},${v - 9})`
      x.fillRect(c * 64 + (r % 2) * 32, r * 32, 64, 32)
    }
  x.strokeStyle = 'rgba(120,105,80,.6)'
  x.lineWidth = 2
  for (let r = 0; r <= 8; r++) {
    x.beginPath()
    x.moveTo(0, r * 32)
    x.lineTo(w, r * 32)
    x.stroke()
  }
  for (let r = 0; r < 8; r++)
    for (let c = 0; c <= 4; c++) {
      x.beginPath()
      x.moveTo(c * 64 + (r % 2) * 32, r * 32)
      x.lineTo(c * 64 + (r % 2) * 32, r * 32 + 32)
      x.stroke()
    }
  for (let i = 0; i < 500; i++) {
    x.fillStyle = `rgba(90,75,50,${rn(0.03, 0.1)})`
    x.fillRect(rn(0, w), rn(0, h), rn(1, 3), rn(1, 3))
  }
})
stoneTex.repeat.set(3, 1.2)

export const roofTex = cvs(256, 256, (x, w, h) => {
  x.fillStyle = '#cfe6e6'
  x.fillRect(0, 0, w, h)
  for (let r = 0; r < 16; r++)
    for (let c = -1; c < 9; c++) {
      const cx = c * 32 + (r % 2) * 16,
        cy = r * 16,
        g = x.createRadialGradient(cx, cy + 4, 2, cx, cy + 4, 24)
      g.addColorStop(0, '#ffffff')
      g.addColorStop(1, '#9fc4c4')
      x.fillStyle = g
      x.beginPath()
      x.arc(cx, cy, 16, 0, Math.PI)
      x.fill()
      x.strokeStyle = 'rgba(20,70,80,.45)'
      x.lineWidth = 1.5
      x.stroke()
    }
})
roofTex.repeat.set(3, 1.5)

export const grassTex = cvs(256, 256, (x, w, h) => {
  x.fillStyle = '#f4f4f4'
  x.fillRect(0, 0, w, h)
  for (let i = 0; i < 70; i++) {
    x.fillStyle = i % 2 ? 'rgba(0,70,0,.07)' : 'rgba(255,255,255,.12)'
    x.beginPath()
    x.arc(rn(0, w), rn(0, h), rn(10, 35), 0, 7)
    x.fill()
  }
  for (let i = 0; i < 900; i++) {
    x.strokeStyle = i % 3 ? 'rgba(0,80,10,.18)' : 'rgba(255,255,255,.3)'
    x.lineWidth = 1
    const a = rn(0, w),
      b = rn(0, h)
    x.beginPath()
    x.moveTo(a, b)
    x.lineTo(a + rn(-2, 2), b - rn(3, 8))
    x.stroke()
  }
})
grassTex.repeat.set(8, 8)

export const rockTex = cvs(256, 256, (x, w, h) => {
  x.fillStyle = '#e6dfea'
  x.fillRect(0, 0, w, h)
  for (let i = 0; i < 24; i++) {
    x.fillStyle = `rgba(60,45,80,${rn(0.04, 0.1)})`
    x.fillRect(0, rn(0, h), w, rn(4, 16))
  }
  for (let i = 0; i < 30; i++) {
    x.strokeStyle = 'rgba(40,28,60,.4)'
    x.lineWidth = rn(1, 2.5)
    let a = rn(0, w),
      b = rn(0, h)
    x.beginPath()
    x.moveTo(a, b)
    for (let k = 0; k < 4; k++) {
      a += rn(-18, 18)
      b += rn(6, 24)
      x.lineTo(a, b)
    }
    x.stroke()
  }
  for (let i = 0; i < 700; i++) {
    x.fillStyle = `rgba(30,20,40,${rn(0.05, 0.15)})`
    x.fillRect(rn(0, w), rn(0, h), rn(1, 3), rn(1, 3))
  }
})
rockTex.repeat.set(6, 2)

export const cobTex = cvs(256, 256, (x, w, h) => {
  x.fillStyle = '#8f8068'
  x.fillRect(0, 0, w, h)
  for (let r = 0; r < 8; r++)
    for (let c = -1; c < 5; c++) {
      const v = rn(225, 255) | 0,
        px = c * 64 + (r % 2) * 32 + 3,
        py = r * 32 + 3
      x.fillStyle = `rgb(${v},${v - 6},${v - 18})`
      x.beginPath()
      x.moveTo(px + 8, py)
      x.lineTo(px + 50, py)
      x.quadraticCurveTo(px + 58, py, px + 58, py + 8)
      x.lineTo(px + 58, py + 18)
      x.quadraticCurveTo(px + 58, py + 26, px + 50, py + 26)
      x.lineTo(px + 8, py + 26)
      x.quadraticCurveTo(px, py + 26, px, py + 18)
      x.lineTo(px, py + 8)
      x.quadraticCurveTo(px, py, px + 8, py)
      x.fill()
    }
})
cobTex.repeat.set(3, 3)

// Pufuri de nor (alfa moale), folosite de nori și ceața cascadelor.
const cloudCanvas = cvsCanvas(256, 256, (x, w, h) => {
  for (let i = 0; i < 10; i++) {
    const cx = rn(80, 176),
      cy = rn(90, 166),
      r = rn(50, 80),
      g = x.createRadialGradient(cx, cy, 0, cx, cy, r)
    g.addColorStop(0, 'rgba(255,255,255,.9)')
    g.addColorStop(0.55, 'rgba(244,248,255,.5)')
    g.addColorStop(1, 'rgba(235,242,255,0)')
    x.fillStyle = g
    x.fillRect(0, 0, w, h)
  }
})
export const cloudTex = new THREE.CanvasTexture(cloudCanvas)
cloudTex.colorSpace = THREE.SRGBColorSpace
export const cloudDataURL = cloudCanvas.toDataURL('image/png')

// Dâre de apă verticale pentru cascade (se derulează în timp).
export const waterTex = cvs(
  128,
  256,
  (x, w, h) => {
    const g = x.createLinearGradient(0, 0, w, 0)
    g.addColorStop(0, 'rgba(160,232,255,0)')
    g.addColorStop(0.2, 'rgba(160,232,255,.55)')
    g.addColorStop(0.8, 'rgba(160,232,255,.55)')
    g.addColorStop(1, 'rgba(160,232,255,0)')
    x.fillStyle = g
    x.fillRect(0, 0, w, h)
    for (let i = 0; i < 70; i++) {
      const a = rn(10, w - 10)
      x.strokeStyle = `rgba(255,255,255,${rn(0.15, 0.6)})`
      x.lineWidth = rn(1, 3)
      const y = rn(0, h),
        l = rn(30, 120)
      x.beginPath()
      x.moveTo(a, y)
      x.lineTo(a + rn(-2, 2), y + l)
      x.stroke()
      if (y + l > h) {
        x.beginPath()
        x.moveTo(a, y - h)
        x.lineTo(a, y + l - h)
        x.stroke()
      }
    }
  },
  { repeat: true }
)

// Sprite de strălucire pentru calitate scăzută (fără bloom real).
export const glowTex = cvs(
  128,
  128,
  (x) => {
    const g = x.createRadialGradient(64, 64, 0, 64, 64, 64)
    g.addColorStop(0, 'rgba(255,255,255,1)')
    g.addColorStop(0.25, 'rgba(255,255,255,.45)')
    g.addColorStop(1, 'rgba(255,255,255,0)')
    x.fillStyle = g
    x.fillRect(0, 0, 128, 128)
  },
  { repeat: false }
)
