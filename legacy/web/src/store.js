import { create } from 'zustand'
import { BUILDINGS, MAX_LVL } from './data'

const KEY = 'buble3d' // aceeași cheie ca în buble.html, salvările vechi rămân valabile
const QKEY = 'buble3d-q'

const fresh = () => ({
  coins: 300,
  xp: 0,
  b: { palat: 1, obs: 1, turn: 1, mag: 1, sera: 1 },
  t: 0,
  mis: { up: 0, blast: 0 },
})

function load() {
  const s = fresh()
  try {
    const raw = JSON.parse(localStorage.getItem(KEY))
    if (raw && raw.b) {
      Object.assign(s, raw)
      s.b = { ...fresh().b, ...raw.b }
      s.mis = { ...fresh().mis, ...raw.mis }
    }
  } catch {
    /* salvare coruptă sau stocare indisponibilă */
  }
  return s
}

function loadQuality() {
  try {
    const q = localStorage.getItem(QKEY)
    if (q === 'inalta' || q === 'scazuta') return q
  } catch {
    /* ignore */
  }
  return 'inalta'
}

export const sumLevels = (b) => Object.values(b).reduce((a, v) => a + v, 0)
export const upgradeCost = (bld, lvl) => Math.round(bld.b * Math.pow(lvl, 1.7))
export const playerLevel = (xp) => 1 + Math.floor(xp / 100)

export const useGame = create((set, get) => ({
  save: load(),
  quality: loadQuality(),
  sel: null, // id-ul clădirii selectate
  modal: null, // 'album' | 'friends' | 'events' | 'shop' | 'models' | null
  blastOpen: false,
  toast: { msg: '', on: false, id: 0 },
  // Evenimente pentru scena 3D (contoare: scena reacționează când se schimbă).
  jump: 0,
  pop: { id: null, n: 0 },
  // Modele GLB încărcate de utilizator (IndexedDB) – obiecte three parse-uite.
  userModels: {},

  persist() {
    const s = { ...get().save, t: Date.now() }
    set({ save: s })
    try {
      localStorage.setItem(KEY, JSON.stringify(s))
    } catch {
      /* ignore */
    }
  },

  showToast(msg, ms = 2200) {
    const id = get().toast.id + 1
    set({ toast: { msg, on: true, id } })
    setTimeout(() => {
      if (get().toast.id === id) set({ toast: { msg, on: false, id } })
    }, ms)
  },

  select(id) {
    set({ sel: id })
  },

  upgrade() {
    const { sel, save } = get()
    const bld = BUILDINGS.find((b) => b.id === sel)
    if (!bld) return
    const lvl = save.b[bld.id]
    const cs = upgradeCost(bld, lvl)
    if (lvl >= MAX_LVL || save.coins < cs) return
    set({
      save: {
        ...save,
        coins: save.coins - cs,
        xp: save.xp + 40,
        b: { ...save.b, [bld.id]: lvl + 1 },
        mis: { ...save.mis, up: 1 },
      },
      pop: { id: bld.id, n: get().pop.n + 1 },
      jump: get().jump + 1,
    })
    get().showToast(`${bld.n} a ajuns la nivelul ${lvl + 1} ✨`)
    get().persist()
  },

  addCoins(n) {
    set({ save: { ...get().save, coins: get().save.coins + n } })
  },

  // Venit pasiv: suma nivelurilor la fiecare 10 s.
  tickIncome() {
    get().addCoins(sumLevels(get().save.b))
    get().persist()
  },

  // Venit offline, maximum 1 h. Returnează monedele câștigate.
  collectOffline() {
    const s = get().save
    const el = Math.min((Date.now() - (s.t || Date.now())) / 1000, 3600)
    if (el <= 30) return 0
    const ga = Math.floor((el / 10) * sumLevels(s.b))
    get().addCoins(ga)
    return ga
  },

  blastReward(score, won) {
    const co = Math.floor(score / 4) + (won ? 100 : 0)
    const s = get().save
    set({
      save: {
        ...s,
        coins: s.coins + co,
        xp: s.xp + Math.floor(score / 5) + (won ? 30 : 0),
        mis: { ...s.mis, blast: 1 },
      },
    })
    get().persist()
    return co
  },

  setModal(modal) {
    set({ modal })
  },
  openBlast() {
    set({ blastOpen: true })
  },
  closeBlast(rewarded) {
    set({ blastOpen: false, jump: rewarded ? get().jump + 1 : get().jump })
    if (rewarded) get().showToast('Monedele au fost adăugate în insulă 🪙')
  },

  setQuality(q) {
    set({ quality: q })
    try {
      localStorage.setItem(QKEY, q)
    } catch {
      /* ignore */
    }
  },

  setUserModel(k, obj) {
    const m = { ...get().userModels }
    if (obj) m[k] = obj
    else delete m[k]
    set({ userModels: m })
  },
}))
