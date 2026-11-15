import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import fs from 'node:fs'
import path from 'node:path'

const MODELS_DIR = path.resolve('public/models')
const VIRTUAL = 'virtual:model-manifest'

// Lists the .glb files present in public/models at build/dev time, so the app
// only requests models that exist (no 404s, no HTML fallback parsed as GLB).
function bubleAssets() {
  const list = () =>
    fs.existsSync(MODELS_DIR)
      ? fs.readdirSync(MODELS_DIR).filter((f) => f.toLowerCase().endsWith('.glb')).map((f) => f.slice(0, -4))
      : []
  return {
    name: 'buble-assets',
    resolveId(id) {
      if (id === VIRTUAL) return '\0' + VIRTUAL
    },
    load(id) {
      if (id === '\0' + VIRTUAL) return `export default ${JSON.stringify(list())}`
    },
    configureServer(server) {
      server.watcher.add(MODELS_DIR)
      const reload = (f) => {
        if (!f.startsWith(MODELS_DIR) || !f.endsWith('.glb')) return
        const m = server.moduleGraph.getModuleById('\0' + VIRTUAL)
        if (m) server.moduleGraph.invalidateModule(m)
        server.ws.send({ type: 'full-reload' })
      }
      server.watcher.on('add', reload)
      server.watcher.on('unlink', reload)
      server.watcher.on('change', reload)
    },
  }
}

export default defineConfig({
  base: './',
  plugins: [react(), bubleAssets()],
  build: { chunkSizeWarningLimit: 2000 },
})
