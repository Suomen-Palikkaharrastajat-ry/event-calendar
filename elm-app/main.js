import './main.css'
import { Elm } from './src/Main.elm'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import PocketBase from 'pocketbase'
import siteConfig from 'virtual:site-config'
import { resolveInitAuth, wirePocketBaseAuthPorts } from './packages/app-toolkit/js/pocketbase-auth.js'
import { appSettings, pickLang, requestedLang, showLanguage } from './packages/site-config/browser.mjs'

// Fix Leaflet default icon paths broken by Vite bundling
import markerIconUrl from 'leaflet/dist/images/marker-icon.png'
import markerIcon2xUrl from 'leaflet/dist/images/marker-icon-2x.png'
import markerShadowUrl from 'leaflet/dist/images/marker-shadow.png'

delete L.Icon.Default.prototype._getIconUrl
L.Icon.Default.mergeOptions({
  iconUrl: markerIconUrl,
  iconRetinaUrl: markerIcon2xUrl,
  shadowUrl: markerShadowUrl,
})

// ── App init ─────────────────────────────────────────────────────────────────

// App settings come from [app] in ../config.toml, in the language being shown.
const settings = appSettings(siteConfig, pickLang(siteConfig))
const pbBaseUrl = import.meta.env.VITE_POCKETBASE_URL || settings.pocketbase_url
// Signed-out visitors read the feed files published with the app (kalenteri.json and
// kalenteri-YYYY.json), not PocketBase. Empty means the same origin as the app.
const staticBaseUrl = import.meta.env.VITE_STATIC_BASE_URL || ''

const initAuth = await resolveInitAuth(pbBaseUrl, { PocketBase })

const flags = {
  authToken: initAuth.authToken,
  authModel: initAuth.authModel,
  now: Date.now(),
  pbBaseUrl,
  staticBaseUrl,
  siteConfig,
  requestedLang: requestedLang(siteConfig),
}

const app = Elm.Main.init({
  node: document.getElementById('app'),
  flags,
})

// ── Nav ports ─────────────────────────────────────────────────────────────────

app.ports.setDocumentLang.subscribe((lang) => showLanguage(siteConfig, lang))
app.ports.reportError.subscribe((problem) => console.error(problem))

// ── Auth ports ────────────────────────────────────────────────────────────────

wirePocketBaseAuthPorts(app, { PocketBase })

// ── Map ports (Leaflet) ───────────────────────────────────────────────────────

/** Registry of active Leaflet maps: containerId → { map, marker } */
const maps = {}

app.ports.initMap.subscribe(({ containerId, lat, lon, zoom, markerLat, markerLon, draggable }) => {
  // Defer until after Elm renders the container element into the DOM
  requestAnimationFrame(() => {
    // Destroy existing map if present
    if (maps[containerId]) {
      maps[containerId].map.remove()
      delete maps[containerId]
    }

    // The zoom buttons are named in the language being shown, not Leaflet's English.
    const map = L.map(containerId, { zoomControl: false }).setView([lat, lon], zoom)
    L.control
      .zoom({ zoomInTitle: settings.strings.zoom_in, zoomOutTitle: settings.strings.zoom_out })
      .addTo(map)
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    }).addTo(map)

    let marker = null
    if (markerLat !== null && markerLon !== null) {
      marker = L.marker([markerLat, markerLon], { draggable }).addTo(map)
      if (draggable) {
        marker.on('dragend', (e) => {
          const { lat: mlat, lng: mlon } = e.target.getLatLng()
          app.ports.mapMarkerMoved.send({ lat: mlat, lon: mlon })
        })
      }
    }

    maps[containerId] = { map, marker }
  })
})

app.ports.setMapMarker.subscribe(({ lat, lon }) => {
  Object.entries(maps).forEach(([, entry]) => {
    if (entry.marker) {
      entry.marker.setLatLng([lat, lon])
      entry.map.panTo([lat, lon])
    } else {
      const newMarker = L.marker([lat, lon], { draggable: true }).addTo(entry.map)
      newMarker.on('dragend', (e) => {
        const { lat: mlat, lng: mlon } = e.target.getLatLng()
        app.ports.mapMarkerMoved.send({ lat: mlat, lon: mlon })
      })
      entry.marker = newMarker
      entry.map.panTo([lat, lon])
    }
  })
})

app.ports.destroyMap.subscribe((containerId) => {
  if (maps[containerId]) {
    maps[containerId].map.remove()
    delete maps[containerId]
  }
})

