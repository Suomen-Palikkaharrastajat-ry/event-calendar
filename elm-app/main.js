import './main.css'
import { Elm } from './src/Main.elm'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import PocketBase from 'pocketbase'

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

const flags = {
  authToken: localStorage.getItem('pb_auth_token') || null,
  authModel: localStorage.getItem('pb_auth_model') || null,
  now: Date.now(),
  pbBaseUrl: import.meta.env.VITE_POCKETBASE_URL || 'https://data.palikkaharrastajat.fi',
}

const app = Elm.Main.init({
  node: document.getElementById('app'),
  flags,
})

// ── Nav ports ─────────────────────────────────────────────────────────────────

app.ports.focusMobileNav.subscribe(function () {
  requestAnimationFrame(function () {
    const el = document.getElementById('mobile-nav-active') || document.querySelector('#mobile-nav a')
    if (el) el.focus({ focusVisible: true })
  })
})

// ── Auth ports ────────────────────────────────────────────────────────────────

app.ports.initiateOAuth.subscribe(async (pbBaseUrl) => {
  try {
    const pb = new PocketBase(pbBaseUrl)
    const authData = await pb.collection('users').authWithOAuth2({ provider: 'oidc' })
    app.ports.oauthPopupResult.send({
      token: authData.token,
      model: JSON.stringify({
        id: authData.record.id,
        name: authData.record.name || '',
        email: authData.record.email || '',
      }),
    })
  } catch (err) {
    console.error('OAuth2 login failed:', err)
    app.ports.oauthPopupResult.send({ token: '', model: '{}' })
  }
})

app.ports.saveAuthToken.subscribe(({ token, model }) => {
  localStorage.setItem('pb_auth_token', token)
  localStorage.setItem('pb_auth_model', model)
})

app.ports.clearAuthToken.subscribe(() => {
  localStorage.removeItem('pb_auth_token')
  localStorage.removeItem('pb_auth_model')
})

app.ports.getCallbackParams.subscribe(() => {
  app.ports.callbackParams.send({
    codeVerifier: sessionStorage.getItem('pb_code_verifier') || '',
    state: sessionStorage.getItem('pb_provider_state') || '',
  })
})

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

    const map = L.map(containerId).setView([lat, lon], zoom)
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
  Object.values(maps).forEach(({ map, marker }) => {
    if (marker) {
      marker.setLatLng([lat, lon])
      map.panTo([lat, lon])
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

  const HINT_THRESHOLD = 24
  const RELEASE_THRESHOLD = 128
  const MAX_INDICATOR_HEIGHT = 72
  const MIN_INDICATOR_HEIGHT = 44
  let startY = 0
  let currentY = 0
  let isPulling = false
  let isReloading = false

  const indicator = document.createElement('div')
  indicator.setAttribute('aria-hidden', 'true')
  indicator.style.cssText = [
    'position:fixed',
    'top:0',
    'left:0',
    'right:0',
    'height:0',
    'overflow:hidden',
    'display:flex',
    'align-items:center',
    'justify-content:center',
    'background:#fff',
    'color:#05131D',
    'font-family:system-ui,sans-serif',
    'font-size:1.75rem',
    'z-index:9999',
    'transition:height 0.15s ease',
    'pointer-events:none',
    'user-select:none',
  ].join(';')
  document.documentElement.appendChild(indicator)

  function clearPullState() {
    isPulling = false
    startY = 0
    currentY = 0
    indicator.style.height = '0'
  }

  function navigateForRefresh() {
    isReloading = true
    window.location.reload()
  }

  document.addEventListener('touchstart', function (e) {
    if (isReloading) return
    if (e.touches.length !== 1) { clearPullState(); return }
    if (window.scrollY === 0) {
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
      if (delta <= HINT_THRESHOLD) {
        indicator.style.height = '0'
        indicator.textContent = ''
        return
      }
      const progress = Math.min(
        (delta - HINT_THRESHOLD) / (RELEASE_THRESHOLD - HINT_THRESHOLD),
        1
      )
      const height = MIN_INDICATOR_HEIGHT + ((MAX_INDICATOR_HEIGHT - MIN_INDICATOR_HEIGHT) * progress)
      indicator.style.height = height + 'px'
      indicator.textContent = delta >= RELEASE_THRESHOLD
        ? '✓ Vapauta päivittämään'
        : '↓ Vedä päivittääksesi'
    } else {
      clearPullState()
    }
  }, { passive: true })

  document.addEventListener('touchend', function () {
    if (!isPulling) return
    const delta = currentY - startY
    clearPullState()
    if (delta >= RELEASE_THRESHOLD && !isReloading) {
      setTimeout(navigateForRefresh, 150)
    }
  }, { passive: true })

  document.addEventListener('touchcancel', clearPullState, { passive: true })
}

setupPullToRefresh()

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
      dateStr: null,  // TODO: extract date from description if present
    }
  })
  app.ports.kmlParsed.send(placemarks)
})
