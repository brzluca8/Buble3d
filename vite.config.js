import { defineConfig } from 'vite';
// base relativ: build-ul merge și din subfolder (GitHub Pages) și în Capacitor
export default defineConfig({ base: './', build: { chunkSizeWarningLimit: 900 } });
