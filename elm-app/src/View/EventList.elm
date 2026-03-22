module View.EventList exposing (view)

import DateUtils exposing (formatEventDateDisplay)
import Html exposing (Html, a, div, h1, h3, p, text)
import Html.Attributes exposing (class, href)
import I18n exposing (MsgKey(..), t)
import RemoteData exposing (RemoteData)
import Route exposing (Route(..), toHref)
import Types exposing (AuthState(..), Event, EventListPage, Msg(..))


view : AuthState -> EventListPage -> Html Msg
view authState page =
    div [ class "p-4" ]
        [ div [ class "flex items-center justify-between mb-4" ]
            [ h1 [ class "text-2xl font-bold" ] [ text (t NavEvents) ]
            , case authState of
                Authenticated _ ->
                    a
                        [ href (toHref RouteEventNew)
                        , class "btn-primary text-sm"
                        ]
                        [ text ("+ " ++ t EventListNewEvent) ]

                NotAuthenticated ->
                    text ""
            ]
        , case page.events of
            RemoteData.NotAsked ->
                text ""

            RemoteData.Loading ->
                div [ class "text-gray-500 text-center py-8" ] [ text (t Loading) ]

            RemoteData.Failure _ ->
                div [ class "text-red-600 text-center py-8" ] [ text (t ErrorUnknown) ]

            RemoteData.Success events ->
                if List.isEmpty events then
                    div [ class "text-gray-500 text-center py-8" ] [ text (t EventListEmpty) ]

                else
                    div [ class "flex flex-col gap-4" ]
                        (List.map (viewEvent authState) events)
        ]


viewEvent : AuthState -> Event -> Html Msg
viewEvent authState event =
    div [ class "border rounded p-3 hover:bg-gray-50" ]
        [ div [ class "flex items-start justify-between gap-4" ]
            [ div []
                [ p [ class "text-sm text-gray-500" ] [ text (formatEventDateDisplay event) ]
                , h3 [ class "font-semibold" ]
                    [ a
                        [ href (toHref (RouteEventDetail event.id))
                        , class "hover:underline"
                        ]
                        [ text event.title ]
                    ]
                , case event.location of
                    Nothing ->
                        text ""

                    Just loc ->
                        p [ class "text-sm text-gray-600" ] [ text loc ]
                ]
            , case authState of
                Authenticated _ ->
                    a
                        [ href (toHref (RouteEventEdit event.id))
                        , class "text-sm text-primary hover:underline shrink-0"
                        ]
                        [ text (t EventListEdit) ]

                NotAuthenticated ->
                    text ""
            ]
        ]
