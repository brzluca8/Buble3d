// Date statice ale jocului (portate din buble.html).
export const BUILDINGS = [
  { id: 'palat', n: 'Palatul Norilor', x: 0, z: -4, b: 150 },
  { id: 'obs', n: 'Observatorul', x: -4.6, z: -1.2, b: 100 },
  { id: 'turn', n: 'Turnul Elegant', x: 4.6, z: -1.2, b: 100 },
  { id: 'mag', n: 'Magazinul', x: -4, z: 2.6, b: 80 },
  { id: 'sera', n: 'Sera de Cristal', x: 4, z: 2.6, b: 90 },
]
export const MAX_LVL = 5

// Înălțimi țintă pentru modelele GLB (insula se scalează după diametru).
export const MODEL_HEIGHT = { palat: 5.5, obs: 4.5, turn: 5.3, mag: 3, sera: 3, mascot: 1.6 }
export const ISLAND_DIAMETER = 14.4
export const MODEL_NAMES = {
  palat: 'Palat',
  obs: 'Observator',
  turn: 'Turn',
  mag: 'Magazin',
  sera: 'Seră',
  mascot: 'Mascotă',
  insula: 'Insulă',
}

export const WATERFALLS = [
  [-4.4, 5.2],
  [4.4, 5.2],
]
