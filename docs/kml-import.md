# KML Import

To facilitate bulk event creation, administrators can upload Keyhole Markup Language (KML) files containing multiple placemarks. The application parses this geographic data and translates it into discrete event records.

## Features
- **File Upload**: A drag-and-drop or file selection interface for importing `.kml` files.
- **XML Parsing**: Extracts title, description, and coordinate data from KML placemarks.
- **Batch Processing**: Iterates through the parsed data and automatically provisions new events in the backend.

## Related Code Locations
- **`elm-app/src/Page/Events.elm`**: Handles the primary interface and logic for triggering KML file uploads from the event management list.
- **`elm-app/src/Ports.elm`**: Manages the JavaScript interop required to read the uploaded file contents and parse the XML structure before passing it back to Elm.
