import { useGame } from '../store'
import { MODEL_NAMES } from '../data'
import { parseGLB, normalize, idbSet, idbDel, PUBLIC_MODELS, brokenPublic } from '../three/models'

const Demo = ({ children }) => <span className="demo">{children}</span>
const Row = ({ a, b = 'În curând' }) => (
  <div className="row">
    <span>{a}</span>
    <span>{b}</span>
  </div>
)

const SCREENS = {
  album: () => (
    <>
      <h2>Album</h2>
      <Demo>DEMO – fără server</Demo>
      <p>Colecția de cărți se va debloca din Buble Blast și evenimente. Schimburile necesită conturi online.</p>
      <div className="grid">
        {Array.from({ length: 12 }, (_, i) => (
          <div key={i}>🔒</div>
        ))}
      </div>
    </>
  ),
  friends: () => (
    <>
      <h2>Prieteni</h2>
      <Demo>DEMO – fără server</Demo>
      <p>Prietenii, vizitarea insulelor și duelurile necesită cont și backend. În această versiune nu există alți jucători.</p>
      <Row a="Invită un prieten" />
      <Row a="Vizitează o insulă" />
    </>
  ),
  events: () => (
    <>
      <h2>Evenimente</h2>
      <Demo>DEMO – fără server</Demo>
      <p>Expediția celor patru: eveniment cooperativ pentru 4 persoane.</p>
      <div className="grid">
        {Array.from({ length: 4 }, (_, i) => (
          <div key={i} style={{ fontSize: 12 }}>
            Liber
          </div>
        ))}
      </div>
      <Row a="Clasament cluburi" />
    </>
  ),
  shop: () => (
    <>
      <h2>Magazin</h2>
      <Demo>DEMO – plăți dezactivate</Demo>
      <Row a="🪙 Pachete de monede" />
      <Row a="👑 Abonament VIP" />
      <Row a="🎟️ Season Pass" />
    </>
  ),
  models: ModelsPanel,
}

export async function applyUserModel(k, buf) {
  const gltf = await parseGLB(buf)
  useGame.getState().setUserModel(k, { scene: normalize(k, gltf.scene), animations: gltf.animations })
}

function ModelsPanel() {
  const userModels = useGame((s) => s.userModels)
  const quality = useGame((s) => s.quality)
  const setQuality = useGame((s) => s.setQuality)
  const showToast = useGame((s) => s.showToast)

  const onFile = async (k, e) => {
    const f = e.target.files[0]
    e.target.value = ''
    if (!f) return
    const buf = await f.arrayBuffer()
    try {
      await applyUserModel(k, buf)
      idbSet(k, buf)
      showToast(`${MODEL_NAMES[k]}: model încărcat`)
    } catch {
      showToast('Fișier GLB invalid')
    }
  }
  const reset = (k) => {
    useGame.getState().setUserModel(k, null)
    idbDel(k)
    showToast(`${MODEL_NAMES[k]}: ${PUBLIC_MODELS.has(k) && !brokenPublic.has(k) ? 'modelul din joc restabilit' : 'model procedural restabilit'}`)
  }
  const status = (k) =>
    userModels[k]
      ? 'fișierul tău'
      : brokenPublic.has(k)
        ? 'GLB din joc invalid → procedural'
        : PUBLIC_MODELS.has(k)
          ? 'GLB din joc'
          : 'procedural'

  return (
    <>
      <h2>Modele 3D</h2>
      <p>
        Alege un fișier .glb pentru fiecare piesă. Modelul înlocuiește varianta procedurală și rămâne salvat pe telefon.
      </p>
      {Object.keys(MODEL_NAMES).map((k) => (
        <div className="row mrow" key={k}>
          <span>
            {MODEL_NAMES[k]}
            <em>{status(k)}</em>
          </span>
          <span>
            <label className="file">
              Alege .glb
              <input type="file" accept=".glb,model/gltf-binary" onChange={(e) => onFile(k, e)} />
            </label>
            <button className="mini" onClick={() => reset(k)} title="Revino la modelul implicit" disabled={!userModels[k]}>
              ↺
            </button>
          </span>
        </div>
      ))}
      <h3>Calitate grafică</h3>
      <div className="seg">
        <button className={quality === 'inalta' ? 'on' : ''} onClick={() => setQuality('inalta')}>
          Înaltă
        </button>
        <button className={quality === 'scazuta' ? 'on' : ''} onClick={() => setQuality('scazuta')}>
          Scăzută
        </button>
      </div>
      <small>Calitatea înaltă activează strălucirea (bloom) și umbre fine. Pe telefoane lente, alege „Scăzută".</small>
    </>
  )
}

export function Modal() {
  const modal = useGame((s) => s.modal)
  const setModal = useGame((s) => s.setModal)
  if (!modal) return null
  const Screen = SCREENS[modal]
  return (
    <div id="md" onPointerDown={(e) => e.target.id === 'md' && setModal(null)}>
      <div className="card">
        <button className="x" onClick={() => setModal(null)} aria-label="Închide">
          ✕
        </button>
        <Screen />
      </div>
    </div>
  )
}
