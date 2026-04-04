module View.EventDetail exposing (view)

import Api
import DateUtils exposing (formatEventDateDisplay)
import FeatherIcons
import Html exposing (Html, a, button, div, h1, img, p, span, text)
import Html.Attributes exposing (alt, class, href, src, target)
import Html.Events exposing (onClick)
import I18n exposing (MsgKey(..), t)
import RemoteData exposing (RemoteData)
import Route exposing (Route(..), toHref)
import Types exposing (AuthState(..), EventDetailPage, Msg(..), isAuthenticated)
import View.Icons exposing (featherIcon)


view : String -> AuthState -> String -> EventDetailPage -> Html Msg
view pbBaseUrl authState _ detPage =
    div [ class "max-w-2xl mx-auto p-4" ]
        [ button
            [ onClick (NavigateTo (RouteCalendar Nothing))
            , class "flex items-center gap-1 type-caption text-brand hover:underline mb-4"
            ]
            [ featherIcon FeatherIcons.arrowLeft 14, text (t DetailBack) ]
        , case detPage.event of
            RemoteData.NotAsked ->
                text ""

            RemoteData.Loading ->
                div [ class "text-text-muted text-center py-8" ] [ text (t Loading) ]

            RemoteData.Failure _ ->
                div [ class "text-brand-red py-4" ] [ text (t ErrorUnknown) ]

            RemoteData.Success event ->
                div []
                    [ div [ class "flex justify-between items-start mb-2" ]
                        [ h1 [ class "type-h1" ] [ text event.title ]
                        , if isAuthenticated authState then
                            div [ class "flex gap-2 ml-4 shrink-0" ]
                                [ button
                                    [ onClick (NavigateTo (RouteEventEdit event.id))
                                    , class "px-3 py-1 bg-brand text-white rounded hover:opacity-90 type-caption"
                                    ]
                                    [ text (t DetailEdit) ]
                                , button
                                    [ onClick DetailRequestDelete
                                    , class "px-3 py-1 bg-brand-red text-white rounded hover:opacity-90 type-caption"
                                    ]
                                    [ text (t DetailDelete) ]
                                ]

                          else
                            text ""
                        ]
                    , if detPage.deleteConfirm then
                        div [ class "flex items-center gap-3 p-3 mb-3 bg-brand-red/10 border border-brand-red/30 rounded" ]
                            [ span [ class "text-brand-red type-body-small" ] [ text "Poistetaanko tapahtuma?" ]
                            , button
                                [ onClick DetailConfirmDelete
                                , class "px-3 py-1 bg-brand-red text-white rounded hover:opacity-90 type-caption"
                                ]
                                [ text (t DetailDeleteConfirm) ]
                            , button
                                [ onClick (NavigateTo (RouteCalendar Nothing))
                                , class "px-3 py-1 border rounded hover:bg-bg-subtle type-caption"
                                ]
                                [ text (t DetailDeleteCancel) ]
                            ]

                      else
                        text ""
                    , p [ class "text-text-muted mb-3" ] [ text (formatEventDateDisplay event) ]
                    , case event.location of
                        Nothing ->
                            text ""

                        Just loc ->
                            div [ class "mb-3" ]
                                [ span [ class "type-body-small mr-1" ] [ text (t DetailLocation ++ ":") ]
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
                                            , class "text-brand hover:underline"
                                            ]
                                            [ text loc ]

                                    Nothing ->
                                        span [] [ text loc ]
                                ]
                    , case event.description of
                        Nothing ->
                            text ""

                        Just desc ->
                            div [ class "mb-4 whitespace-pre-line text-text-primary" ] [ text desc ]
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
                                    , class "text-brand hover:underline"
                                    ]
                                    [ text (t DetailMoreInfo) ]
                                ]
                    ]
        ]
