import { useEffect, useRef, useState } from 'react'
import { useGame } from '../store'

// Buble Blast: grilă hexagonală de 8 coloane, 25 de mutări, grupuri de 3+, bule căzute.
const COL = ['#2bd4c8', '#9a63ff', '#ffc83d', '#ff6fa8']
const RW = 14,
  CW = 8

export default function BubleBlast() {
  const cv = useRef()
  const [result, setResult] = useState(null)
  const closeBlast = useGame((s) => s.closeBlast)
  const gameRef = useRef(null)

  useEffect(() => {
    const bc = cv.current,
      bt = bc.getContext('2d')
    let G,
      raf,
      last = performance.now(),
      alive = true
    const dpr = Math.min(window.devicePixelRatio || 1, 2)

    const layout = () => {
      const W = bc.clientWidth,
        H = bc.clientHeight
      bc.width = W * dpr
      bc.height = H * dpr
      bt.setTransform(dpr, 0, 0, dpr, 0, 0)
      const r = Math.min(W / 17, 34)
      Object.assign(G, { W, H, r, rs: r * 1.732, x0: (W - 17 * r) / 2 + r, y0: 100 + r, sx: W / 2, sy: H - 100 })
      G.lim = Math.floor((G.sy - 2.6 * r - G.y0) / G.rs)
    }
    const cp = (r, c) => [G.x0 + c * 2 * G.r + (r % 2) * G.r, G.y0 + r * G.rs]
    const nb = (r, c) => {
      const p = r % 2,
        o = [
          [r, c - 1],
          [r, c + 1],
        ]
      for (const q of [r - 1, r + 1]) o.push([q, c - 1 + p], [q, c + p])
      return o.filter((a) => a[0] >= 0 && a[0] < RW && a[1] >= 0 && a[1] < CW)
    }
    const pickc = () => {
      const s = new Set()
      G.g.forEach((r) => r.forEach((v) => v >= 0 && s.add(v)))
      const a = s.size ? [...s] : [0, 1, 2, 3]
      return a[(Math.random() * a.length) | 0]
    }

    G = {
      g: Array.from({ length: RW }, () => Array(CW).fill(-1)),
      score: 0,
      shots: 25,
      mv: null,
      a: Math.PI / 2,
      over: false,
      fx: [],
      msg: '',
      mt: 0,
    }
    gameRef.current = G
    layout()
    for (let i = 0; i < 6; i++) for (let j = 0; j < CW; j++) G.g[i][j] = (Math.random() * 4) | 0
    G.cc = pickc()
    G.nc = pickc()

    const dot = (x, y, c, r) => {
      bt.beginPath()
      bt.arc(x, y, r * 0.94, 0, 7)
      bt.fillStyle = COL[c]
      bt.fill()
      const g = bt.createRadialGradient(x - r * 0.35, y - r * 0.35, r * 0.05, x - r * 0.2, y - r * 0.2, r * 0.8)
      g.addColorStop(0, 'rgba(255,255,255,.9)')
      g.addColorStop(1, 'rgba(255,255,255,0)')
      bt.fillStyle = g
      bt.fill()
      bt.strokeStyle = 'rgba(0,0,0,.25)'
      bt.lineWidth = 2
      bt.stroke()
    }
    const aim = (e) => {
      const r = bc.getBoundingClientRect()
      G.a = Math.max(0.2, Math.min(Math.PI - 0.2, Math.atan2(G.sy - (e.clientY - r.top), e.clientX - r.left - G.sx)))
    }
    const pop = (r, c, fall) => {
      const [x, y] = cp(r, c),
        col = G.g[r][c]
      G.g[r][c] = -1
      if (fall) G.fx.push({ x, y, vx: (Math.random() - 0.5) * 120, vy: -100, c: col, big: 1, t: 1.2 })
      for (let i = 0; i < 5; i++) G.fx.push({ x, y, vx: (Math.random() - 0.5) * 300, vy: (Math.random() - 0.5) * 300, c: col, t: 0.5 })
    }
    const end = (won) => {
      G.over = true
      const co = useGame.getState().blastReward(G.score, won)
      setResult({ won, score: G.score, coins: co })
    }
    const place = () => {
      const m = G.mv
      G.mv = null
      let b = null,
        bd = 1e9
      for (let r = 0; r < RW; r++)
        for (let c = 0; c < CW; c++)
          if (G.g[r][c] < 0) {
            const [x, y] = cp(r, c),
              d = (x - m.x) ** 2 + (y - m.y) ** 2
            if (d < bd) {
              bd = d
              b = [r, c]
            }
          }
      if (!b) return end(false)
      G.g[b[0]][b[1]] = m.c
      const st = [b],
        same = new Set([b + ''])
      while (st.length) {
        const [r, c] = st.pop()
        for (const n of nb(r, c))
          if (G.g[n[0]][n[1]] === m.c && !same.has(n + '')) {
            same.add(n + '')
            st.push(n)
          }
      }
      let falls = 0
      if (same.size >= 3) {
        same.forEach((k) => {
          const [r, c] = k.split(',').map(Number)
          pop(r, c, 0)
          G.score += 10
        })
        const ok = new Set(),
          q = []
        for (let c = 0; c < CW; c++)
          if (G.g[0][c] >= 0) {
            ok.add('0,' + c)
            q.push([0, c])
          }
        while (q.length) {
          const [r, c] = q.pop()
          for (const n of nb(r, c))
            if (G.g[n[0]][n[1]] >= 0 && !ok.has(n + '')) {
              ok.add(n + '')
              q.push(n)
            }
        }
        for (let r = 0; r < RW; r++)
          for (let c = 0; c < CW; c++)
            if (G.g[r][c] >= 0 && !ok.has(r + ',' + c)) {
              pop(r, c, 1)
              falls++
              G.score += 20
            }
      }
      if (falls) {
        G.msg = 'Reacție în lanț! ×' + falls
        G.mt = 1.5
      }
      if (G.g.every((r) => r.every((v) => v < 0))) return end(true)
      if (G.g.some((r, i) => i >= G.lim && r.some((v) => v >= 0)) || G.shots <= 0) end(false)
    }

    const step = (dt) => {
      const g = G
      if (g.mv) {
        for (let s = 0; s < 4 && g.mv; s++) {
          const m = g.mv,
            d = dt / 4
          m.x += m.vx * d
          m.y += m.vy * d
          const L = g.x0 - g.r,
            Rt = L + 17 * g.r
          if (m.x < L + g.r) {
            m.x = L + g.r
            m.vx = -m.vx
          }
          if (m.x > Rt - g.r) {
            m.x = Rt - g.r
            m.vx = -m.vx
          }
          let hit = m.y <= g.y0
          if (!hit)
            for (let r = 0; r < RW && !hit; r++)
              for (let c = 0; c < CW; c++)
                if (g.g[r][c] >= 0) {
                  const [x, y] = cp(r, c)
                  if ((x - m.x) ** 2 + (y - m.y) ** 2 < (1.75 * g.r) ** 2) {
                    hit = true
                    break
                  }
                }
          if (hit) place()
        }
      }
      g.fx = g.fx.filter((f) => (f.t -= dt) > 0)
      g.fx.forEach((f) => {
        f.x += f.vx * dt
        f.y += f.vy * dt
        f.vy += (f.big ? 900 : 200) * dt
      })
      if (g.mt > 0) g.mt -= dt

      bt.clearRect(0, 0, g.W, g.H)
      bt.strokeStyle = 'rgba(255,255,255,.25)'
      bt.setLineDash([8, 8])
      bt.beginPath()
      const ly = g.y0 + g.lim * g.rs - g.r
      bt.moveTo(0, ly)
      bt.lineTo(g.W, ly)
      bt.stroke()
      bt.setLineDash([])
      for (let r = 0; r < RW; r++)
        for (let c = 0; c < CW; c++)
          if (g.g[r][c] >= 0) {
            const [x, y] = cp(r, c)
            dot(x, y, g.g[r][c], g.r)
          }
      if (!g.mv && !g.over) {
        bt.fillStyle = '#fff9'
        for (let i = 1; i < 9; i++)
          bt.fillRect(g.sx + Math.cos(g.a) * i * g.r * 1.6 - 2, g.sy - Math.sin(g.a) * i * g.r * 1.6 - 2, 5, 5)
      }
      if (g.mv) dot(g.mv.x, g.mv.y, g.mv.c, g.r)
      dot(g.sx, g.sy, g.cc, g.r)
      dot(g.sx - g.r * 3.2, g.sy + g.r * 0.6, g.nc, g.r * 0.7)
      g.fx.forEach((f) => {
        bt.globalAlpha = Math.min(1, f.t * 2)
        if (f.big) dot(f.x, f.y, f.c, g.r)
        else {
          bt.fillStyle = COL[f.c]
          bt.beginPath()
          bt.arc(f.x, f.y, g.r * 0.25, 0, 7)
          bt.fill()
        }
      })
      bt.globalAlpha = 1
      bt.fillStyle = '#fff'
      bt.font = 'bold 20px system-ui, sans-serif'
      bt.textAlign = 'left'
      bt.fillText('Scor ' + g.score, 14, 60)
      bt.textAlign = 'center'
      bt.fillText('Mutări: ' + g.shots, g.W / 2, 60)
      if (g.mt > 0) {
        bt.fillStyle = '#ffd86b'
        bt.font = 'bold 26px system-ui, sans-serif'
        bt.fillText(g.msg, g.W / 2, g.H / 2)
      }
    }

    const loop = (now) => {
      if (!alive) return
      const dt = Math.min((now - last) / 1000, 0.05)
      last = now
      step(dt)
      raf = requestAnimationFrame(loop)
    }
    raf = requestAnimationFrame(loop)

    const down = (e) => {
      if (!G.over) aim(e)
    }
    const move = (e) => {
      if (!G.over && e.buttons) aim(e)
    }
    const up = (e) => {
      if (G.over || G.mv || G.shots <= 0) return
      aim(e)
      const s = G.r * 30
      G.mv = { x: G.sx, y: G.sy, vx: Math.cos(G.a) * s, vy: -Math.sin(G.a) * s, c: G.cc }
      G.cc = G.nc
      G.nc = pickc()
      G.shots--
    }
    bc.addEventListener('pointerdown', down)
    bc.addEventListener('pointermove', move)
    bc.addEventListener('pointerup', up)
    window.addEventListener('resize', layout)
    return () => {
      alive = false
      cancelAnimationFrame(raf)
      bc.removeEventListener('pointerdown', down)
      bc.removeEventListener('pointermove', move)
      bc.removeEventListener('pointerup', up)
      window.removeEventListener('resize', layout)
    }
  }, [])

  // ✕ în timpul rundei: runda se abandonează fără recompensă (ca în original).
  const quit = () => {
    if (gameRef.current) gameRef.current.over = true
    closeBlast(false)
  }

  return (
    <div id="bw">
      <canvas id="bc" ref={cv} />
      <button id="bx" onClick={quit} aria-label="Închide">
        ✕
      </button>
      {result && (
        <div id="rs">
          <div>
            <h2>{result.won ? 'Nivel finalizat! 🎉' : 'Sfârșit de rundă'}</h2>
            <p>Scor: {result.score}</p>
            <p>Ai câștigat 🪙 {result.coins} monede</p>
            <button onClick={() => closeBlast(true)}>Înapoi pe insulă</button>
          </div>
        </div>
      )}
    </div>
  )
}
