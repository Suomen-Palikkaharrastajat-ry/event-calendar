module View.EventDetail exposing (view)

import Api
import DateUtils exposing (formatEventDateDisplay)
import Html exposing (Html, a, button, div, h1, img, p, span, text)
import Html.Attributes exposing (alt, class, href, src, target)
import Html.Events exposing (onClick)
import I18n exposing (MsgKey(..), t)
import RemoteData exposing (RemoteData)
import Route exposing (Route(..), toHref)
import Types exposing (AuthState(..), EventDetailPage, Msg(..), isAuthenticated)


view : String -> AuthState -> String -> EventDetailPage -> Html Msg
view pbBaseUrl authState _ detPage =
    div [ class "max-w-2xl mx-auto p-4" ]
        [ button
            [ onClick (NavigateTo (RouteCalendar Nothing))
            , class "text-sm text-blue-600 hover:underline mb-4 inline-block"
            ]
            [ text (t DetailBack) ]
        , case detPage.event of
            RemoteData.NotAsked ->
                text ""

            RemoteData.Loading ->
                div [ class "text-gray-500 text-center py-8" ] [ text (t Loading) ]

            RemoteData.Failure _ ->
                div [ class "text-red-600 py-4" ] [ text (t ErrorUnknown) ]

            RemoteData.Success event ->
                div []
                    [ div [ class "flex justify-between items-start mb-2" ]
                        [ h1 [ class "text-2xl font-bold" ] [ text event.title ]
                        , if isAuthenticated authState then
                            div [ class "flex gap-2 ml-4 shrink-0" ]
                                [ button
                                    [ onClick (NavigateTo (RouteEventEdit event.id))
                                    , class "px-3 py-1 bg-blue-600 text-white rounded hover:bg-blue-700 text-sm"
                                    ]
                                    [ text (t DetailEdit) ]
                                , button
                                    [ onClick DetailRequestDelete
                                    , class "px-3 py-1 bg-red-600 text-white rounded hover:bg-red-700 text-sm"
                                    ]
                                    [ text (t DetailDelete) ]
                                ]

                          else
                            text ""
                        ]
                    , if detPage.deleteConfirm then
                        div [ class "flex items-center gap-3 p-3 mb-3 bg-red-50 border border-red-200 rounded" ]
                            [ span [ class "text-red-700 font-medium" ] [ text "Poistetaanko tapahtuma?" ]
                            , button
                                [ onClick DetailConfirmDelete
                                , class "px-3 py-1 bg-red-600 text-white rounded hover:bg-red-700 text-sm"
                                ]
                                [ text (t DetailDeleteConfirm) ]
                            , button
                                [ onClick (NavigateTo (RouteCalendar Nothing))
                                , class "px-3 py-1 border rounded hover:bg-gray-100 text-sm"
                                ]
                                [ text (t DetailDeleteCancel) ]
                            ]

                      else
                        text ""
                    , p [ class "text-gray-600 mb-3" ] [ text (formatEventDateDisplay event) ]
                    , case event.location of
                        Nothing ->
                            text ""

                        Just loc ->
                            div [ class "mb-3" ]
                                [ span [ class "font-semibold mr-1" ] [ text (t DetailLocation ++ ":") ]
                                , case event.point of
                                    Just pt ->
                                        a
                                            [ href
                                                ("https://www.openstreetmap.org/?mlat="
                                                    ++ String.fromFloat pt.lat
                                                    ++ "&mlon="
                                                    ++ String.fromFloat pt.lon
                                                    ++ "&zoom=15"
                                                )
                                            , target "_blank"
                                            , class "text-blue-600 hover:underline"
                                            ]
                                            [ text loc ]

                                    Nothing ->
                                        span [] [ text loc ]
                                ]
                    , case event.description of
                        Nothing ->
                            text ""

                        Just desc ->
                            div [ class "mb-4 whitespace-pre-line text-gray-800" ] [ text desc ]
                    , case event.image of
                        Nothing ->
                            text ""

                        Just filename ->
                            div [ class "mb-4" ]
                                [ img
                                    [ src (Api.imageUrl pbBaseUrl event.id filename)
                                    , alt (Maybe.withDefault "" event.imageDescription)
                                    , class "max-w-full rounded shadow"
                                    ]
                                    []
                                ]
                    , case event.url of
                        Nothing ->
                            text ""

                        Just url ->
                            div [ class "mb-4" ]
                                [ a
                                    [ href url
                                    , target "_blank"
                                    , class "text-blue-600 hover:underline"
                                    ]
                                    [ text (t DetailMoreInfo) ]
                                ]
                    ]
        ]
