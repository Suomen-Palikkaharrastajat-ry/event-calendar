import { createReadStream, statSync } from 'node:fs'
import { extname, join, normalize, resolve } from 'node:path'
import { defineConfig } from 'vite'
import tailwindcss from '@tailwindcss/vite'
import elmTailwind from 'elm-tailwind-classes/vite'
import elm from 'vite-plugin-elm'
import siteConfig from './packages/site-config/vite.mjs'

// The SPA reads kalenteri*.json and images/ from the site root when signed out. They are
// written into ../assets by `make statics`, and production copies them into dist/; the dev
// server serves them from there.
const assetsDir = resolve(import.meta.dirname, '../assets')
const assetTypes = { '.json': 'application/json', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.gif': 'image/gif', '.webp': 'image/webp' }

function staticsAssets() {
  return {
    name: 'statics-assets',
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        let file
        try {
          const path = normalize(decodeURIComponent((req.url || '').split('?')[0]))
          if (!/^\/(kalenteri[^/]*\.json|images\/[^/]+)$/.test(path)) return next()
          file = join(assetsDir, path)
          if (!statSync(file).isFile()) return next()
        } catch {
          // A malformed URL or a file `make statics` has not written yet
          return next()
        }
        res.setHeader('Content-Type', assetTypes[extname(file).toLowerCase()] || 'application/octet-stream')
        createReadStream(file)
          .on('error', (err) => next(err))
          .pipe(res)
      })
    },
  }
}

export default defineConfig({
  publicDir: 'public',
  plugins: [
    // config.toml → document head, site.webmanifest and virtual:site-config
    siteConfig(),
    staticsAssets(),
    elmTailwind(),
    elm(),
    tailwindcss(),
  ],
  build: {
    outDir: '../dist',
    emptyOutDir: true,
  },
  // Hash routing in Elm means no server-side rewrite needed
  base: '/',
})
