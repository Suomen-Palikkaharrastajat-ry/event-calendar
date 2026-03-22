{- Event edit page — owns the EventEditPage state type and init.

   Page/View split: this module handles state and init; all rendering lives in
   View.EventForm (viewEdit).  The update logic for EditForm* messages is in
   Main.elm (search for `PageEventEdit`).
-}


module Page.EventEdit exposing (init, view)

import Api
import Html exposing (Html)
import RemoteData
import Types exposing (AuthState, EventEditPage, FormStatus(..), Msg(..), emptyEventFormData)
import View.EventForm


init : String -> Maybe String -> String -> ( EventEditPage, Cmd Msg )
init pbBaseUrl maybeToken id =
    ( { event = RemoteData.Loading
      , form = emptyEventFormData
      , formStatus = FormIdle
      }
    , Api.fetchEvent pbBaseUrl maybeToken id EditGotEvent
    )


view : EventEditPage -> Html Msg
view =
    View.EventForm.viewEdit
