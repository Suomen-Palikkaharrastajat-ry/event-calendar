module View.EventList exposing (view)

{-| Public events list page view.
-}

import Api
import Component.Button as Button
import Component.LoadState as LoadState
import DateUtils exposing (formatEventDateDisplay)
import FeatherIcons
import FinnishTime exposing (parseUtcString, toHelsinkiParts)
import Html exposing (Html, a, div, h1, h3, p, span, text)
import Html.Attributes exposing (attribute, class, href, target)
import I18n exposing (MsgKey(..), t)
import Lang exposing (Lang)
import RemoteData exposing (RemoteData)
import Route exposing (Route(..), toHref)
import Time exposing (Posix, posixToMillis)
import Types exposing (AuthState(..), Event, EventListPage, EventState(..), Msg(..))
import View.Icons exposing (featherIcon)


view : Lang -> AuthState -> Posix -> EventListPage -> Html Msg
view lang authState now page =
    div [ class "p-4" ]
        [ div [ class "flex items-center justify-between mb-4" ]
            [ h1 [ class "type-h1" ] [ text (t lang NavEvents) ]
            , case authState of
                Authenticated _ ->
                    Button.link
                        { label = "+ " ++ t lang EventListNewEvent
                        , href = toHref RouteEventNew
                        }
                        |> Button.withVariant Button.Primary
                        |> Button.withSize Button.Small
                        |> Button.toHtml

                NotAuthenticated ->
                    text ""
            ]
        , LoadState.view
            { loadingLabel = t lang Loading
            , errorMessage = Api.httpErrorToString lang
            , onRetry = Nothing
            , retryLabel = ""
            }
            (fromRemoteData page.events)
            (\events ->
                let
                    items =
                        reorderEvents now events
                in
                if List.isEmpty items then
                    div [ class "text-text-muted text-center py-8" ] [ text (t lang EventListEmpty) ]

                else
                    div [ class "flex flex-col gap-4" ]
                        (List.map (viewEvent lang now authState) items)
            )
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


{-| Reorder events so upcoming events appear before past events, preserving relative order.
-}
reorderEvents : Posix -> List Event -> List Event
reorderEvents now eventsList =
    let
        isPast event =
            let
                dateIsPast posix =
                    let
                        p =
                            toHelsinkiParts posix

                        n =
                            toHelsinkiParts now
                    in
                    ( p.year, p.month, p.day ) < ( n.year, n.month, n.day )
            in
            if event.allDay then
                case event.endDate |> Maybe.andThen parseUtcString of
                    Just endPosix ->
                        dateIsPast endPosix

                    Nothing ->
                        case parseUtcString event.startDate of
                            Just startPosix ->
                                dateIsPast startPosix

                            Nothing ->
                                False

            else
                case event.endDate |> Maybe.andThen parseUtcString of
                    Just endPosix ->
                        posixToMillis endPosix < posixToMillis now

                    Nothing ->
                        case parseUtcString event.startDate of
                            Just startPosix ->
                                posixToMillis startPosix < posixToMillis now

                            Nothing ->
                                False

        ( past, upcoming ) =
            List.foldl
                (\r ( ps, us ) ->
                    if isPast r then
                        ( ps ++ [ r ], us )

                    else
                        ( ps, us ++ [ r ] )
                )
                ( [], [] )
                eventsList

        eventMillis e =
            case e.endDate |> Maybe.andThen parseUtcString of
                Just p ->
                    posixToMillis p

                Nothing ->
                    case parseUtcString e.startDate of
                        Just s ->
                            posixToMillis s

                        Nothing ->
                            0

        pastDesc =
            List.sortBy (\e -> Basics.negate (eventMillis e)) past
    in
    upcoming ++ pastDesc


viewEvent : Lang -> Posix -> AuthState -> Event -> Html Msg
viewEvent lang now authState event =
    let
        isPast ev =
            let
                dateIsPast posix =
                    let
                        p =
                            toHelsinkiParts posix

                        n =
                            toHelsinkiParts now
                    in
                    ( p.year, p.month, p.day ) < ( n.year, n.month, n.day )
            in
            if ev.allDay then
                case ev.endDate |> Maybe.andThen parseUtcString of
                    Just endPosix ->
                        dateIsPast endPosix

                    Nothing ->
                        case parseUtcString ev.startDate of
                            Just startPosix ->
                                dateIsPast startPosix

                            Nothing ->
                                False

            else
                case ev.endDate |> Maybe.andThen parseUtcString of
                    Just endPosix ->
                        posixToMillis endPosix < posixToMillis now

                    Nothing ->
                        case parseUtcString ev.startDate of
                            Just startPosix ->
                                posixToMillis startPosix < posixToMillis now

                            Nothing ->
                                False

        classes =
            if isPast event || event.state /= Published then
                "border rounded p-3 hover:bg-bg-subtle opacity-50"

            else
                "border rounded p-3 hover:bg-bg-subtle"
    in
    div [ class classes ]
        [ div [ class "flex items-start justify-between gap-4" ]
            [ div []
                [ p [ class "type-caption text-text-muted" ] [ text (formatEventDateDisplay lang event) ]
                , h3 [ class "type-h4" ]
                    [ a
                        [ href (toHref (RouteEventDetail event.id))
                        , class "hover:underline"
                        ]
                        [ span (I18n.contentAttrs lang) [ text (Types.displayTitle (I18n.t lang I18n.CancelledPrefix) event) ] ]
                    ]
                , case event.location of
                    Nothing ->
                        text ""

                    Just loc ->
                        p [ class "type-caption text-text-muted" ] [ span (I18n.contentAttrs lang) [ text loc ] ]
                ]
            , div [ class "flex items-center gap-2 shrink-0" ]
                [ case event.point of
                    Nothing ->
                        text ""

                    Just pt ->
                        if pt.lat == 0 && pt.lon == 0 then
                            text ""

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
                                , class "text-brand hover:text-brand-yellow transition-colors"
                                , attribute "aria-label" (t lang ListShowOnMap)
                                ]
                                [ featherIcon FeatherIcons.mapPin 16 ]
                , case event.url of
                    Nothing ->
                        text ""

                    Just url ->
                        a
                            [ href url
                            , target "_blank"
                            , class "text-brand hover:text-brand-yellow transition-colors"
                            , attribute "aria-label" (t lang ListOpenWebsite)
                            ]
                            [ featherIcon FeatherIcons.externalLink 16 ]
                , case authState of
                    Authenticated _ ->
                        a
                            [ href (toHref (RouteEventEdit event.id))
                            , class "type-caption text-primary hover:underline"
                            ]
                            [ text (t lang EventListEdit) ]

                    NotAuthenticated ->
                        text ""
                ]
            ]
        ]
