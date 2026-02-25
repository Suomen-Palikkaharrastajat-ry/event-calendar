# Event Calendar — Static Generation Report

Scripts: [scripts/generate-utils.js](scripts/generate-utils.js) · [scripts/generate-statics.js](scripts/generate-statics.js)

Invoked via `make statics` → `pnpm run generate-statics` → `node scripts/generate-statics.js`

---

## Overview

The static generation pipeline fetches all published events from PocketBase and produces a set of static files written to both `static/` (for dev) and `build/` (for production, if it exists). No CLI arguments or environment variables are required — all URLs are hardcoded.

**Base URL:** `https://kalenteri.suomenpalikkayhteiso.fi`
**Data source:** PocketBase at `https://data.suomenpalikkayhteiso.fi`, collection `events`
**Event filter:** `state = "published"` AND `(end_date > yesterday OR start_date > yesterday)`
**Sort order:** `start_date` ascending

---

## Data Flow

```
PocketBase (events collection)
        │
        ▼
fetchPublishedEvents()          ← published, from yesterday onwards
        │
        ├──▶ generateEmbed()   ──▶  static/kalenteri.html
        │
        └──▶ generateFeeds()
                │
                ├──▶ downloadEventImages()  ──▶  static/images/{id}_{filename}
                │
                ├──▶ per-event loop
                │       ├──▶  static/events/{id}.ics
                │       └──▶  static/events/{id}.html
                │
                ├──▶  static/kalenteri.rss
                ├──▶  static/kalenteri.atom
                ├──▶  static/kalenteri.json
                ├──▶  static/kalenteri.geo.json
                └──▶  static/kalenteri.ics
```

---

## Output Files

### `static/kalenteri.html` — Printable / Embeddable Calendar

A self-contained HTML page grouping events by month.

**Contents per event:**
- Finnish-formatted date string (e.g. `ma 5.5. klo 14.00–16.00`)
- Title (linked to `event.url` if present)
- Location inline with title
- Description paragraph
- QR code (data URI) linking to `events/{id}.html` — visible only when printing (`@media print`)
- "Add to calendar" link using a base64-encoded ICS data URI — hidden when printing
- "Read more" link to `event.url` — hidden when printing

**Month headers:** Finnish month names (Tammikuu … Joulukuu) with year

**Design:** Black-and-white brand colors (print-safe), `page-break-inside: avoid` on each event and month block.

---

### `static/kalenteri.ics` — Master iCalendar Feed

A single `.ics` file containing all published events, suitable for calendar subscription.

**Per-event fields:**
- `SUMMARY` — title (all-day events append `| City` from the first part of the location string)
- `DESCRIPTION` — description or title fallback
- `DTSTART` / `DTEND` — Helsinki timezone; all-day events get an extra `+24h` on `DTEND`
- `URL` — `event.url` if present
- `LOCATION` — location name + `GEO` lat/lon if coordinates exist
- `UID` — `{baseUrl}/#/events/{id}`
- `TZID` — `Europe/Helsinki`

---

### `static/events/{id}.ics` — Per-event iCalendar Files

Identical structure to the master ICS, but one file per event.
Used as enclosures in RSS/Atom feeds and as download targets from the per-event HTML pages.

---

### `static/events/{id}.html` — Per-event Landing Pages

Minimal HTML pages, one per event. Primary purpose: QR code scan target for print media.

**Contents:**
- Title as `<h1>`
- Location and formatted date string
- Description
- "Add to calendar" button linking to `{id}.ics`

---

### `static/kalenteri.rss` — RSS 2.0 Feed

Standard RSS feed, one item per event.

**Per-item fields:**
- `title` — `{date} {title} | {location}`
- `description` — description + formatted date
- `link` — `event.url` (omitted if not set)
- `pubDate` — `event.updated`
- `published` — `event.created`
- `enclosure` — `events/{id}.ics` (type: `text/calendar`, with byte length)
- `image` — hosted image URL if the event has an image

---

### `static/kalenteri.atom` — Atom 1.0 Feed

Same content as RSS, in Atom format.
Post-processed to fix a library bug: replaces incorrect `type="image/ics"` → `type="text/calendar"` on enclosure links.

---

### `static/kalenteri.json` — JSON Feed (JSON Feed 1.1)

Same content as RSS/Atom, in JSON Feed format. Suitable for modern feed readers and API consumers.

---

### `static/kalenteri.geo.json` — GeoJSON FeatureCollection

Only events with valid, non-zero coordinates (`point.lat`, `point.lon`) are included.

**Per-feature:**
- `geometry.type` — `Point`
- `geometry.coordinates` — `[lon, lat]` (GeoJSON order)
- `properties.title`, `description`, `start`, `end`, `all_day`, `location`, `url`
- `properties.ics` — full ICS file content embedded as a string
- `properties.id` — event ID

---

### `static/images/{id}_{filename}` — Downloaded Event Images

Event images are downloaded from PocketBase file storage and saved locally.
Used to provide absolute image URLs in feed items. Failed downloads are logged as warnings and skipped.

---

## Date & Timezone Formatting

All date conversion uses `Europe/Helsinki` (EET/EEST, DST-aware via `toLocaleString`).

**Finnish display format examples:**

| Event type | Example output |
|------------|---------------|
| Single timed event | `ma 5.5. klo 14.00` |
| Timed event with end time same day | `ma 5.5. klo 14.00–16.00` |
| Timed event spanning days | `5.5. 14.00–6.5. 12.00` |
| All-day, single day | `ma 5.5.` |
| All-day, same month range | `ma–ke 5.–7.5.` |
| All-day, cross-month range | `30.4.–2.5.` |

Day abbreviations (Finnish): `su ma ti ke to pe la`

---

## Dependencies

| Package | Purpose |
|---------|---------|
| `pocketbase` | Fetch events from backend |
| `ical-generator` | Build `.ics` iCalendar files |
| `feed` | Build RSS 2.0, Atom 1.0, JSON Feed |
| `qrcode` | Generate QR code data URIs for print HTML |
| `fs` / `path` | Write output files (Node.js built-ins) |

---

## Error Handling

- Image download failures are logged as warnings and do not abort the run.
- Any uncaught error in `generateStatics()` is logged and exits the process with code `1`.
- Files are written with `mkdirSync({ recursive: true })`, so output directories are created automatically.