// ── KML parsing port ──────────────────────────────────────────────────────────

// ── Pull-to-refresh ───────────────────────────────────────────────────────────

function setupPullToRefresh() {
  if (window.__pullToRefreshSetup) return
  window.__pullToRefreshSetup = true

  const isStandalone =
    window.matchMedia('(display-mode: standalone)').matches ||
    window.navigator.standalone === true
  if (!isStandalone) return

  const REVEAL_THRESHOLD = 20
  const ARM_THRESHOLD = 148
  const MAX_PULL_DISTANCE = 196
  const MENU_HEIGHT = 52
  const IMMEDIATE_REARM_MS = 400
  let startY = 0
  let currentY = 0
  let isPulling = false
  let isReloading = false
  let allowPullUntil = 0

  const indicator = document.createElement('div')
  indicator.setAttribute('aria-hidden', 'true')
  indicator.style.cssText = [
    'position:fixed',
    'top:0',
    'left:0',
    'right:0',
    'height:72px',
    'display:flex',
    'justify-content:center',
    'padding:8px 16px 12px',
    'z-index:9999',
    'pointer-events:none',
    'user-select:none',
    'transform:translateY(-100%)',
    'opacity:0',
    'margin-top:2rem',
  ].join(';')

  const action = document.createElement('div')
  action.style.cssText = [
    'display:flex',
    'align-items:center',
    'justify-content:center',
    'width:min(100%, 20rem)',
    `min-height:${MENU_HEIGHT}px`,
    'padding:0 16px',
    'color:#000000',
    'font-family:var(--font-sans, Outfit, system-ui, sans-serif)',
    'font-size:1.75rem',
    'font-weight:500',
    'line-height:1.5',
    'opacity:0.3',
    'border-bottom:2px solid transparent',
    'transform:translateY(0)',
  ].join(';')

  const label = document.createElement('span')
  label.textContent = settings.strings.refresh

  action.appendChild(label)
  indicator.appendChild(action)
  document.documentElement.appendChild(indicator)

  function clearPullState() {
    isPulling = false
    startY = 0
    currentY = 0
    indicator.style.transform = 'translateY(-100%)'
    indicator.style.opacity = '0'
    action.style.opacity = '0.3'
    action.style.borderBottomColor = 'transparent'
    action.style.transform = 'translateY(0)'
  }

  function updateIndicator(delta) {
    if (delta <= REVEAL_THRESHOLD) {
      indicator.style.transform = 'translateY(-100%)'
      indicator.style.opacity = '0'
      return
    }

    const progress = Math.min(
      (delta - REVEAL_THRESHOLD) / (MAX_PULL_DISTANCE - REVEAL_THRESHOLD),
      1
    )
    const translateY = -100 + 100 * progress
    const isArmed = delta >= ARM_THRESHOLD

    indicator.style.transform = `translateY(${translateY}%)`
    indicator.style.opacity = '1'
    action.style.transform = `translateY(${Math.max(0, 10 - (progress * 10))}px)`

    if (isArmed) {
      action.style.opacity = '1'
      action.style.borderBottomColor = '#000000'
    } else {
      action.style.opacity = '0.3'
      action.style.borderBottomColor = 'transparent'
    }
  }

  document.addEventListener('touchstart', function (e) {
    if (isReloading) return
    if (e.touches.length !== 1) { clearPullState(); return }

    const isAtTop = window.scrollY === 0
    const isWithinRearmWindow = performance.now() <= allowPullUntil

    if (isAtTop || isWithinRearmWindow) {
      startY = e.touches[0].clientY
      currentY = startY
      isPulling = true
    }
  }, { passive: true })

  document.addEventListener('touchmove', function (e) {
    if (!isPulling) return
    currentY = e.touches[0].clientY
    const delta = currentY - startY
    if (delta > 0) {
      updateIndicator(delta)
    } else {
      clearPullState()
    }
  }, { passive: true })

  document.addEventListener('touchend', function () {
    if (!isPulling) return
    const delta = currentY - startY
    allowPullUntil = performance.now() + IMMEDIATE_REARM_MS
    clearPullState()
    if (delta >= ARM_THRESHOLD && !isReloading) {
      isReloading = true
      setTimeout(() => window.location.reload(), 0)
    }
  }, { passive: true })

  document.addEventListener('touchcancel', function () {
    allowPullUntil = performance.now() + IMMEDIATE_REARM_MS
    clearPullState()
  }, { passive: true })
}

setupPullToRefresh()

