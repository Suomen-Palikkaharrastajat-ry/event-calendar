port module Ports exposing
    ( callbackParams
    , clearAuthToken
    , destroyMap
      -- Map (inbound)
    , getCallbackParams
      -- Auth (inbound)
    , initMap
    , -- Auth (outbound)
      initiateOAuth
    , kmlParsed
    , mapMarkerMoved
      -- KML (outbound)
    , oauthPopupResult
      -- Map (outbound)
    , parseKml
      -- KML (inbound)
    , saveAuthToken
    , setMapMarker
    )

import Json.Decode as Json



-- ── Auth ports ────────────────────────────────────────────────────────────────


{-| Trigger OAuth2 login flow. Sends PocketBase base URL to JS.
-}
port initiateOAuth : String -> Cmd msg


{-| Persist auth token + user model JSON to localStorage.
-}
port saveAuthToken : { token : String, model : String } -> Cmd msg


{-| Clear auth token + user model from localStorage.
-}
port clearAuthToken : () -> Cmd msg


{-| Request stored OAuth callback params (codeVerifier, state) from sessionStorage.
-}
port getCallbackParams : () -> Cmd msg


{-| Receive stored callback params from sessionStorage.
-}
port callbackParams : ({ codeVerifier : String, state : String } -> msg) -> Sub msg


{-| Receive OAuth2 popup result from PocketBase SDK (token + user model JSON).
-}
port oauthPopupResult : ({ token : String, model : String } -> msg) -> Sub msg



-- ── Map ports ─────────────────────────────────────────────────────────────────


{-| Initialize a Leaflet map in the given DOM container.
-}
port initMap :
    { containerId : String
    , lat : Float
    , lon : Float
    , zoom : Int
    , markerLat : Maybe Float
    , markerLon : Maybe Float
    , draggable : Bool
    }
    -> Cmd msg


{-| Move the map marker programmatically.
-}
port setMapMarker : { lat : Float, lon : Float } -> Cmd msg


{-| Destroy a Leaflet map and clean up its resources.
-}
port destroyMap : String -> Cmd msg


{-| Fired when the user drags the map marker to a new position.
-}
port mapMarkerMoved : ({ lat : Float, lon : Float } -> msg) -> Sub msg



-- ── KML ports ─────────────────────────────────────────────────────────────────


{-| Send KML file content to JS for parsing.
-}
port parseKml : String -> Cmd msg


{-| Receive parsed KML placemarks from JS as a JSON value.
-}
port kmlParsed : (Json.Value -> msg) -> Sub msg
