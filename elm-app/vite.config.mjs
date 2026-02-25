import { defineConfig } from 'vite'
import elm from 'vite-plugin-elm'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [
    elm(),
    tailwindcss(),
  ],
  publicDir: 'public',
  build: {
    outDir: '../build',
    emptyOutDir: true,
  },
  // Hash routing in Elm means no server-side rewrite needed
  base: '/',
})
