# Authentication

Authentication in the Event Calendar is handled via OAuth2/OIDC, delegating identity management to PocketBase. This ensures that only authorized administrators can access the event management features.

## Features
- **OAuth2 Login Flow**: Users authenticate through PocketBase's OAuth2 popup flow (`authWithOAuth2`): the popup returns to PocketBase's `/api/oauth2-redirect` and the token reaches the app over PocketBase's realtime connection. The hub script opens the popup synchronously inside the click, as Safari requires. The app's `#/callback` route and the `getCallbackParams`/`callbackParams` ports are legacy and unused.
- **Protected Routes**: Certain Elm SPA routes (like `/#/events/new` or `/#/events/:id/edit`) require a valid authentication token. If unauthenticated, the user is redirected to the calendar view with an info toast.
- **Session Persistence**: Authentication state is stored and restored upon app initialization.

## Related Code Locations
- **`vendor/master-builder/packages/app-toolkit/src/PocketBaseAuth.elm`**: The hub's shared module: auth state and user types, restore from flags, OAuth code exchange, popup result and legacy `#/callback` helpers.
- **`vendor/master-builder/packages/app-toolkit/js/pocketbase-auth.js`**: The hub's shared script: token refresh at start-up, OAuth popup, token storage in `localStorage`. `elm-app/main.js` wires it.
- **`elm-app/src/Main.elm`**: Initializes authentication from flags and manages top-level auth state transitions.
- **`elm-app/src/Route.elm`**: Identifies which routes require authentication.
- **`elm-app/src/Ports.elm`**: Used to potentially interact with browser APIs for OAuth popup management or localStorage session persistence.
