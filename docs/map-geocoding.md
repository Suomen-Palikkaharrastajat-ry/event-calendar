# Map & Geocoding

Events frequently require precise location data. The application integrates mapping and geocoding services to allow administrators to visualize and accurately set event coordinates.

## Features
- **Map Visualization**: Renders interactive maps using Leaflet.js to display event locations.
- **Geocoding**: Converts human-readable addresses into geographic coordinates (latitude and longitude) using the Nominatim API.
- **Elm-JS Interop**: Since Leaflet is a JavaScript library, the Elm application communicates with it securely via ports.

## Related Code Locations
- **`elm-app/src/Geocoding.elm`**: Handles HTTP requests to the Nominatim geocoding service and parses the resulting coordinate data.
- **`elm-app/src/Ports.elm`**: Defines the Elm ports used to send commands to Leaflet (e.g., initializing a map, adding markers, or listening for map clicks).
- **`elm-app/src/View/MapWidget.elm`**: The Elm view module that renders the container for the Leaflet map and manages its local state.
- **`elm-app/public/`**: Stores the static Leaflet marker icons needed for rendering.
