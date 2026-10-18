module Page.EventDetail exposing (init, view)

{-| Event detail page — owns the EventDetailPage state type and init.

Page/View split: this module handles state and init; all rendering lives in
View.EventDetail. The update logic for Detail\* messages is in Main.elm
(search for `PageEventDetail`).

-}

import Api
import Html exposing (Html)
import Lang exposing (Lang)
import PocketBaseAuth exposing (AuthState(..))
import RemoteData
import Types exposing (EventDetailPage, Msg(..))
import View.EventDetail


{-| Signed in, the event comes from PocketBase (drafts included); signed out, from the static
feed files.
-}
init : AuthState -> String -> String -> String -> ( EventDetailPage, Cmd Msg )
init authState pbBaseUrl staticBaseUrl id =
    ( { event = RemoteData.Loading
      , deleteConfirm = False
      }
    , case authState of
        Authenticated user ->
            Api.fetchEvent pbBaseUrl (Just user.token) id DetailGotEvent

        NotAuthenticated ->
            Api.fetchStaticEvent staticBaseUrl id DetailGotEvent
    )


view : Lang -> (String -> String -> String) -> AuthState -> String -> EventDetailPage -> Html Msg
view lang =
    View.EventDetail.view lang
