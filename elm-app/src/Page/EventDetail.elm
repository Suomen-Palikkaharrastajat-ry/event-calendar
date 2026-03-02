{- Event detail page — owns the EventDetailPage state type and init.

   Page/View split: this module handles state and init; all rendering lives in
   View.EventDetail.  The update logic for Detail* messages is in Main.elm
   (search for `PageEventDetail`).
-}


module Page.EventDetail exposing (init, view)

import Api
import Html exposing (Html)
import RemoteData
import Types exposing (AuthState, EventDetailPage, Msg(..))
import View.EventDetail


init : String -> Maybe String -> String -> ( EventDetailPage, Cmd Msg )
init pbBaseUrl maybeToken id =
    ( { event = RemoteData.Loading
      , deleteConfirm = False
      }
    , Api.fetchEvent pbBaseUrl maybeToken id DetailGotEvent
    )


view : String -> AuthState -> String -> EventDetailPage -> Html Msg
view =
    View.EventDetail.view
