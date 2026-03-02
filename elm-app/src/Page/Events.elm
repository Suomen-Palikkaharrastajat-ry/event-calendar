{- Events management page — owns the EventsPage state type and init.

   Page/View split: this module handles state and init; all rendering lives in
   View.Events.  The update logic for EventsPage messages is in Main.elm
   (search for `PageEvents`).
-}


module Page.Events exposing (init, view)

import Api
import Html exposing (Html)
import RemoteData
import Types exposing (AuthState, EventsPage, FormStatus(..), KmlImportStatus(..), Msg, emptyEventFormData)
import View.Events


init : String -> Maybe String -> ( EventsPage, Cmd Msg )
init pbBaseUrl maybeToken =
    case maybeToken of
        Just token ->
            ( { events = RemoteData.Loading
              , currentPage = 1
              , form = emptyEventFormData
              , formStatus = FormIdle
              , kmlImportStatus = KmlIdle
              , kmlQueue = []
              , showNewForm = False
              }
            , Api.fetchAllEvents pbBaseUrl token 1 Types.EventsGotEvents
            )

        Nothing ->
            ( { events = RemoteData.NotAsked
              , currentPage = 1
              , form = emptyEventFormData
              , formStatus = FormIdle
              , kmlImportStatus = KmlIdle
              , kmlQueue = []
              , showNewForm = False
              }
            , Cmd.none
            )


view : AuthState -> EventsPage -> Html Msg
view =
    View.Events.view
