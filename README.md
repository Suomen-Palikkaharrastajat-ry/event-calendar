# Event Calendar

Event calendar for Suomen Palikkaharrastajat ry, built with Elm 0.19, Haskell, and PocketBase.


## Overview

The project combines:

- an Elm frontend in [`elm-app/`](/workspaces/web/event-calendar/elm-app) for the public calendar, event views, and authenticated editing
- a Haskell static generator in [`statics/`](/workspaces/web/event-calendar/statics) for feeds, printable pages, and exported assets

Features include calendar and list views, event detail pages, authenticated CRUD, KML import, Leaflet maps, and static exports such as iCal, RSS, Atom, JSON Feed, and GeoJSON.

## Development Environment

This project uses `devenv` for local development and CI.

```sh
make develop
make shell
```

On a fresh environment, run `cabal update` before the first `cabal build statics`.

The default PocketBase URL is `https://data.palikkaharrastajat.fi`. For local development, set `VITE_POCKETBASE_URL` and `POCKETBASE_URL` via `.env` or use the `*-local` Makefile targets. Local PocketBase and Keycloak services are available through `devenv up`.

## Common Commands

| Command | What it does |
|---|---|
| `make shell` | Open the development shell |
| `make elm-dev` | Start the Elm + Vite dev server |
| `make elm-build` | Build the Elm frontend into `dist/` |
| `make statics-build` | Build the Haskell static generator |
| `make statics` | Generate static files from live events |
| `make dist` | Build the statics and Elm app together |
| `make test` | Run Elm and Haskell tests |
| `make check` | Run formatting and lint checks |
| `make site-config` | Regenerate the files derived from `config.toml` |
| `make format` | Auto-format Elm and Haskell code |
| `make clean` | Remove build output |

## Project Structure

```text
elm-app/          Elm 0.19 SPA frontend
  src/            Elm source modules
  tests/          Elm unit tests
  public/         Static frontend assets
  packages/       Symlink to shared Elm packages in vendor/master-builder
statics/          Haskell static generator
  src/            Haskell library modules
  app/            Haskell executable entry point
assets/           Files copied verbatim into dist/
pkgs/             Nix-managed Node/Vite/Elm tooling manifest + lockfile
vendor/master-builder  Shared Elm design tokens and UI components
.github/workflows CI/CD workflows
```

## Configuration and Translations

The site describes itself in [`config.toml`](config.toml): URL, title,
description, languages, and the app's own settings under `[app]`. It is layered
on the family defaults of the hub; the format is documented in
[`vendor/master-builder/docs/site-config.md`](vendor/master-builder/docs/site-config.md).

- Text in the default language (Finnish) sits directly in a section; English
  goes in a sub-table such as `[site.en]`; the app's own text sits in
  `[app.strings]` and `[app.en.strings]`.
- Vite generates the document head and `site.webmanifest` from it, so
  `elm-app/index.html` carries no title, description or icon tags.
- Two committed files are derived from it: `elm-app/tests/SiteFixture.elm`
  and `statics/src/SiteConfig.hs` (used by the feeds, iCalendar file and HTML export). After editing
  `config.toml`, run `make site-config`; `make site-config-check` (part of
  `make elm-check` and of CI) fails when they are stale.
- Interface text lives in `elm-app/src/I18n.elm`, per language. Views take a
  `Lang` and contain no text of their own; the same check fails on Finnish
  text outside translations. To add a string, add a key (or a function, when
  the wording depends on a number) with its Finnish and English text.
- A visitor switches language with the footer link or `?lang=en`.

## Shared Frontend Conventions

The frontend follows the Suomen Palikkaharrastajat design guide:

- https://logo.palikkaharrastajat.fi/
- https://logo.palikkaharrastajat.fi/brand.css

Shared Elm design tokens and UI components are exposed through [`elm-app/packages`](/workspaces/web/event-calendar/elm-app/packages), which points to [`vendor/master-builder/packages`](/workspaces/web/event-calendar/vendor/master-builder/packages).

Frontend tooling is managed through Nix, not `pnpm`:

- [`pkgs/package.json`](/workspaces/web/event-calendar/pkgs/package.json)
- [`pkgs/package-lock.json`](/workspaces/web/event-calendar/pkgs/package-lock.json)
- [`pkgs/npm-tools.nix`](/workspaces/web/event-calendar/pkgs/npm-tools.nix)

## CI and Deployment

GitHub Actions builds and deploys the site to GitHub Pages.

- [`deploy.yml`](/workspaces/web/event-calendar/.github/workflows/deploy.yml)
- [`scheduled.yml`](/workspaces/web/event-calendar/.github/workflows/scheduled.yml)

Human-facing usage lives here in `README.md`. Agent-specific development instructions live in [`AGENTS.md`](/workspaces/web/event-calendar/AGENTS.md).
