# Event Calendar

Event calendar for Suomen Palikkaharrastajat ry — built with Elm 0.19, Haskell, and PocketBase.

## Features

- Monthly calendar grid and list view of published events
- Event detail pages with OSM location links and image display
- Authenticated users can create, edit, and delete events
- KML file import to bulk-create draft events
- Interactive Leaflet maps with geocoding (Nominatim)
- Finnish UI with Helsinki timezone support (DST-aware)
- Static feed exports: iCal, RSS, Atom, JSON Feed, GeoJSON
- Printable HTML calendar and per-event landing pages

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Elm 0.19 SPA (via Vite + vite-plugin-elm) |
| CSS | Tailwind CSS 4 |
| Maps | Leaflet (via Elm ports) |
| Static generator | Haskell (Cabal) |
| Backend | PocketBase |
| Auth | OAuth2/OIDC via PocketBase |
| Deployment | GitHub Pages (GitHub Actions) |

## Development

### Prerequisites

Install [devenv](https://devenv.sh/) then run:

```sh
make develop
```

This bootstraps a Nix-based shell with GHC 9.6, Cabal, Elm 0.19.1, Vite, and all other tools.

### Getting Started

```sh
# Enter the dev shell
make shell

# Update Cabal package index (first time only)
cabal update

# Start Elm + Vite dev server
make elm-dev
```

The app will be available at `http://localhost:5173`.

### Configuration

The PocketBase URL defaults to the live instance at `https://data.palikkaharrastajat.fi`.
For local development, set `VITE_POCKETBASE_URL` (Elm SPA) and `POCKETBASE_URL` (static generator)
via `.env` or the `*-local` Makefile targets.

A local PocketBase instance and Keycloak OIDC provider are available via `devenv up`.

### Useful Commands

```sh
make test         # Run all tests (Elm + Haskell)
make elm-test     # Run Elm tests only
make statics-test # Run Haskell tests only
make dist         # Full production build (Elm SPA + static files)
make elm-build    # Build Elm SPA to build/
make statics      # Generate static files (fetches live events)
make format       # Auto-format all source files
make check        # Validate formatting without changes
make clean        # Remove build/
```

## Project Structure

```
elm-app/          Elm 0.19 SPA (frontend)
  src/            Elm source modules
  tests/          Elm tests (elm-test)
  public/         Static assets (marker icons, fonts, logo)
statics/          Haskell static generator
  src/            Haskell library modules
  app/            Haskell executable entry point
  tests/          Haskell tests (cabal test)
static/           Files copied verbatim into build/
.github/workflows CI/CD (GitHub Actions → GitHub Pages)
```

## Building for Production

```sh
make dist
```

Produces a `build/` directory with the Elm SPA and all generated static files, ready for deployment to any static host.
