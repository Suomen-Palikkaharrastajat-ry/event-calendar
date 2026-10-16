module Page.EventDetail exposing (init, view)

{-| Event detail page — owns the EventDetailPage state type and init.

Page/View split: this module handles state and init; all rendering lives in
View.EventDetail. The update logic for Detail\* messages is in Main.elm
(search for `PageEventDetail`).

-}

import Api
import Html exposing (Html)
import Lang exposing (Lang)
import PocketBaseAuth exposing (AuthState)
import RemoteData
import Types exposing (EventDetailPage, Msg(..))
import View.EventDetail


init : String -> Maybe String -> String -> ( EventDetailPage, Cmd Msg )
init pbBaseUrl maybeToken id =
    ( { event = RemoteData.Loading
      , deleteConfirm = False
      }
    , Api.fetchEvent pbBaseUrl maybeToken id DetailGotEvent
    )


view : Lang -> String -> AuthState -> String -> EventDetailPage -> Html Msg
view lang =
    View.EventDetail.view lang
