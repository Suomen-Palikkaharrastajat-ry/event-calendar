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
}

const app = Elm.Main.init({
  node: document.getElementById('app'),
  flags,
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
