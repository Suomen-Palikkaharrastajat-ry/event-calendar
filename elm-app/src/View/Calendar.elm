module View.Calendar exposing (view)

{-| Calendar page rendering. From `md` up it is a month grid with event chips;
below `md` the grid cannot fit readable titles, so it becomes a compact month
strip (days marked with bars) above an agenda grouped by week.
-}

import Api
import CalendarAgenda exposing (AgendaWeek)
import Component.LoadState as LoadState
import DateUtils exposing (formatEventDateDisplay)
import FeatherIcons
import FinnishTime exposing (daysInMonth, monthGrid, monthName, nextMonth, prevMonth, utcStringToHelsinkiDateInput)
import Html exposing (Html, a, button, div, h3, li, p, section, span, text, ul)
import Html.Attributes exposing (attribute, class, classList, id, tabindex, type_)
import Html.Events exposing (onClick)
import I18n exposing (MsgKey(..), t)
import Json.Decode as Decode
import Lang exposing (Lang)
import PocketBaseAuth exposing (AuthState(..))
import RemoteData exposing (RemoteData)
import Types exposing (CalendarPage, CalendarViewMode(..), Event, Msg(..))
import View.Icons exposing (featherIcon)


view : Lang -> String -> AuthState -> CalendarPage -> Html Msg
view lang contactEmail authState page =
    div [ class "p-4" ]
        [ case authState of
            Authenticated _ ->
                text ""

            NotAuthenticated ->
                p [ class "type-caption text-text-muted mb-2" ]
                    [ text (t lang SubmitByEmailText)
                    , text " "
                    , a
                        [ class "text-brand underline"
                        , attribute "href" (I18n.submitEventMailto lang contactEmail)
                        ]
                        [ text (t lang SubmitByEmailLinkText) ]
                    ]
        , viewCalendarNav lang page
        , case page.viewMode of
            MonthGrid ->
                LoadState.view
                    { loadingLabel = t lang Loading
                    , errorMessage = Api.httpErrorToString lang
                    , onRetry = Just (CalendarSetMonth page.year page.month)
                    , retryLabel = t lang Retry
                    }
                    (fromRemoteData page.events)
                    (\events ->
                        div []
                            [ div [ attribute "data-testid" "month-grid", class "hidden md:block" ]
                                [ viewMonthGrid lang page events ]
                            , div [ attribute "data-testid" "mobile-calendar", class "md:hidden" ]
                                [ viewMonthStrip lang page events
                                , viewAgenda lang page events
                                ]
                            ]
                    )

            ListView ->
                LoadState.view
                    { loadingLabel = t lang Loading
                    , errorMessage = Api.httpErrorToString lang
                    , onRetry = Just (CalendarSetMonth page.year page.month)
                    , retryLabel = t lang Retry
                    }
                    (fromRemoteData page.events)
                    (viewListView lang page)
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


touchStartDecoder : Decode.Decoder Msg
touchStartDecoder =
    Decode.at [ "touches", "length" ] Decode.int
        |> Decode.andThen
            (\len ->
                if len == 1 then
                    Decode.at [ "touches", "0" ]
                        (Decode.map2 CalendarTouchStart
                            (Decode.field "clientX" Decode.float)
                            (Decode.field "clientY" Decode.float)
                        )

                else
                    Decode.fail "Ignore multi-touch"
            )


touchEndDecoder : Decode.Decoder Msg
touchEndDecoder =
    Decode.at [ "touches", "length" ] Decode.int
        |> Decode.andThen
            (\len ->
                if len == 0 then
                    Decode.at [ "changedTouches", "0" ]
                        (Decode.map2 CalendarTouchEnd
                            (Decode.field "clientX" Decode.float)
                            (Decode.field "clientY" Decode.float)
                        )

                else
                    Decode.fail "Ignore multi-touch"
            )


onTouchStart : Html.Attribute Msg
onTouchStart =
    Html.Events.on "touchstart" touchStartDecoder


onTouchEnd : Html.Attribute Msg
onTouchEnd =
    Html.Events.on "touchend" touchEndDecoder


onTouchCancel : Html.Attribute Msg
onTouchCancel =
    Html.Events.on "touchcancel" (Decode.succeed CalendarTouchCancel)


viewCalendarNav : Lang -> CalendarPage -> Html Msg
viewCalendarNav lang page =
    let
        ( prevY, prevM ) =
            prevMonth page.year page.month

        ( nextY, nextM ) =
            nextMonth page.year page.month
    in
    div
        [ class "flex items-center gap-2 sm:gap-4 mb-4 flex-wrap touch-pan-y touch-pinch-zoom"
        , onTouchStart
        , onTouchEnd
        , onTouchCancel
        ]
        [ button
            [ type_ "button"
            , onClick (CalendarSetMonth prevY prevM)
            , class "h-8 w-8 inline-flex items-center justify-center border rounded hover:bg-bg-subtle focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand focus-visible:ring-offset-1"
            , attribute "aria-label" (t lang CalPrevMonth)
            ]
            [ featherIcon FeatherIcons.chevronLeft 16 ]
        , span [ class "type-h3 min-w-36 text-center" ]
            [ text (monthName (I18n.locale lang) page.month ++ " " ++ String.fromInt page.year) ]
        , button
            [ type_ "button"
            , onClick (CalendarSetMonth nextY nextM)
            , class "h-8 w-8 inline-flex items-center justify-center border rounded hover:bg-bg-subtle focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand focus-visible:ring-offset-1"
            , attribute "aria-label" (t lang CalNextMonth)
            ]
            [ featherIcon FeatherIcons.chevronRight 16 ]
        , button
            [ type_ "button"
            , onClick (CalendarSetMonth page.todayYear page.todayMonth)
            , class "h-8 px-2.5 inline-flex items-center justify-center type-body-small border rounded hover:bg-bg-subtle focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand focus-visible:ring-offset-1"
            ]
            [ text (t lang CalToday) ]
        ]


viewMonthGrid : Lang -> CalendarPage -> List Event -> Html Msg
viewMonthGrid lang page events =
    div []
        [ div [ class "grid grid-cols-7 text-center type-overline text-text-muted mb-1" ]
            (List.map (\d -> div [] [ text d ])
                [ "Ma", "Ti", "Ke", "To", "Pe", "La", "Su" ]
            )
        , div [ class "grid grid-cols-7 border-t border-l" ]
            (List.concatMap (List.map (viewDayCell lang page events))
                (monthGrid page.year page.month)
            )
        ]



-- SMALL SCREENS


{-| Compact month: day numbers only, with a bar under days that have events.
A multi-day event shows as one continuous bar across its days.
-}
viewMonthStrip : Lang -> CalendarPage -> List Event -> Html Msg
viewMonthStrip lang page events =
    div
        [ attribute "data-testid" "month-strip"
        , class "mb-6 touch-pan-y touch-pinch-zoom"
        , onTouchStart
        , onTouchEnd
        , onTouchCancel
        ]
        [ div
            [ class "grid grid-cols-7 text-center type-overline text-text-muted mb-1"
            , attribute "aria-hidden" "true"
            ]
            (List.map (\d -> div [] [ text d ])
                [ "Ma", "Ti", "Ke", "To", "Pe", "La", "Su" ]
            )
        , div [ class "grid grid-cols-7" ]
            (monthGrid page.year page.month
                |> List.filter (List.any ((/=) Nothing))
                |> List.concatMap (List.map (viewStripCell lang page events))
            )
        ]


viewStripCell : Lang -> CalendarPage -> List Event -> Maybe Int -> Html Msg
viewStripCell lang page events maybeDay =
    case maybeDay of
        Nothing ->
            div [] []

        Just day ->
            let
                mark =
                    CalendarAgenda.dayMark page.year page.month day events

                isToday =
                    page.year == page.todayYear && page.month == page.todayMonth && day == page.todayDay

                number =
                    span
                        [ class
                            (if isToday then
                                "type-body-small inline-flex items-center justify-center w-7 h-7 rounded-full bg-brand text-text-on-dark"

                             else
                                "type-body-small inline-flex items-center justify-center w-7 h-7"
                            )
                        ]
                        [ text (String.fromInt day) ]

                bar =
                    span
                        [ class
                            ("block h-1.5 mt-0.5 bg-brand-yellow border-y border-brand"
                                ++ (if mark.joinsPrev then
                                        ""

                                    else
                                        " ml-1.5 rounded-l-full border-l"
                                   )
                                ++ (if mark.joinsNext then
                                        ""

                                    else
                                        " mr-1.5 rounded-r-full border-r"
                                   )
                            )
                        ]
                        []
            in
            if mark.count == 0 then
                div [ class "h-12 pt-1 text-center text-text-muted" ] [ number ]

            else
                button
                    [ type_ "button"
                    , class "h-12 pt-1 text-center cursor-pointer hover:bg-bg-subtle focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand focus-visible:ring-inset"
                    , attribute "data-has-events" "true"
                    , attribute "aria-label" (I18n.dayLabel lang { day = day, month = page.month, count = mark.count })
                    , onClick (CalendarJumpToWeek (CalendarAgenda.weekNumberOf page.year page.month day))
                    ]
                    [ number, bar ]


{-| The month's events as full-width cards under week headings.
-}
viewAgenda : Lang -> CalendarPage -> List Event -> Html Msg
viewAgenda lang page events =
    case CalendarAgenda.agendaWeeks page.year page.month events of
        [] ->
            div [ class "text-text-muted text-center py-8" ] [ text (t lang CalNoEvents) ]

        weeks ->
            div [ class "flex flex-col gap-6" ] (List.map (viewAgendaWeek lang) weeks)


viewAgendaWeek : Lang -> AgendaWeek -> Html Msg
viewAgendaWeek lang week =
    section []
        [ h3
            [ id (CalendarAgenda.weekHeadingId week.weekNumber)
            , tabindex -1
            , class "type-overline text-text-muted mb-2 scroll-mt-4 focus:text-brand focus:outline-none focus-visible:ring-2 focus-visible:ring-brand focus-visible:ring-offset-2"
            ]
            [ text (CalendarAgenda.weekLabel lang week) ]
        , ul [ class "flex flex-col gap-2" ]
            (List.map (\event -> li [] [ viewAgendaEvent lang event ]) week.events)
        ]


viewAgendaEvent : Lang -> Event -> Html Msg
viewAgendaEvent lang event =
    button
        [ type_ "button"
        , class "block w-full text-left border border-border-default border-l-4 border-l-brand-yellow rounded p-3 cursor-pointer hover:bg-bg-subtle focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand focus-visible:ring-offset-2"
        , onClick (CalendarClickEvent event.id)
        ]
        [ span [ class "block type-caption text-text-muted" ] [ text (formatEventDateDisplay lang event) ]
        , span [ class "block type-h4" ] [ span (I18n.contentAttrs lang) [ text (Types.displayTitle (I18n.t lang I18n.CancelledPrefix) event) ] ]
        , case event.location of
            Nothing ->
                text ""

            Just loc ->
                span [ class "block type-caption text-text-muted" ] [ span (I18n.contentAttrs lang) [ text loc ] ]
        ]



-- MONTH GRID CELLS


viewDayCell : Lang -> CalendarPage -> List Event -> Maybe Int -> Html Msg
viewDayCell lang page events maybeDay =
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
                    ("border-r border-b min-h-24 relative overflow-hidden"
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
                    (List.take 3 (List.map (\ev -> viewEventChip lang (chipPos page.year page.month day ev) ev) dayEvents)
                        ++ (if List.length dayEvents > 3 then
                                [ div [ class "type-caption text-text-muted mx-1" ]
                                    [ text ("+" ++ String.fromInt (List.length dayEvents - 3) ++ t lang CalMore) ]
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


viewEventChip : Lang -> ChipPosition -> Event -> Html Msg
viewEventChip lang pos event =
    let
        shapeClass =
            case pos of
                ChipSingle ->
                    "mx-1 px-1"

                ChipStart ->
                    "ml-1 mr-0 pl-1"

                ChipMiddle ->
                    "mx-0 px-0"

                ChipEnd ->
                    "ml-0 mr-1 pr-1"

        label =
            case pos of
                ChipSingle ->
                    Types.displayTitle (I18n.t lang I18n.CancelledPrefix) event

                ChipStart ->
                    Types.displayTitle (I18n.t lang I18n.CancelledPrefix) event

                _ ->
                    "\u{00A0}"
    in
    div
        ([ classList
            [ ( "event-all-day", event.allDay )
            , ( "event-timed", not event.allDay )
            ]
         , class shapeClass
         , onClick (CalendarClickEvent event.id)
         , tabindex 0
         , attribute "role" "button"
         , attribute "title" (Types.displayTitle (I18n.t lang I18n.CancelledPrefix) event)
         , attribute "aria-label" (Types.displayTitle (I18n.t lang I18n.CancelledPrefix) event)
         ]
            ++ I18n.contentAttrs lang
        )
        [ text label ]


viewListView : Lang -> CalendarPage -> List Event -> Html Msg
viewListView lang page events =
    let
        monthEvents =
            List.filter (eventInMonth page.year page.month) events
    in
    if List.isEmpty monthEvents then
        div [ class "text-text-muted text-center py-8" ] [ text (t lang CalNoEvents) ]

    else
        div [ class "flex flex-col gap-4" ]
            (List.map (viewListEvent lang) monthEvents)


viewListEvent : Lang -> Event -> Html Msg
viewListEvent lang event =
    div
        [ class "border rounded p-3 cursor-pointer hover:bg-bg-subtle"
        , onClick (CalendarClickEvent event.id)
        ]
        [ p [ class "type-caption text-text-muted" ] [ text (formatEventDateDisplay lang event) ]
        , h3 [ class "type-h4" ] [ span (I18n.contentAttrs lang) [ text (Types.displayTitle (I18n.t lang I18n.CancelledPrefix) event) ] ]
        , case event.location of
            Nothing ->
                text ""

            Just loc ->
                p [ class "type-caption text-text-muted" ] [ span (I18n.contentAttrs lang) [ text loc ] ]
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
