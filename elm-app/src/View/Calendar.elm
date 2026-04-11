module View.Calendar exposing (view)

import Component.Alert as Alert
import Component.Spinner as Spinner
import DateUtils exposing (daysInMonth, finnishMonthName, formatEventDateDisplay, monthGrid, nextMonth, prevMonth, utcStringToHelsinkiDateInput)
import FeatherIcons
import Html exposing (Html, a, button, div, h3, p, span, text)
import Html.Attributes exposing (attribute, class, classList, tabindex)
import Html.Events exposing (onClick)
import I18n exposing (MsgKey(..), t)
import RemoteData exposing (RemoteData)
import Types exposing (AuthState, CalendarPage, CalendarViewMode(..), Event, Msg(..))
import View.Icons exposing (featherIcon)


view : AuthState -> CalendarPage -> Html Msg
view authState page =
    div [ class "p-4" ]
        [ case authState of
            Types.Authenticated _ ->
                text ""

            Types.NotAuthenticated ->
                p [ class "type-caption text-text-muted mb-2" ]
                    [ text (t SubmitByEmailText)
                    , text " "
                    , a
                        [ class "text-brand underline"
                        , attribute "href" "mailto:palikkaharrastajatry@outlook.com?subject=Uusi%20tapahtuma%20Palikkakalenteriin&body=Tapahtuman%20nimi%3A%0D%0A%0D%0ATarkempi%20kuvaus%3A%0D%0A%0D%0APaikkakunta%3A%0D%0A%0D%0AAlkaa%3A%0D%0A%0D%0AP%C3%A4%C3%A4ttyy%3A%0D%0A%0D%0AKotisivut%3A%0D%0A%0D%0A"
                        ]
                        [ text (t SubmitByEmailLinkText) ]
                    ]
        , viewCalendarNav page
        , case page.viewMode of
            MonthGrid ->
                case page.events of
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
                        viewMonthGrid page events

            ListView ->
                case page.events of
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
                        viewListView page events
        ]


viewCalendarNav : CalendarPage -> Html Msg
viewCalendarNav page =
    let
        ( prevY, prevM ) =
            prevMonth page.year page.month

        ( nextY, nextM ) =
            nextMonth page.year page.month
    in
    div [ class "flex items-center gap-4 mb-4 flex-wrap" ]
        [ button
            [ onClick (CalendarSetMonth prevY prevM)
            , class "px-2 py-1 border rounded hover:bg-bg-subtle focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand focus-visible:ring-offset-1"
            ]
            [ featherIcon FeatherIcons.chevronLeft 16 ]
        , span [ class "type-h3" ]
            [ text (finnishMonthName page.month ++ " " ++ String.fromInt page.year) ]
        , button
            [ onClick (CalendarSetMonth nextY nextM)
            , class "px-2 py-1 border rounded hover:bg-bg-subtle focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand focus-visible:ring-offset-1"
            ]
            [ featherIcon FeatherIcons.chevronRight 16 ]
        , button
            [ onClick (CalendarSetMonth page.todayYear page.todayMonth)
            , class "px-3 py-1 border rounded hover:bg-bg-subtle focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand focus-visible:ring-offset-1"
            ]
            [ text (t CalToday) ]
        ]


viewMonthGrid : CalendarPage -> List Event -> Html Msg
viewMonthGrid page events =
    div []
        [ div [ class "grid grid-cols-7 text-center type-overline text-text-muted mb-1" ]
            (List.map (\d -> div [] [ text d ])
                [ "Ma", "Ti", "Ke", "To", "Pe", "La", "Su" ]
            )
        , div [ class "grid grid-cols-7 border-t border-l" ]
            (List.concatMap (List.map (viewDayCell page events))
                (monthGrid page.year page.month)
            )
        ]


viewDayCell : CalendarPage -> List Event -> Maybe Int -> Html Msg
viewDayCell page events maybeDay =
    case maybeDay of
        Nothing ->
            div [ class "border-r border-b min-h-24 bg-bg-subtle" ] []

        Just day ->
            let
                dayEvents =
                    List.filter (eventOnDay page.year page.month day) events

                isToday =
                    page.year == page.todayYear && page.month == page.todayMonth && day == page.todayDay
            in
            div
                [ class
                    ("border-r border-b min-h-24 p-1 relative overflow-hidden"
                        ++ (if isToday then
                                " bg-brand-yellow/10"

                            else
                                ""
                           )
                    )
                ]
                [ span
                    [ class
                        (if isToday then
                            "type-caption text-white bg-brand rounded-full inline-flex items-center justify-center w-5 h-5 float-right"

                         else
                            "type-caption text-text-muted float-right"
                        )
                    ]
                    [ text (String.fromInt day) ]
                , div [ class "mt-5 flex flex-col gap-0.5 -mx-1" ]
                    (List.take 3 (List.map (\ev -> viewEventChip (chipPos page.year page.month day ev) ev) dayEvents)
                        ++ (if List.length dayEvents > 3 then
                                [ div [ class "type-caption text-text-muted mx-1" ]
                                    [ text ("+" ++ String.fromInt (List.length dayEvents - 3) ++ " lisää") ]
                                ]

                            else
                                []
                           )
                    )
                ]


