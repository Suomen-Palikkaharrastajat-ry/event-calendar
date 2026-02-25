# Event Calendar — Feature Report

**Stack:** SvelteKit 5 (Runes) + PocketBase + Tailwind CSS + Leaflet

**Purpose:** Event management system for *Suomen Palikkayhteisö ry* (Finnish Parkour community), Finnish-language UI.

---

## Features & User Stories

### 1. Calendar View (Home Page `/`)

**Features:** Month grid + list view toggle, date picker, "published" events only, click-to-detail, query param `?date=` support.

| # | User Story |
|---|------------|
| 1.1 | As a visitor, I can view a monthly calendar grid of published events so I can see what's happening. |
| 1.2 | As a visitor, I can switch between month grid and list view to browse events in the format I prefer. |
| 1.3 | As a visitor, I can click a specific date to jump to it, and share that view via URL (`?date=YYYY-MM-DD`). |
| 1.4 | As a visitor, I can click an event on the calendar to view its details. |
| 1.5 | As a visitor, I can navigate to previous/next months or jump to today. |

---

### 2. Authentication

**Features:** OAuth2/OIDC login, PocketBase auth, user display in header, logout.

| # | User Story |
|---|------------|
| 2.1 | As a community member, I can log in via OAuth so I can manage events. |
| 2.2 | As an authenticated user, I can see my name in the header and log out at any time. |
| 2.3 | As an unauthenticated visitor, I see a login button and a contact email link to submit events externally. |

---

### 3. Event Creation (`/events`)

**Features:** Full form with title, location + geocoding, description, URL, image upload, date/time pickers, all-day toggle, draft/published status.

| # | User Story |
|---|------------|
| 3.1 | As an authenticated user, I can create a new event with a title, description, date/time, and location. |
| 3.2 | As an authenticated user, I can mark an event as all-day or specify start/end times. |
| 3.3 | As an authenticated user, I can attach a URL and an image (with alt text) to an event. |
| 3.4 | As an authenticated user, I can save an event as **draft** or publish it immediately. |
| 3.5 | As an authenticated user, I can type a location name and have it automatically geocoded to coordinates (via Nominatim/OSM). |
| 3.6 | As an authenticated user, I can toggle geocoding on/off and manually enter lat/lon coordinates. |
| 3.7 | As an authenticated user, I can place or drag a marker on an interactive map to set the event's location. |

---

### 4. Event Management Table (`/events`)

**Features:** Paginated table of own events, inline status change, edit/delete actions.

| # | User Story |
|---|------------|
| 4.1 | As an authenticated user, I can view a paginated list (100/page) of all draft and published events. |
| 4.2 | As an authenticated user, I can change an event's status (draft → pending → published → deleted) directly from the list. |
| 4.3 | As an authenticated user, I can navigate to an event's edit form from the list. |

---

### 5. Event Detail View (`/events/[id]`)

**Features:** Full event info, OSM location link, image, edit/delete for authenticated users, keyboard shortcuts.

| # | User Story |
|---|------------|
| 5.1 | As a visitor, I can view all event details: title, description, dates (Helsinki timezone), location, URL, and image. |
| 5.2 | As a visitor, I can click the location to open it in OpenStreetMap. |
| 5.3 | As an authenticated user, I can edit or delete an event from its detail view. |
| 5.4 | As a keyboard user, I can press `E` to edit, `Esc` to go back, without using a mouse. |

---

### 6. Event Editing (`/events/[id]/edit`)

**Features:** Pre-populated edit form, same fields as creation, image replacement, coordinate editing with map.

| # | User Story |
|---|------------|
| 6.1 | As an authenticated user, I can edit any field of an existing event, including replacing the image. |
| 6.2 | As an authenticated user, I can update the event location by dragging the map marker or re-geocoding. |
| 6.3 | As an authenticated user, I can cancel editing and return to the detail view without saving. |

---

### 7. KML Import (`/events`)

**Features:** Upload KML file, parse placemarks, extract coordinates and dates, bulk-create draft events.

| # | User Story |
|---|------------|
| 7.1 | As an authenticated user, I can import a KML file to bulk-create events from geographic placemarks. |
| 7.2 | As an authenticated user, imported events are created in **draft** state so I can review before publishing. |

---

### 8. Feed Exports (Footer)

**Features:** iCal, HTML/PDF, RSS, ATOM, JSON feed, GeoJSON.

| # | User Story |
|---|------------|
| 8.1 | As a visitor, I can subscribe to an iCalendar (ICS) feed to get events in my calendar app. |
| 8.2 | As a visitor, I can access an RSS, ATOM, or JSON feed to integrate events into other tools. |
| 8.3 | As a developer, I can use the GeoJSON feed to consume event locations in mapping applications. |
| 8.4 | As a visitor, I can view a formatted HTML/PDF event listing for printing or sharing. |

---

### 9. Timezone & Date Handling

**Features:** All dates stored in UTC, displayed in Europe/Helsinki (DST-aware), European date format.

| # | User Story |
|---|------------|
| 9.1 | As a Finnish user, I see all dates and times displayed in Helsinki time (EET/EEST), correctly handling daylight saving time. |
| 9.2 | As a user creating events, my local date/time inputs are transparently converted to UTC for storage. |

---

### 10. Accessibility & UX

| # | User Story |
|---|------------|
| 10.1 | As a keyboard-only user, I can navigate the calendar, event list, and forms using Tab, Enter, Space, and Esc. |
| 10.2 | As a user, I receive toast notifications for success and error states (e.g., save succeeded, geocoding failed). |
| 10.3 | As a Finnish speaker, the entire interface is in Finnish with complete i18n coverage. |

---

## Event State Workflow

```
draft → pending → published → deleted
```

Events are only visible on the public calendar when `state = "published"`.

---

## Data Model

```typescript
interface Event {
  id: string;
  title: string;
  description?: string;
  start_date: string;           // UTC ISO string
  end_date?: string;            // UTC ISO string
  all_day: boolean;
  url?: string;
  location?: string;
  state: 'draft' | 'pending' | 'published' | 'deleted';
  image?: string;               // PocketBase file field
  image_description?: string;
  point?: { lat: number; lon: number } | null;
  created: string;
  updated: string;
}
```

---

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `pocketbase` | Backend client (auth, CRUD, file storage) |
| `svelte` / `@sveltejs/kit` | UI framework and routing |
| `@event-calendar/core` | Calendar grid and list view |
| `leaflet` | Interactive maps with draggable markers |
| `flowbite-svelte` | Date and time picker components |
| `svelte-i18n` | Finnish translations |
| `@zerodevx/svelte-toast` | Toast notifications |
| `tailwindcss` | Styling framework |
