module Page.EventDetail exposing (init, view)

import Api
import Html exposing (Html)
import RemoteData
import Types exposing (AuthState, EventDetailPage, Msg(..))
import View.EventDetail


init : Maybe String -> String -> ( EventDetailPage, Cmd Msg )
init maybeToken id =
    ( { event = RemoteData.Loading
      , deleteConfirm = False
      }
    , Api.fetchEvent maybeToken id DetailGotEvent
    )


view : AuthState -> String -> EventDetailPage -> Html Msg
view =
    View.EventDetail.view
