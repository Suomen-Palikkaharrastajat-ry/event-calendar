# AGENTS.md

This file provides instructions for AI coding agents working on this project.

## Project Overview

Event calendar for *Suomen Palikkaharrastajat ry*, built with an **Elm 0.19 SPA** (frontend) and a **Haskell static generator** (feeds, HTML, images), backed by **PocketBase**.

The project was migrated from SvelteKit 5 in early 2026. There is **no TypeScript, no Svelte, no ESLint, no Prettier, and no pnpm** in the current codebase. Ignore any references to those tools in older docs.

## Repository Layout

```
elm-app/          Elm 0.19 SPA (Vite + vite-plugin-elm + Tailwind CSS 4)
  src/            Elm source modules (Main, Types, Route, Api, Auth, Ports, I18n, DateUtils)
  src/Page/       Page-level Elm modules (Calendar, Events, EventDetail, EventEdit)
  src/View/       View helpers (Layout, Calendar, Events, EventForm, EventDetail, EventList)
  tests/          Elm unit tests — elm-explorations/test (81 tests)
  public/         Static assets (Leaflet marker icons, fonts, logo)
  packages/       Symlink to shared Elm packages in vendor/master-builder
statics/          Haskell static generator (Cabal)
  src/            Library modules (PocketBase, DateUtils, ICalGen, FeedGen, GeoJsonGen, HtmlGen)
  app/Main.hs     Executable entry point
  tests/Main.hs   Haskell tests — tasty (72 tests)
review/           elm-review config (shared LlmAgent rules via vendor/master-builder)
assets/           Files copied verbatim into dist/ (e.g. .nojekyll)
pkgs/             Nix-managed npm packages (vite, elm-test, Tailwind, etc.)
  npm-tools.nix   Thin wrapper over vendor/master-builder/pkgs/mk-npm-tools.nix (repo hash kept here)
  package.json    npm manifest for pkgs/npm-tools.nix
  package-lock.json  Lockfile for pkgs/npm-tools.nix
.github/workflows CI/CD: deploy.yml (push to main → GitHub Pages), scheduled.yml (build 4×/day)
```

Shared code is consumed through the pinned `vendor/master-builder` submodule:
Elm plumbing from `packages/app-toolkit` (`Geocoding`, `View.MapWidget`, `View.Icons`)
and Haskell modules from `packages-hs/statics-common` (`DescriptionHtml`, `ImageFetcher`).
Do not re-add local copies of these — edit them in master-builder and bump the pin.

## Development Environment

The project uses **devenv** (Nix). Always run commands inside the devenv shell, either with `make shell` (interactive) or prefixed with `devenv shell --`. Run `make vendor` first so the `vendor/master-builder` submodule (shared packages + npm-tools builder) is present before `devenv shell`.

**Enter the shell interactively:**
```sh
make shell
```

### npm / node_modules

All npm packages (vite, vite-plugin-elm, @tailwindcss/vite, elm-test, leaflet, pocketbase, …) are managed by the Nix derivation in `pkgs/npm-tools.nix`. There is no `package.json` in the project root or in `elm-app/`.

When `devenv shell` starts, `enterShell` creates two symlinks pointing at the Nix store:
```
node_modules      → <nix-store>/event-calendar-npm-tools/lib/node_modules
elm-app/node_modules → same
```

These symlinks let `vite build` and `elm-test` resolve packages when run from either the repo root or `elm-app/`.

Shared package layout:
```
elm-app/packages -> ../vendor/master-builder/packages
```

Import shared UI as `Component.*` and shared tokens as `DesignTokens.*`.

**To update npm dependencies:**
1. Edit `pkgs/package.json`
2. Generate a new lockfile: `npm install --package-lock-only --ignore-scripts` (needs `nodejs_22` available)
3. Set `hash = pkgs.lib.fakeHash;` in `pkgs/npm-tools.nix`
4. Run `devenv shell` — it fails with `got: sha256-…` in the error
5. Paste that sha256 into `pkgs/npm-tools.nix`

