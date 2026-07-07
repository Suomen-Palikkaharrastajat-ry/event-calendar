# Static Generators

While the Elm SPA provides an interactive frontend, a dedicated Haskell build system fetches the latest event data and generates static, universally accessible files. This dual architecture ensures broad compatibility and SEO friendliness.

## Features
- **Calendar Feeds**: Generates `kalenteri.ics` for importing into external calendar apps (Google Calendar, Apple Calendar), embedding base64 event images.
- **Syndication Feeds**: Creates `kalenteri.rss`, `kalenteri.atom`, and JSON feeds for content aggregators.
- **Geospatial Data**: Generates `kalenteri.geojson` for external mapping applications.
- **Static HTML Output**: Produces a static, printable `kalenteri.html` view and individual event pages.
- **Image Caching**: A dedicated worker fetches and optimizes event images locally.

## Related Code Locations
- **`statics/app/Main.hs`**: The main executable entry point for the static generation pipeline.
- **`statics/src/PocketBase.hs`**: Fetches the authoritative event list from the PocketBase REST API.
- **`statics/src/ICalGen.hs`**: Manual RFC 5545 text generator for the `.ics` calendar feed.
- **`statics/src/FeedGen.hs`**: Generates RSS, Atom, and JSON formats.
- **`statics/src/GeoJsonGen.hs`**: Generates the GeoJSON coordinate dump.
- **`statics/src/HtmlGen.hs`**: Produces the static HTML pages using self-hosted fonts and assets.
- **`statics/src/ImageFetcher.hs`**: Handles downloading and caching of remote event images.
