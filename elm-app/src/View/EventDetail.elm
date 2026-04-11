module View.EventDetail exposing (view)

import Api
import Component.Alert as Alert
import Component.Button as Button
import Component.Spinner as Spinner
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
                div [ class "flex justify-center py-8" ]
                    [ Spinner.view { size = Spinner.Medium, label = t Loading } ]

            RemoteData.Failure _ ->
                div [ class "py-4" ]
                    [ Alert.view
                        { alertType = Alert.Error
                        , title = Nothing
                        , body = [ text (t ErrorUnknown) ]
                        , customIcon = Nothing
                        , onDismiss = Nothing
                        }
                    ]

            RemoteData.Success event ->
                div []
                    [ div [ class "flex justify-between items-start mb-2" ]
                        [ h1 [ class "type-h1" ] [ text event.title ]
                        , if isAuthenticated authState then
                            div [ class "flex gap-2 ml-4 shrink-0" ]
                                [ Button.view
                                    { label = t DetailEdit
                                    , variant = Button.Secondary
                                    , size = Button.Small
                                    , onClick = NavigateTo (RouteEventEdit event.id)
                                    , disabled = False
                                    , loading = False
                                    , ariaPressedState = Nothing
                                    }
                                , Button.view
                                    { label = t DetailDelete
                                    , variant = Button.Danger
                                    , size = Button.Small
                                    , onClick = DetailRequestDelete
                                    , disabled = False
                                    , loading = False
                                    , ariaPressedState = Nothing
                                    }
                                ]

                          else
                            text ""
                        ]
                    , if detPage.deleteConfirm then
                        div [ class "mb-3" ]
                            [ Alert.view
                                { alertType = Alert.Error
                                , title = Just "Poistetaanko tapahtuma?"
                                , body =
                                    [ div [ class "flex gap-2 mt-2" ]
                                        [ Button.view
                                            { label = t DetailDeleteConfirm
                                            , variant = Button.Danger
                                            , size = Button.Small
                                            , onClick = DetailConfirmDelete
                                            , disabled = False
                                            , loading = False
                                            , ariaPressedState = Nothing
                                            }
                                        , Button.view
                                            { label = t DetailDeleteCancel
                                            , variant = Button.Secondary
                                            , size = Button.Small
                                            , onClick = NavigateTo (RouteCalendar Nothing)
                                            , disabled = False
                                            , loading = False
                                            , ariaPressedState = Nothing
                                            }
                                        ]
                                    ]
                                , customIcon = Nothing
                                , onDismiss = Nothing
                                }
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