type ChipPosition
    = ChipSingle
    | ChipStart
    | ChipMiddle
    | ChipEnd


chipPos : Int -> Int -> Int -> Event -> ChipPosition
chipPos year month day event =
    let
        dayStr =
            String.fromInt year
                ++ "-"
                ++ String.padLeft 2 '0' (String.fromInt month)
                ++ "-"
                ++ String.padLeft 2 '0' (String.fromInt day)

        isStart =
            dayStr == helsinkiDateStr event.startDate

        isEnd =
            case event.endDate of
                Nothing ->
                    True

                Just endDate ->
                    dayStr == helsinkiDateStr endDate
    in
    case ( isStart, isEnd ) of
        ( True, True ) ->
            ChipSingle

        ( True, False ) ->
            ChipStart

        ( False, True ) ->
            ChipEnd

        _ ->
            ChipMiddle


viewEventChip : ChipPosition -> Event -> Html Msg
viewEventChip pos event =
    let
        shapeClass =
            case pos of
                ChipSingle ->
                    "rounded mx-1 px-1"

                ChipStart ->
                    "rounded-l ml-1 mr-0 pl-1"

                ChipMiddle ->
                    "mx-0 px-0"

                ChipEnd ->
                    "rounded-r ml-0 mr-1 pr-1"

        label =
            case pos of
                ChipSingle ->
                    event.title

                ChipStart ->
                    event.title

                _ ->
                    "\u{00A0}"
    in
    div
        [ classList
            [ ( "event-all-day", event.allDay )
            , ( "event-timed", not event.allDay )
            ]
        , class shapeClass
        , onClick (CalendarClickEvent event.id)
        , tabindex 0
        , attribute "role" "button"
        , attribute "aria-label" event.title
        ]
        [ text label ]


viewListView : CalendarPage -> List Event -> Html Msg
viewListView page events =
    let
        monthEvents =
            List.filter (eventInMonth page.year page.month) events
    in
    if List.isEmpty monthEvents then
        div [ class "text-text-muted text-center py-8" ] [ text (t CalNoEvents) ]

    else
        div [ class "flex flex-col gap-4" ]
            (List.map viewListEvent monthEvents)


viewListEvent : Event -> Html Msg
viewListEvent event =
    div
        [ class "border rounded p-3 cursor-pointer hover:bg-bg-subtle"
        , onClick (CalendarClickEvent event.id)
        ]
        [ p [ class "type-caption text-text-muted" ] [ text (formatEventDateDisplay event) ]
        , h3 [ class "type-h4" ] [ text event.title ]
        , case event.location of
            Nothing ->
                text ""

            Just loc ->
                p [ class "type-caption text-text-muted" ] [ text loc ]
        ]



-- HELPERS


{-| Helsinki-local date string ("YYYY-MM-DD") for an event's UTC date string.
Used for calendar placement — avoids the UTC-midnight-before-midnight-Helsinki bug.
-}
helsinkiDateStr : String -> String
helsinkiDateStr =
    utcStringToHelsinkiDateInput


eventOnDay : Int -> Int -> Int -> Event -> Bool
eventOnDay year month day event =
    let
        dayStr =
            String.fromInt year
                ++ "-"
                ++ String.padLeft 2 '0' (String.fromInt month)
                ++ "-"
                ++ String.padLeft 2 '0' (String.fromInt day)

        startStr =
            helsinkiDateStr event.startDate
    in
    -- A multi-day event occupies every day from startDate through endDate.
    dayStr
        >= startStr
        && (case event.endDate of
                Nothing ->
                    dayStr == startStr

                Just endDate ->
                    dayStr <= helsinkiDateStr endDate
           )


eventInMonth : Int -> Int -> Event -> Bool
eventInMonth year month event =
    let
        firstDay =
            String.fromInt year
                ++ "-"
                ++ String.padLeft 2 '0' (String.fromInt month)
                ++ "-01"

        lastDay =
            String.fromInt year
                ++ "-"
                ++ String.padLeft 2 '0' (String.fromInt month)
                ++ "-31"

        startStr =
            helsinkiDateStr event.startDate
    in
    -- Event overlaps with this month if it starts on or before the last day
    -- of the month AND (no end date: it must start in this month; OR end date:
    -- the end must reach into or past this month's first day).
    startStr
        <= lastDay
        && (case event.endDate of
                Nothing ->
                    startStr >= firstDay

                Just endDate ->
                    helsinkiDateStr endDate >= firstDay
           )
