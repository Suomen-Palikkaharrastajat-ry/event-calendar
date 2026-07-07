# Frontend SPA

The Event Calendar frontend is built as a Single Page Application (SPA) using Elm 0.19. It provides an interactive interface for viewing, managing, and browsing events. 

## Features
- **Routing**: Utilizes hash-based routing to navigate between views such as the main calendar view, the events list view, and individual event detail/edit views.
- **Styling**: Styled using Tailwind CSS 4, integrated via Vite and a custom Elm Vite plugin. 
- **Shared Components**: Leverages a vendored component library for consistent UI elements (buttons, modals, forms).

## Related Code Locations
- **`elm-app/src/Main.elm`**: The main entry point of the Elm application, initializing state and handling top-level routing/messages.
- **`elm-app/src/Route.elm`**: Defines the hash-based routes (`/#/calendar`, `/#/events`, `/#/events/:id`, etc.) and the URL parsing logic.
- **`elm-app/src/Types.elm`**: Core Elm types and application state models.
- **`elm-app/src/Page/`**: Contains page-level modules (`Calendar`, `Events`, `EventDetail`, `EventEdit`).
- **`elm-app/src/View/`**: Reusable view functions and layout wrappers.
- **`elm-app/packages/`**: Symlink to the shared component library containing `Component.*` and `DesignTokens.*`.
