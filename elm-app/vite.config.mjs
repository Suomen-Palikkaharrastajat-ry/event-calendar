import { defineConfig } from 'vite'
import elmTailwind from 'elm-tailwind-classes/vite'
import elm from 'vite-plugin-elm'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [
    elmTailwind(),
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
