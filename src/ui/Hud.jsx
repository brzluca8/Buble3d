import { useGame, sumLevels, upgradeCost, playerLevel } from '../store'
import { BUILDINGS, MAX_LVL } from '../data'

export function TopBar() {
  const coins = useGame((s) => s.save.coins)
  const xp = useGame((s) => s.save.xp)
  return (
    <div id="top">
      <div className="logo">
        <div className="av">☺</div>
        <b>Buble</b>
      </div>
      <div className="pill">🪙 {Math.floor(coins).toLocaleString('ro-RO')}</div>
      <div className="badge">
        NIVEL<b>{playerLevel(xp)}</b>
      </div>
    </div>
  )
}

export function XPBar() {
  const xp = useGame((s) => s.save.xp)
  const b = useGame((s) => s.save.b)
  const mis = useGame((s) => s.save.mis)
  const showToast = useGame((s) => s.showToast)
  return (
    <div id="xpbar">
      <span>
        Dezvoltă insula • <b>{sumLevels(b)}/25</b> niveluri
      </span>
      <button
        id="mis"
        onClick={() =>
          showToast(`${mis.up ? '✅' : '⬜'} Îmbunătățește o clădire  •  ${mis.blast ? '✅' : '⬜'} Joacă Buble Blast`, 3500)
        }
      >
        Misiuni
      </button>
      <div className="bar">
        <i style={{ width: `${xp % 100}%` }} />
      </div>
    </div>
  )
}

export function Title() {
  const sel = useGame((s) => s.sel)
  return (
    <div id="title" style={{ opacity: sel ? 0 : 1 }}>
      Grădina dintre nori<small>Atinge o clădire ca să o dezvolți</small>
    </div>
  )
}

export function Sheet() {
  const sel = useGame((s) => s.sel)
  const save = useGame((s) => s.save)
  const upgrade = useGame((s) => s.upgrade)
  const b = BUILDINGS.find((x) => x.id === sel)
  if (!b) return null
  const l = save.b[b.id],
    cs = upgradeCost(b, l),
    lack = save.coins < cs
  return (
    <div id="sheet" key={b.id}>
      <div className="sh1">
        <b>{b.n}</b>
        <span>
          Nivel {l}/{MAX_LVL}
        </span>
      </div>
      <div className="pips">
        {'●'.repeat(l)}
        {'○'.repeat(MAX_LVL - l)}
      </div>
      {l >= MAX_LVL ? (
        <div className="mx">✨ Nivel maxim atins</div>
      ) : (
        <>
          <button id="up" className={lack ? 'dis' : ''} onClick={upgrade}>
            Îmbunătățește · 🪙 {cs}
          </button>
          {lack && <small>Îți mai trebuie {Math.ceil(cs - save.coins)} monede. Joacă Buble Blast!</small>}
        </>
      )}
    </div>
  )
}

const NAV = [
  ['home', '🏠', 'Acasă'],
  ['album', '🃏', 'Album'],
  ['friends', '👥', 'Prieteni'],
  ['events', '🏆', 'Evenimente'],
  ['shop', '🏪', 'Magazin'],
]
export function Nav() {
  const modal = useGame((s) => s.modal)
  const setModal = useGame((s) => s.setModal)
  const cur = NAV.some((n) => n[0] === modal) ? modal : 'home'
  return (
    <nav>
      {NAV.map(([m, i, t]) => (
        <button key={m} className={cur === m ? 'on' : ''} onClick={() => setModal(m === 'home' ? null : m)}>
          <i>{i}</i>
          {t}
        </button>
      ))}
    </nav>
  )
}

export function Toast() {
  const t = useGame((s) => s.toast)
  return <div id="toast" className={t.on ? 'on' : ''}>{t.msg}</div>
}
