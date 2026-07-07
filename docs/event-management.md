# Event Management (CRUD)

The application provides a comprehensive suite of tools for event administrators to create, read, update, and delete (CRUD) events. The event data is securely stored and managed using PocketBase as the backend REST API.

## Features
- **Event Creation**: A detailed form for entering event metadata (title, description, dates, location, coordinates).
- **Event Updates**: Modifying existing event details, including support for multipart form submissions when uploading new event images. 
- **Event Deletion**: Removing events from the system with confirmation dialogues.
- **Data Synchronization**: Asynchronous API communication handling loading states via the `RemoteData` pattern.

## Related Code Locations
- **`elm-app/src/Api.elm`**: Handles all HTTP requests to the PocketBase backend, including fetching event lists, single events, and submitting mutations.
- **`elm-app/src/Page/EventEdit.elm`**: The primary Elm module handling the logic for both creating new events and editing existing ones.
- **`elm-app/src/Page/EventDetail.elm`**: The view for reading the details of an individual event.
- **`elm-app/src/View/EventForm.elm`**: The shared form view component used for data entry.
- **`statics/src/PocketBase.hs`**: The backend Haskell equivalent for fetching live event records to be used in static generation.
