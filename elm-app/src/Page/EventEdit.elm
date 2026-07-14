{- Event edit page — owns the EventEditPage state type and init.

   Page/View split: this module handles state and init; all rendering lives in
   View.EventForm (viewEdit).  The update logic for EditForm* messages is in
   Main.elm (search for `PageEventEdit`).
-}


module Page.EventEdit exposing (init, view)

import Api
import Date
import DatePicker
import DateUtils
import Html exposing (Html)
import RemoteData
import Time exposing (Posix)
import Types exposing (AuthState, EventEditPage, FormStatus(..), Msg(..), emptyEventFormData)
import View.EventForm


init : Posix -> String -> Maybe String -> String -> ( EventEditPage, Cmd Msg )
init now pbBaseUrl maybeToken id =
    let
        currentDate =
            Date.fromPosix (DateUtils.helsinkiZone now) now

        startDatePicker =
            DatePicker.initFromDate currentDate

        endDatePicker =
            DatePicker.initFromDate currentDate
    in
    ( { event = RemoteData.Loading
      , form = emptyEventFormData
      , startDatePicker = startDatePicker
      , endDatePicker = endDatePicker
      , formStatus = FormIdle
      }
    , Api.fetchEvent pbBaseUrl maybeToken id EditGotEvent
    )


view : EventEditPage -> Html Msg
view =
    View.EventForm.viewEdit
