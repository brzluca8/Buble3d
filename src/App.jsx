import { useEffect } from 'react'
import { useGame } from './store'
import { MODEL_NAMES } from './data'
import { idbGet } from './three/models'
import World from './three/World'
import { TopBar, XPBar, Title, Sheet, Nav, Toast } from './ui/Hud'
import { Modal, applyUserModel } from './ui/Modals'
import BubleBlast from './ui/BubleBlast'

let booted = false
function boot() {
  if (booted) return
  booted = true
  const g = useGame.getState()
  const ga = g.collectOffline()
  g.persist()
  if (ga) setTimeout(() => useGame.getState().showToast(`Bine ai revenit! Insula a produs 🪙 ${ga}`), 600)
  setInterval(() => useGame.getState().tickIncome(), 10000)
  // modelele alese anterior de utilizator (IndexedDB)
  Object.keys(MODEL_NAMES).forEach(async (k) => {
    const buf = await idbGet(k)
    if (buf) applyUserModel(k, buf).catch(() => {})
  })
}

export default function App() {
  const blastOpen = useGame((s) => s.blastOpen)
  const openBlast = useGame((s) => s.openBlast)
  const setModal = useGame((s) => s.setModal)
  useEffect(boot, [])

  return (
    <>
      <World />
      <div className="vignette" />
      <div id="ui">
        <TopBar />
        <XPBar />
        <Title />
        <Sheet />
        <button id="mdl" onClick={() => setModal('models')}>
          🧩 Modele 3D
        </button>
        <button id="blast" onClick={openBlast}>
          Buble Blast<span>JOACĂ ȘI CÂȘTIGĂ MONEDE</span>
        </button>
        <Nav />
        <Toast />
        <Modal />
        {blastOpen && <BubleBlast />}
      </div>
    </>
  )
}
