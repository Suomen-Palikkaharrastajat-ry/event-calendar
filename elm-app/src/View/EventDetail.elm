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
import Lang exposing (Lang)
import PocketBaseAuth exposing (AuthState(..), isAuthenticated)
import RemoteData exposing (RemoteData)
import Route exposing (Route(..), toHref)
import Types exposing (EventDetailPage, Msg(..))
import View.Icons exposing (featherIcon)


view : Lang -> String -> AuthState -> String -> EventDetailPage -> Html Msg
view lang pbBaseUrl authState _ detPage =
    div [ class "max-w-2xl mx-auto p-4" ]
        [ div []
            [ case detPage.event of
                RemoteData.Success event ->
                    backButton lang (eventCalendarRoute event)

                _ ->
                    backButton lang (RouteCalendar Nothing)
            , LoadState.view
                { loadingLabel = t lang Loading
                , errorMessage = Api.httpErrorToString lang
                , onRetry = Nothing
                , retryLabel = ""
                }
                (fromRemoteData detPage.event)
                (\event ->
                    div []
                        [ div [ class "flex justify-between items-start mb-2" ]
                            [ h1 [ class "type-h1" ] [ span (I18n.contentAttrs lang) [ text (Types.displayTitle (I18n.t lang I18n.CancelledPrefix) event) ] ]
                            , if isAuthenticated authState then
                                div [ class "flex gap-2 ml-4 shrink-0" ]
                                    [ Button.new
                                        { label = t lang DetailEdit
                                        , onClick = NavigateTo (RouteEventEdit event.id)
                                        }
                                        |> Button.withVariant Button.Secondary
                                        |> Button.withSize Button.Small
                                        |> Button.toHtml
                                    , Button.new
                                        { label = t lang DetailDelete
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
                                    , title = Just (t lang DetailDeleteQuestion)
                                    , body =
                                        [ div [ class "flex gap-2 mt-2" ]
                                            [ Button.new
                                                { label = t lang DetailDeleteConfirm
                                                , onClick = DetailConfirmDelete
                                                }
                                                |> Button.withVariant Button.Danger
                                                |> Button.withSize Button.Small
                                                |> Button.toHtml
                                            , Button.new
                                                { label = t lang DetailDeleteCancel
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
                        , p [ class "text-text-muted mb-3" ] [ text (formatEventDateDisplay lang event) ]
                        , case event.location of
                            Nothing ->
                                text ""

                            Just loc ->
                                div [ class "mb-3" ]
                                    [ span [ class "type-body-small mr-1" ] [ text (t lang DetailLocation ++ ":") ]
                                    , case event.point of
                                        Just pt ->
                                            if pt.lat == 0 && pt.lon == 0 then
                                                span [] [ span (I18n.contentAttrs lang) [ text loc ] ]

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
                                            span [] [ span (I18n.contentAttrs lang) [ text loc ] ]
                                    ]
                        , case event.description of
                            Nothing ->
                                text ""

                            Just desc ->
                                div [ class "mb-4 whitespace-pre-line text-text-primary" ] [ span (I18n.contentAttrs lang) [ text desc ] ]
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
                                        [ text (t lang DetailMoreInfo)
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


backButton : Lang -> Route -> Html Msg
backButton lang route =
    a
        [ href (toHref route)
        , onClick (NavigateTo route)
        , class "flex items-center gap-1 type-caption text-brand hover:underline mb-4"
        ]
        [ featherIcon FeatherIcons.arrowLeft 14, text (t lang DetailBack) ]


eventCalendarRoute : Types.Event -> Route
eventCalendarRoute event =
    case utcStringToHelsinkiDateInput event.startDate of
        "" ->
            RouteCalendar Nothing

        dateStr ->
            RouteCalendar (Just dateStr)
