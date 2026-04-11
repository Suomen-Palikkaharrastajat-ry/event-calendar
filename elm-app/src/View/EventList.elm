module View.EventList exposing (view)

import Component.Alert as Alert
import Component.Button as Button
import Component.Spinner as Spinner
import DateUtils exposing (formatEventDateDisplay, parseUtcString, toHelsinkiParts)
import FeatherIcons
import Html exposing (Html, a, div, h1, h3, p, text)
import Html.Attributes exposing (class, href, target)
import I18n exposing (MsgKey(..), t)
import RemoteData exposing (RemoteData)
import Route exposing (Route(..), toHref)
import Time exposing (Posix, posixToMillis)
import Types exposing (AuthState(..), Event, EventListPage, Msg(..))
import View.Icons exposing (featherIcon)


view : AuthState -> Posix -> EventListPage -> Html Msg
view authState now page =
    div [ class "p-4" ]
        [ div [ class "flex items-center justify-between mb-4" ]
            [ h1 [ class "type-h1" ] [ text (t NavEvents) ]
            , case authState of
                Authenticated _ ->
                    Button.viewLink
                        { label = "+ " ++ t EventListNewEvent
                        , variant = Button.Primary
                        , size = Button.Small
                        , href = toHref RouteEventNew
                        }

                NotAuthenticated ->
                    text ""
            ]
        , case page.events of
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

            RemoteData.Success events ->
                let
                    items =
                        reorderEvents now events
                in
                if List.isEmpty items then
                    div [ class "text-text-muted text-center py-8" ] [ text (t EventListEmpty) ]

                else
                    div [ class "flex flex-col gap-4" ]
                        (List.map (viewEvent now authState) items)
        ]


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


viewEvent : Posix -> AuthState -> Event -> Html Msg
viewEvent now authState event =
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
            if isPast event then
                "border rounded p-3 hover:bg-bg-subtle opacity-50"

            else
                "border rounded p-3 hover:bg-bg-subtle"
    in
    div [ class classes ]
        [ div [ class "flex items-start justify-between gap-4" ]
            [ div []
                [ p [ class "type-caption text-text-muted" ] [ text (formatEventDateDisplay event) ]
                , h3 [ class "type-h4" ]
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
                        p [ class "type-caption text-text-muted" ] [ text loc ]
                ]
            , div [ class "flex items-center gap-2 shrink-0" ]
                [ case event.point of
                    Nothing ->
                        text ""

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
                            , class "text-brand hover:text-brand-yellow transition-colors"
                            ]
                            [ featherIcon FeatherIcons.globe 16 ]
                , case event.url of
                    Nothing ->
                        text ""

                    Just url ->
                        a
                            [ href url
                            , target "_blank"
                            , class "text-brand hover:text-brand-yellow transition-colors"
                            ]
                            [ featherIcon FeatherIcons.externalLink 16 ]
                , case authState of
                    Authenticated _ ->
                        a
                            [ href (toHref (RouteEventEdit event.id))
                            , class "type-caption text-primary hover:underline"
                            ]
                            [ text (t EventListEdit) ]

                    NotAuthenticated ->
                        text ""
                ]
            ]
        ]