## Build and Test Commands

All commands are defined in the `Makefile`. Run them from the repo root:

| Command | Description |
|---------|-------------|
| `make elm-dev` | Start Elm + Vite dev server (hot reload) at http://localhost:5173 |
| `make elm-build` | Production build of Elm SPA → `dist/` |
| `make elm-test` | Run Elm unit tests |
| `make elm-check` | Validate Elm formatting (elm-format --validate) + elm-review |
| `make elm-review` | Run elm-review with the shared LlmAgent rules from `vendor/master-builder` |
| `make elm-format` | Auto-format Elm source files |
| `make statics-build` | Build Haskell static generator |
| `make statics` | Run generator (fetches live events, writes static files to `dist/`) |
| `make statics-test` | Run Haskell unit tests |
| `make statics-check` | Lint Haskell source (hlint) |
| `make statics-format` | Auto-format Haskell source (fourmolu) |
| `make test` | Run all tests (Elm + Haskell) |
| `make dist` | Full production build: Elm SPA + static files |
| `make format` | Auto-format all source files |
| `make check` | Validate all formatting without changes |
| `make clean` | Remove `dist/` |

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
- PocketBase URL is compiled in via `elm-app/src/Api.elm`. For local dev, set `VITE_POCKETBASE_URL`.
- `RemoteData` (krisajenkins/remotedata) is used for async API state.
- Pagination uses a custom `PbList a` wrapper (not plain `List a`).

### Haskell Static Generator
- Fetches live events from PocketBase REST API (`statics/src/PocketBase.hs`).
- Generates: iCal (ICalGen), RSS/Atom/JSON Feed (FeedGen), GeoJSON (GeoJsonGen), printable HTML + per-event pages (HtmlGen), event images (ImageFetcher).
- ICS files embedded in feeds as `text/calendar` enclosures (base64-encoded).
- `statics/app/Main.hs` calls `setLocaleEncoding utf8` — required because the devcontainer locale ≠ UTF-8.
- `iCalendar` Haskell library is unmaintained; ICalGen.hs uses manual RFC 5545 text generation instead.

## Known Gotchas

- **Haskell build scope**: this repo's `cabal.project` manages `statics/` plus the shared `vendor/master-builder/packages-hs/statics-common/` package.
- **GHC version**: 9.6.7 (via devenv/Nix). CI uses `haskell-actions/setup` with `ghc-version: '9.6'`.
- **JSON decoders in Elm tests**: `Json.Decode.decodeString` returns `Result Json.Error a`, not `Result String a`.
- **node_modules are symlinks**: `elm-app/node_modules` points into the Nix store (read-only). Do not run `npm install` or `pnpm install` inside `elm-app/` — it will break the symlink. Add deps via `pkgs/package.json` instead.

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
- [ ] `dist/kalenteri.ics` opens in a calendar app and shows all published events
- [ ] `dist/kalenteri.rss` validates at https://validator.w3.org/feed/
- [ ] `dist/kalenteri.atom` validates at https://validator.w3.org/feed/
- [ ] `dist/kalenteri.html` renders correctly in a browser

## Style Guide

The association's official design guide lives at **<https://logo.palikkaharrastajat.fi/>**. Machine-readable JSON-LD: <https://logo.palikkaharrastajat.fi/design-guide/index.jsonld>.

**Agent CSS reference:** Fetch `https://logo.palikkaharrastajat.fi/brand.css` for the latest canonical `@theme`, `@utility type-*`, `@font-face`, reduced-motion rule, and shared component classes. Tailwind v4 requires `@theme` in the locally-processed file — copy the content into `elm-app/main.css`.

### Design tokens, typography, logos, WCAG

**Single source of truth:** the design-system reference lives in
[`vendor/master-builder/AGENTS.md`](vendor/master-builder/AGENTS.md) (section
"Design system": color tokens, typography type scale, layout, focus rings,
logos, WCAG rules). The machine-readable token definitions live in the
`design-guide` repo's `content/*.toml`. Do not duplicate the token tables here —
read them from master-builder so this app cannot drift from the others.

