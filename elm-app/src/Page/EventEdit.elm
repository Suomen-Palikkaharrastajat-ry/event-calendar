module Page.EventEdit exposing (init, view)

{-| Event edit page — owns the EventEditPage state type and init.

Page/View split: this module handles state and init; all rendering lives in
View.EventForm (viewEdit). The update logic for EditForm\* messages is in
Main.elm (search for `PageEventEdit`).

-}

import Api
import Date
import DatePicker
import FinnishTime
import Html exposing (Html)
import Lang exposing (Lang)
import PocketBaseAuth exposing (AuthState)
import RemoteData
import Time exposing (Posix)
import Types exposing (EventEditPage, FormStatus(..), Msg(..), emptyEventFormData)
import View.EventForm


init : Posix -> String -> Maybe String -> String -> ( EventEditPage, Cmd Msg )
init now pbBaseUrl maybeToken id =
    let
        currentDate =
            Date.fromPosix (FinnishTime.helsinkiZone now) now

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


view : Lang -> EventEditPage -> Html Msg
view lang =
    View.EventForm.viewEdit lang
