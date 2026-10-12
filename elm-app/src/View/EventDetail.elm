module View.EventDetail exposing (eventCalendarRoute, view)

{-| Event detail page view.
-}

import Api
import Component.Alert as Alert
import Component.Button as Button
import Component.LoadState as LoadState
import DateUtils exposing (formatEventDateDisplay)
import FeatherIcons
import FinnishTime exposing (utcStringToHelsinkiDateInput)
import Html exposing (Html, a, div, h1, img, p, span, text)
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
        [ div []
            [ case detPage.event of
                RemoteData.Success event ->
                    backButton (eventCalendarRoute event)

                _ ->
                    backButton (RouteCalendar Nothing)
            , LoadState.view
                { loadingLabel = t Loading
                , errorMessage = Api.httpErrorToString
                , onRetry = Nothing
                , retryLabel = ""
                }
                (fromRemoteData detPage.event)
                (\event ->
                    div []
                        [ div [ class "flex justify-between items-start mb-2" ]
                            [ h1 [ class "type-h1" ] [ text (Types.displayTitle event) ]
                            , if isAuthenticated authState then
                                div [ class "flex gap-2 ml-4 shrink-0" ]
                                    [ Button.new
                                        { label = t DetailEdit
                                        , onClick = NavigateTo (RouteEventEdit event.id)
                                        }
                                        |> Button.withVariant Button.Secondary
                                        |> Button.withSize Button.Small
                                        |> Button.toHtml
                                    , Button.new
                                        { label = t DetailDelete
                                        , onClick = DetailRequestDelete
                                        }
                                        |> Button.withVariant Button.Danger
                                        |> Button.withSize Button.Small
                                        |> Button.toHtml
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
                                            [ Button.new
                                                { label = t DetailDeleteConfirm
                                                , onClick = DetailConfirmDelete
                                                }
                                                |> Button.withVariant Button.Danger
                                                |> Button.withSize Button.Small
                                                |> Button.toHtml
                                            , Button.new
                                                { label = t DetailDeleteCancel
                                                , onClick = NavigateTo (RouteCalendar Nothing)
                                                }
                                                |> Button.withVariant Button.Secondary
                                                |> Button.withSize Button.Small
                                                |> Button.toHtml
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
                                            if pt.lat == 0 && pt.lon == 0 then
                                                span [] [ text loc ]

                                            else
                                                a
                                                    [ href
                                                        ("https://www.openstreetmap.org/?mlat="
                                                            ++ String.fromFloat pt.lat
                                                            ++ "&mlon="
                                                            ++ String.fromFloat pt.lon
                                                            ++ "&zoom=15"
                                                        )
                                                    , target "_blank"
                                                    , class "text-brand underline inline-flex items-center gap-1"
                                                    ]
                                                    [ text loc
                                                    , featherIcon FeatherIcons.globe 14
                                                    ]

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
                                        , class "text-brand underline inline-flex items-center gap-1"
                                        ]
                                        [ text (t DetailMoreInfo)
                                        , featherIcon FeatherIcons.externalLink 14
                                        ]
                                    ]
                        ]
                )
            ]
        ]


fromRemoteData : RemoteData e a -> LoadState.State e a
fromRemoteData rd =
    case rd of
        RemoteData.NotAsked ->
            LoadState.NotAsked

        RemoteData.Loading ->
            LoadState.Loading

        RemoteData.Failure e ->
            LoadState.Failure e

        RemoteData.Success a ->
            LoadState.Success a


backButton : Route -> Html Msg
backButton route =
    a
        [ href (toHref route)
        , onClick (NavigateTo route)
        , class "flex items-center gap-1 type-caption text-brand hover:underline mb-4"
        ]
        [ featherIcon FeatherIcons.arrowLeft 14, text (t DetailBack) ]


eventCalendarRoute : Types.Event -> Route
eventCalendarRoute event =
    case utcStringToHelsinkiDateInput event.startDate of
        "" ->
            RouteCalendar Nothing

        dateStr ->
            RouteCalendar (Just dateStr)
