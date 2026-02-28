# AGENTS.md

This file provides instructions for AI coding agents working with this project.

## Project Overview

Event calendar for *Suomen Palikkayhteisö ry*, built with **Elm 0.19 SPA** (frontend) and a **Haskell static generator** (feeds, HTML, images), backed by **PocketBase**.

The project was migrated from SvelteKit 5 in early 2026. There is **no TypeScript, no Svelte, no ESLint, and no Prettier** in the current codebase. Ignore any references to those tools in older docs.

## Repository Layout

```
elm-app/          Elm 0.19 SPA (Vite + vite-plugin-elm + Tailwind CSS 4)
  src/            Elm source modules (Main, Types, Route, Api, Auth, Ports, I18n, DateUtils, Geocoding)
  src/Page/       Page-level Elm modules (Calendar, Events, EventDetail, EventEdit)
  src/View/       View helpers (Layout, Calendar, Events, EventForm, EventDetail, MapWidget, EventList)
  tests/          Elm unit tests — elm-explorations/test (81 tests)
  public/         Static assets (Leaflet marker icons)
statics/          Haskell static generator (Cabal)
  src/            Library modules (PocketBase, DateUtils, ICalGen, FeedGen, GeoJsonGen, HtmlGen, ImageFetcher)
  app/Main.hs     Executable entry point
  tests/Main.hs   Haskell tests — tasty (72 tests)
static/           Files copied verbatim into build/ (e.g. .nojekyll)
refactoring-plan/ Migration documentation (historical reference only)
.github/workflows CI/CD: build.yml (push to main → GitHub Pages), hourly-build.yml
```

## Development Environment

The project uses **devenv** (Nix). Always run commands inside the devenv shell, either with `make shell` (interactive) or prefixed with `devenv shell --`.

**Bootstrap (first time):**
```sh
make develop   # creates devenv.local.nix + devenv.local.yaml, opens VS Code
```

**Enter the shell interactively:**
```sh
make shell
```

## Build and Test Commands

All commands are defined in the `Makefile`. Run them from the repo root:

| Command | Description |
|---------|-------------|
| `make elm-dev` | Start Elm + Vite dev server (hot reload) at http://localhost:5173 |
| `make elm-build` | Production build of Elm SPA → `build/` |
| `make elm-test` | Run Elm unit tests |
| `make elm-check` | Validate Elm formatting (elm-format --validate) |
| `make elm-format` | Auto-format Elm source files |
| `make statics-build` | Build Haskell static generator |
| `make statics` | Run generator (fetches live events, writes static files to `build/`) |
| `make statics-test` | Run Haskell unit tests |
| `make statics-check` | Lint Haskell source (hlint) |
| `make statics-format` | Auto-format Haskell source (fourmolu) |
| `make test` | Run all tests (Elm + Haskell) |
| `make dist` | Full production build: Elm SPA + static files |
| `make format` | Auto-format all source files |
| `make check` | Validate all formatting without changes |
| `make clean` | Remove `build/` |

**First-time Haskell setup** — run `cabal update` before the first `cabal build statics` in a fresh environment.

## Code Style

### Elm
- Formatter: **elm-format** (enforced via `make elm-check`)
- elm-format is opinionated; do not configure it manually — just run it.

### Haskell
- Formatter: **fourmolu** (config in `statics/fourmolu.yaml`)
- Settings: indentation 4, column-limit 100, function-arrows leading, comma-style leading, import-export-style diff-friendly
- Linter: **hlint** (run via `make statics-check`)
- Extension `OverloadedStrings` is enabled by default in `statics.cabal` (required for aeson 2.x).

## Architecture Notes

### Elm SPA
- Hash routing: `/#/calendar`, `/#/events`, `/#/events/:id`, `/#/events/:id/edit`
- The URL fragment is parsed as a path; query params are split off before routing.
- `PageEventList` is the public events list page; the calendar has no list-view toggle.
- Maps use **Leaflet** via Elm ports (`elm-app/src/Ports.elm`). Geocoding uses Nominatim.
- Auth is OAuth2/OIDC via PocketBase. `requireAuth` takes a `Browser.Navigation.Key`.
- PocketBase URL is compiled in via `elm-app/src/Api.elm`. For local dev, set `POCKETBASE_URL`.
- `RemoteData` (krisajenkins/remotedata) is used for async API state.
- Pagination uses a custom `PbList a` wrapper (not plain `List a`).

