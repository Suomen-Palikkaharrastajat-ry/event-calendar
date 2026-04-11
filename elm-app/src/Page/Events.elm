{- Events management page — owns the EventsPage state type and init.

   Page/View split: this module handles state and init; all rendering lives in
   View.Events.  The update logic for EventsPage messages is in Main.elm
   (search for `PageEvents`).
-}


module Page.Events exposing (init, view)

import DatePicker
import Html exposing (Html)
import Time exposing (Posix)
import Types exposing (AuthState, EventsPage, FormStatus(..), KmlImportStatus(..), Msg(..), emptyEventFormData)
import View.Events


init : String -> Maybe String -> ( EventsPage, Cmd Msg )
init _ _ =
    let
        ( startDatePicker, startDatePickerCmd ) =
            DatePicker.init

        ( endDatePicker, endDatePickerCmd ) =
            DatePicker.init
    in
    ( { form = emptyEventFormData
      , startDatePicker = startDatePicker
      , endDatePicker = endDatePicker
      , formStatus = FormIdle
      , kmlImportStatus = KmlIdle
      , kmlQueue = []
      }
    , Cmd.batch
        [ Cmd.map EventsStartDatePickerChanged startDatePickerCmd
        , Cmd.map EventsEndDatePickerChanged endDatePickerCmd
        ]
    )


view : AuthState -> Posix -> EventsPage -> Html Msg
view =
    View.Events.view