Quick rules that always apply in this repo:

- Use semantic token classes from `elm-app/main.css` (`bg-brand`, `text-brand`,
  `bg-brand-yellow`, …) — never hard-code hex values.
- Canonical brand yellow is **`#FAC80A`**. Do not use `#F2CD37` (legacy incorrect value).
- Use named type classes (`.type-h1`, `.type-body`, …), never ad-hoc `text-xl font-bold`.
- Logos: `<picture>` with **SVG `<source>` first**, then WebP, then `<img>` PNG fallback.
- In `HtmlGen.hs` static HTML, always use the self-hosted logo path
  (`/logo/horizontal-full.png`, etc.) and self-hosted `@font-face` for Outfit
  (`/fonts/Outfit-VariableFont_wght.ttf`) — **never** load assets from
  `logo.palikkaharrastajat.fi` at runtime.

### Shared Component Library

The association maintains shared Elm design tokens and UI components through the vendored package workspace in [`vendor/master-builder/packages`](vendor/master-builder/packages). The frontend consumes them through the symlink at [`elm-app/packages`](elm-app/packages).

Import components directly:

```elm
import Component.Button as Button
import Component.Card as Card
import Component.Alert as Alert
```

The package workspace is supplied by the pinned `vendor/master-builder` submodule:

```bash
# After cloning event-calendar:
git submodule update --init

# To refresh the shared package workspace:
git submodule update --remote vendor/master-builder
```

Note: `Component.Alert`, `Component.Dialog`, and `Component.Toast` each depend on `Component.CloseButton`.

**Focus ring convention:** Use `focus-visible:ring-2 focus-visible:ring-brand` (keyboard-only — no ring on mouse click). Do NOT use `focus:ring-*`.

**Available components:** Alert, Accordion, Badge, Breadcrumb, Button (with `ariaPressedState` for toggles), ButtonGroup, Card, CloseButton, Collapse, Dialog, DownloadButton, Dropdown, FeatureGrid, Footer, Hero, ListGroup, Navbar, Pagination, Placeholder, Pricing, Progress, SectionHeader, Spinner, Stats, Tabs, Tag, Timeline, Toast, Toggle, Tooltip — plus ColorSwatch and LogoCard.

### Rules for AI agents

1. **Never hard-code hex colours** in Elm views or Haskell HTML generators. Use the Tailwind semantic class names (`bg-brand`, `text-brand`, `bg-brand-yellow`, `border-brand`, `border-gray-200`, etc.) or the `@theme` CSS variables.
2. **Use named type classes** (`.type-h1`, `.type-h2`, `.type-h3`, `.type-h4`, `.type-body`, `.type-body-small`, `.type-caption`, `.type-mono`, `.type-overline`) rather than ad-hoc `text-xl font-bold` combinations in Elm views and Haskell-generated HTML.
3. When adding logos to any page (Elm SPA or Haskell static HTML), use the `<picture>` pattern with sources in this exact order: **SVG `<source>` first**, then WebP `<source>`, then `<img>` PNG fallback.
4. When generating or editing `statics/src/HtmlGen.hs`, embed `@font-face` for Outfit pointing to the **self-hosted** TTF (`/fonts/Outfit-VariableFont_wght.ttf`) — do not load it from `logo.palikkaharrastajat.fi`. Use CSS variables (not raw hex) for all colour values.
5. Check contrast before picking any colour pair against the WCAG rules in [`vendor/master-builder/AGENTS.md`](vendor/master-builder/AGENTS.md).
6. The canonical brand yellow is **`#FAC80A`** — do not use `#F2CD37` (legacy incorrect value).

## Security Considerations

- The backend is PocketBase at `https://data.palikkaharrastajat.fi`. Ensure PocketBase collection rules are correctly configured to prevent unauthorized reads/writes.
- Authentication is OAuth2/OIDC via PocketBase. Auth logic lives in `elm-app/src/Auth.elm`.
- When modifying auth or data-access logic, run `make test` and manually verify the E2E checklist above.
