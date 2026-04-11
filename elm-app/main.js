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

const pbBaseUrl = import.meta.env.VITE_POCKETBASE_URL || 'https://data.palikkaharrastajat.fi'

function readStoredAuth() {
  return {
    authToken: localStorage.getItem('pb_auth_token') || null,
    authModel: localStorage.getItem('pb_auth_model') || null,
  }
}

function clearStoredAuth() {
  localStorage.removeItem('pb_auth_token')
  localStorage.removeItem('pb_auth_model')
}

function saveStoredAuth(token, model) {
  localStorage.setItem('pb_auth_token', token)
  localStorage.setItem('pb_auth_model', model)
}

function isInvalidAuthError(err) {
  return err?.status === 401 || err?.status === 403
}

async function resolveInitAuth(pbUrl) {
  const stored = readStoredAuth()
  if (!stored.authToken || !stored.authModel) {
    return { authToken: null, authModel: null }
  }

  const pb = new PocketBase(pbUrl)
  pb.authStore.save(stored.authToken, null)

  try {
    const authData = await pb.collection('users').authRefresh()
    const refreshedModel = JSON.stringify({
      id: authData.record.id,
      name: authData.record.name || '',
      email: authData.record.email || '',
    })

    saveStoredAuth(authData.token, refreshedModel)
    return { authToken: authData.token, authModel: refreshedModel }
  } catch (err) {
    if (isInvalidAuthError(err)) {
      clearStoredAuth()
      return { authToken: null, authModel: null }
    }

    console.warn('Auth refresh failed during app init, keeping stored auth:', err)
    return stored
  }
}

const initAuth = await resolveInitAuth(pbBaseUrl)

const flags = {
  authToken: initAuth.authToken,
  authModel: initAuth.authModel,
  now: Date.now(),
  pbBaseUrl,
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
  label.textContent = '⟳ Päivitä sivu'

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
