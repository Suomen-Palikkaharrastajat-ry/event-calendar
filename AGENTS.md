# AGENTS.md

This file provides instructions for AI coding agents working with this project.

## Project Overview

Event calendar for *Suomen Palikkaharrastajat ry*, built with **Elm 0.19 SPA** (frontend) and a **Haskell static generator** (feeds, HTML, images), backed by **PocketBase**.

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

## Style Guide

The association's official design guide lives at **<https://logo.palikkaharrastajat.fi/>**. Machine-readable JSON-LD: <https://logo.palikkaharrastajat.fi/design-guide/index.jsonld>.

### Key design tokens

| Token | Value | Tailwind class |
|---|---|---|
| brand-black | `#05131D` | `bg-brand` / `text-brand` / `border-brand` |
| brand-yellow | `#FAC80A` | `bg-brand-yellow` |
| white | `#FFFFFF` | `text-white` / `bg-white` |
| red (danger/accent) | `#C91A09` | `bg-red` (custom) |
| text.muted | `#6B7280` | `text-gray-500` |
| background.subtle | `#F9FAFB` | `bg-gray-50` |
| border.default | `#E5E7EB` | `border-gray-200` |

> **Note:** The canonical yellow value is `#FAC80A` (from `colors.jsonld`). Do not use `#F2CD37` — it is incorrect.

### Typography

- **Font**: Outfit variable font (wght axis 100–900), `font-family: 'Outfit', system-ui, sans-serif`. Self-hosted from `elm-app/public/fonts/`.
- **Named type scale** (use CSS classes, never raw sizes in components):

| Class | Size | Weight | Notes |
|---|---|---|---|
| `.type-display` | 3rem | 700 | Hero headlines only |
| `.type-h1` | 1.875rem | 700 | One per page |
| `.type-h2` | 1.5rem | 700 | Section headings |
| `.type-h3` | 1.25rem | 600 | Sub-section headings |
| `.type-h4` | 1.125rem | 600 | Card / widget headings |
| `.type-body` | 1rem | 400 | Default body copy |
| `.type-body-small` | 0.875rem | 500 | UI controls, labels |
| `.type-caption` | 0.875rem | 400 | Metadata, footnotes |
| `.type-mono` | 0.875rem | 400 | Code snippets (monospace) |
| `.type-overline` | 0.75rem | 600 uppercase | Category labels |

### Logos & favicons

- Always use SVG first; provide WebP `<source>` with PNG `<img>` fallback via `<picture>`.
  - Correct `<picture>` source order: **SVG `<source>` first**, then WebP `<source>`, then `<img>` PNG fallback.
  - Wrong order (WebP before SVG) causes browsers to pick WebP over the preferred vector format.
- Variants: **square** (avatars, app icons), **horizontal** (header — `horizontal-full.svg` light, `horizontal-full-dark.svg` dark).
- Minimum clear space: 25% of logo width on all sides. Minimum digital width: 80 px (square), 200 px (horizontal).
- Favicon set lives at `https://logo.palikkaharrastajat.fi/favicon/` — download all sizes to `elm-app/public/`.
- **Never** stretch, recolour, shadow, or outline the logo.
- **Never** display animated logo variants (`*-animated.webp/gif`) when `prefers-reduced-motion: reduce` is active.
- In `HtmlGen.hs` static HTML, always use the self-hosted logo path (`/logos/horizontal-full.png`, etc.) — **never** load assets from `logo.palikkaharrastajat.fi` at runtime.

### WCAG / accessibility rules

- All colour pairings must pass WCAG 2.1 AA (≥ 4.5:1 normal text, ≥ 3:1 large text / UI).
- `bg-brand-yellow` (`#FAC80A`) **fails on white** (1.58:1). Always pair it with `text-brand` (`#05131D`) which passes AAA (10.83:1).
- `text-brand` (`#05131D`) on white passes AAA (18.79:1). `text-white` on `bg-brand` also passes AAA.
- Brand red (`#C91A09`) on white passes AA (5.78:1); do not use on dark backgrounds without re-checking.
- Avoid `text-gray-400` for body or label text — its contrast on white (~2.85:1) fails AA. Use `text-gray-500` (4.6:1) as the minimum for muted text.
- Max content width is **1024 px** (`max-w-5xl` in Tailwind). Do not use `max-w-4xl` (896 px) for full-page containers.

### Rules for AI agents

1. **Never hard-code hex colours** in Elm views or Haskell HTML generators. Use the Tailwind semantic class names (`bg-brand`, `text-brand`, `bg-brand-yellow`, `border-brand`, `border-gray-200`, etc.) or the `@theme` CSS variables.
2. **Use named type classes** (`.type-h1`, `.type-h2`, `.type-h3`, `.type-h4`, `.type-body`, `.type-body-small`, `.type-caption`, `.type-mono`, `.type-overline`) rather than ad-hoc `text-xl font-bold` combinations in Elm views and Haskell-generated HTML.
3. When adding logos to any page (Elm SPA or Haskell static HTML), use the `<picture>` pattern with sources in this exact order: **SVG `<source>` first**, then WebP `<source>`, then `<img>` PNG fallback.
4. When generating or editing `statics/src/HtmlGen.hs`, embed `@font-face` for Outfit pointing to the **self-hosted** TTF (`/fonts/Outfit-VariableFont_wght.ttf`) — do not load it from `logo.palikkaharrastajat.fi`. Use CSS variables (not raw hex) for all colour values.
5. Check contrast before picking any colour pair. Refer to the `wcag` fields in `colors.jsonld` or the table above.
6. The canonical brand yellow is **`#FAC80A`** — do not use `#F2CD37` (legacy incorrect value).

## Security

- PocketBase is at `https://data.palikkaharrastajat.fi`. Ensure collection rules remain properly configured.
- Authentication is handled entirely via PocketBase OAuth2. There is no custom auth server.
- Do not commit credentials or tokens. The `POCKETBASE_URL` override is for local dev only.
