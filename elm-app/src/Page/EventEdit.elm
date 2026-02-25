module Page.EventEdit exposing (init, view)

import Api
import Html exposing (Html)
import RemoteData
import Types exposing (AuthState, EventEditPage, FormStatus(..), Msg(..), emptyEventFormData)
import View.EventForm


init : Maybe String -> String -> ( EventEditPage, Cmd Msg )
init maybeToken id =
    ( { event = RemoteData.Loading
      , form = emptyEventFormData
      , formStatus = FormIdle
      }
    , Api.fetchEvent maybeToken id EditGotEvent
    )


view : EventEditPage -> Html Msg
view =
    View.EventForm.viewEdit