// ── Swipe feedback ────────────────────────────────────────────────────────────
// Elm decides the month change on touchend. This only makes the gesture visible:
// once a swipe is clearly horizontal it locks vertical scrolling, moves the
// content with the finger and shows a chevron that firms up past the threshold.

function setupSwipeFeedback() {
  const AREA = '[data-swipe-area]'
  const LOCK_DISTANCE = 8
  const COMMIT_DISTANCE = 40 // keep in sync with Page.Calendar
  const MAX_SHIFT = 96
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)')

  const hint = document.createElement('div')
  hint.setAttribute('aria-hidden', 'true')
  hint.style.cssText = [
    'position:fixed',
    'top:50%',
    'width:48px',
    'height:48px',
    'margin-top:-24px',
    'display:flex',
    'align-items:center',
    'justify-content:center',
    'border-radius:9999px',
    'background:var(--color-brand, currentColor)',
    'color:var(--color-white, #fff)',
    'pointer-events:none',
    'z-index:9999',
    'opacity:0',
  ].join(';')
  const chevron = (d) =>
    '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" ' +
    'stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="' + d + '"/></svg>'
  document.documentElement.appendChild(hint)

  let area = null
  let startX = 0
  let startY = 0
  let mode = 'pending' // 'pending' | 'horizontal' | 'vertical'

  function reset(animate) {
    if (area) {
      area.style.transition = animate && !reduceMotion.matches ? 'transform 200ms ease-out, opacity 200ms ease-out' : 'none'
      area.style.transform = ''
      area.style.opacity = ''
    }
    hint.style.transition = reduceMotion.matches ? 'none' : 'opacity 150ms ease-out'
    hint.style.opacity = '0'
    area = null
    mode = 'pending'
  }

  document.addEventListener('touchstart', function (e) {
    if (e.touches.length !== 1) { if (area) reset(true); return }
    area = e.target.closest ? e.target.closest(AREA) : null
    if (!area) return
    startX = e.touches[0].clientX
    startY = e.touches[0].clientY
    mode = 'pending'
    area.style.transition = 'none'
  }, { passive: true })

  document.addEventListener('touchmove', function (e) {
    if (!area || mode === 'vertical') return
    const dx = e.touches[0].clientX - startX
    const dy = e.touches[0].clientY - startY

    if (mode === 'pending') {
      if (Math.max(Math.abs(dx), Math.abs(dy)) < LOCK_DISTANCE) return
      if (Math.abs(dx) > Math.abs(dy) * 1.5) {
        mode = 'horizontal'
      } else {
        mode = 'vertical'
        reset(false)
        return
      }
    }

    if (e.cancelable) e.preventDefault()

    const committed = Math.abs(dx) >= COMMIT_DISTANCE
    const shift = Math.sign(dx) * Math.min(Math.abs(dx) * 0.5, MAX_SHIFT)
    if (!reduceMotion.matches) {
      area.style.transform = `translateX(${shift}px)`
      area.style.opacity = committed ? '0.6' : '0.85'
    }
    // Swiping right shows the previous month, so the chevron points left.
    hint.innerHTML = chevron(dx > 0 ? 'M15 18l-6-6 6-6' : 'M9 18l6-6-6-6')
    hint.style.transition = 'none'
    hint.style.left = dx > 0 ? '8px' : 'auto'
    hint.style.right = dx > 0 ? 'auto' : '8px'
    hint.style.opacity = committed ? '1' : String(0.25 + 0.5 * (Math.abs(dx) / COMMIT_DISTANCE))
  }, { passive: false })

  document.addEventListener('touchend', function () { if (area) reset(true) }, { passive: true })
  document.addEventListener('touchcancel', function () { if (area) reset(true) }, { passive: true })
}

setupSwipeFeedback()

// ── KML ───────────────────────────────────────────────────────────────────────

app.ports.parseKml.subscribe((kmlContent) => {
  const parser = new DOMParser()
  const doc = parser.parseFromString(kmlContent, 'text/xml')
  const placemarks = Array.from(doc.querySelectorAll('Placemark')).map(pm => {
    const coordsText = pm.querySelector('coordinates')?.textContent?.trim()
    const coords = coordsText ? coordsText.split(',') : []
    return {
      name: pm.querySelector('name')?.textContent || '',
      description: pm.querySelector('description')?.textContent || '',
      lat: coords.length >= 2 ? parseFloat(coords[1]) : null,
      lon: coords.length >= 1 ? parseFloat(coords[0]) : null,
    }
  })
  app.ports.kmlParsed.send(placemarks)
})