### Haskell Static Generator
- Fetches live events from PocketBase REST API (`statics/src/PocketBase.hs`).
- Generates: iCal (ICalGen), RSS/Atom/JSON Feed (FeedGen), GeoJSON (GeoJsonGen), printable HTML + per-event pages (HtmlGen), event images (ImageFetcher).
- QR codes via `qrcode-juicypixels` (custom Nix override): use `QRJP.toPngDataUrlS`.
- ICS files embedded in feeds as `text/calendar` enclosures (base64-encoded).
- `statics/app/Main.hs` calls `setLocaleEncoding utf8` — required because the devcontainer locale ≠ UTF-8.
- `iCalendar` Haskell library is unmaintained; ICalGen.hs uses manual RFC 5545 text generation instead.

## Known Gotchas

- **elm-test wrapper**: pnpm installs a broken Node-wrapping `elm` binary. The `make elm-test` target rewrites `elm-app/node_modules/.bin/elm` to call the system ELF binary directly. Do not remove this workaround.
- **cabal vs stack**: `planet/` (reference implementation) uses Stack — it is **not** part of `cabal.project`. The `cabal.project` file manages only `statics/`.
- **GHC version**: 9.10.3 (via devenv/Nix). CI uses `haskell-actions/setup` with `ghc-version: '9.10'`.
- **JSON decoders in Elm tests**: `Json.Decode.decodeString` returns `Result Json.Error a`, not `Result String a`.

## Manual E2E Test Checklist

Run these checks in a real browser before releasing. Automated Elm/Haskell unit tests do not cover these scenarios.

### Mobile responsive
- [ ] Calendar month grid renders without horizontal overflow on a 375 px wide viewport
- [ ] Event detail page is readable on mobile (no clipped text, tap targets ≥ 44 px)
- [ ] Events management page (create form, KML import) usable on mobile

### Accessibility (keyboard navigation)
- [ ] Calendar is fully navigable with Tab / Enter (month nav, event links)
- [ ] Event detail page: pressing `e` opens the edit page (when authenticated); `Escape` goes back
- [ ] Create/edit forms: all inputs reachable via Tab; dropdowns operable with keyboard

### Event CRUD flow (requires login)
- [ ] Login via OAuth popup → redirected to events management page → toast "Kirjautuminen onnistui"
- [ ] Create event: fill all fields including image → save → event appears in list → detail page correct
- [ ] Edit event: change title and date → save → detail page shows updated values
- [ ] Delete event: detail page → "Poista" → confirm → toast "Tapahtuma poistettu" → redirected to events list
- [ ] Logout → trying to navigate to `/#/events/new` redirects to calendar with info toast

### KML import (requires login)
- [ ] Upload a valid KML file → placemarks parsed → import runs → N events created → KmlDone toast
- [ ] Upload a KML with zero placemarks → KmlDone 0 (no crash)
- [ ] Upload an invalid (non-KML) file → no import started or graceful error

### Feeds and static output (`make statics`)
- [ ] `build/kalenteri.ics` opens in a calendar app and shows all published events
- [ ] `build/kalenteri.rss` validates at https://validator.w3.org/feed/
- [ ] `build/kalenteri.atom` validates at https://validator.w3.org/feed/
- [ ] `build/kalenteri.html` renders correctly in a browser; QR codes visible when printing
- [ ] A per-event `.html` page (e.g. `build/events/<id>.html`) renders with title, date, and QR code

## Security

- **Primary colors** (dark violet): `primary-50` through `primary-900` (generates `bg-primary-*`, `text-primary-*`, etc.)
- **Brand colors**: `brand-primary`, `brand-secondary`, `brand-accent`, `brand-dark`, `brand-highlight`

## Security Considerations

- The application uses PocketBase for the backend, which is hosted at `https://data.palikkaharrastajat.fi`. Ensure that the PocketBase security rules are properly configured to prevent unauthorized access to data.
- Authentication is handled via OAuth2 with an OIDC provider. The authentication logic is in `src/lib/auth.ts`.
- When making changes to the authentication or data access logic, be sure to test thoroughly to prevent security vulnerabilities.
