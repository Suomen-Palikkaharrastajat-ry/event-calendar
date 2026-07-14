{- Events management page — owns the EventsPage state type and init.

   Page/View split: this module handles state and init; all rendering lives in
   View.Events.  The update logic for EventsPage messages is in Main.elm
   (search for `PageEvents`).
-}


module Page.Events exposing (init, view)

import Date
import DatePicker
import DateUtils
import Html exposing (Html)
import Time exposing (Posix)
import Types exposing (AuthState, EventsPage, FormStatus(..), KmlImportStatus(..), Msg(..), emptyEventFormData)
import View.Events


init : Posix -> String -> Maybe String -> ( EventsPage, Cmd Msg )
init now _ _ =
    let
        currentDate =
            Date.fromPosix (DateUtils.helsinkiZone now) now

        startDatePicker =
            DatePicker.initFromDate currentDate

        endDatePicker =
            DatePicker.initFromDate currentDate
    in
    ( { form = emptyEventFormData
      , startDatePicker = startDatePicker
      , endDatePicker = endDatePicker
      , formStatus = FormIdle
      , kmlImportStatus = KmlIdle
      , kmlQueue = []
      }
    , Cmd.none
    )


view : AuthState -> Posix -> EventsPage -> Html Msg
view =
    View.Events.view
