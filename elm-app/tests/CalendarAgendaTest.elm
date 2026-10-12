module CalendarAgendaTest exposing (suite)

{-| Unit tests for the mobile calendar layout (CalendarAgenda) and its
rendering in View.Calendar.
-}

import CalendarAgenda exposing (agendaWeeks, dayMark, weekHeadingId, weekLabel, weekNumberOf)
import Expect
import Html.Attributes as Attr
import RemoteData
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import Types exposing (AuthState(..), CalendarPage, CalendarViewMode(..), Event, EventState(..), Msg(..))
import View.Calendar


{-| Build an all-day Event. Dates are Helsinki-local "YYYY-MM-DD"; October 2026
before the 25th is EEST (UTC+3), so local noon is 09:00Z.
-}
ev : String -> String -> Maybe String -> Event
ev title start end =
    { id = title
    , title = title
    , description = Nothing
    , startDate = start ++ "T09:00:00.000Z"
    , endDate = Maybe.map (\e -> e ++ "T09:00:00.000Z") end
    , allDay = True
    , url = Nothing
    , location = Nothing
    , state = Published
    , cancelled = False
    , image = Nothing
    , imageDescription = Nothing
    , point = Nothing
    , tags = []
    , created = ""
    , updated = ""
    }


october : List Event -> CalendarPage
october events =
    { events = RemoteData.Success events
    , year = 2026
    , month = 10
    , todayYear = 2026
    , todayMonth = 10
    , todayDay = 12
    , viewMode = MonthGrid
    }


weekend : Event
weekend =
    ev "Pii Poo" "2026-10-17" (Just "2026-10-18")


suite : Test
suite =
    describe "CalendarAgenda"
        [ describe "dayMark"
            [ test "a day without events has no mark" <|
                \_ ->
                    dayMark 2026 10 19 [ weekend ]
                        |> Expect.equal { count = 0, joinsPrev = False, joinsNext = False }
            , test "a single-day event marks only its day, unjoined" <|
                \_ ->
                    dayMark 2026 10 15 [ ev "Klotsi" "2026-10-15" Nothing ]
                        |> Expect.equal { count = 1, joinsPrev = False, joinsNext = False }
            , test "the first day of a multi-day event joins the next day" <|
                \_ ->
                    dayMark 2026 10 17 [ weekend ]
                        |> Expect.equal { count = 1, joinsPrev = False, joinsNext = True }
            , test "the last day of a multi-day event joins the previous day" <|
                \_ ->
                    dayMark 2026 10 18 [ weekend ]
                        |> Expect.equal { count = 1, joinsPrev = True, joinsNext = False }
            , test "a middle day joins both neighbours" <|
                \_ ->
                    dayMark 2026 10 24 [ ev "Game" "2026-10-23" (Just "2026-10-25") ]
                        |> Expect.equal { count = 1, joinsPrev = True, joinsNext = True }
            , test "separate events on adjacent days do not join" <|
                \_ ->
                    dayMark 2026 10 17 [ ev "A" "2026-10-17" Nothing, ev "B" "2026-10-18" Nothing ]
                        |> Expect.equal { count = 1, joinsPrev = False, joinsNext = False }
            , test "counts every event on the day" <|
                \_ ->
                    dayMark 2026 10 17 [ weekend, ev "LEGO" "2026-10-17" Nothing ]
                        |> .count
                        |> Expect.equal 2
            , test "a multi-day event joins across the month boundary" <|
                \_ ->
                    dayMark 2026 10 1 [ ev "Syys" "2026-09-28" (Just "2026-10-02") ]
                        |> Expect.equal { count = 1, joinsPrev = True, joinsNext = True }
            , test "places events by Helsinki date, not UTC date" <|
                \_ ->
                    -- 2026-10-16T21:00Z is 00:00 on the 17th in Helsinki (EEST).
                    let
                        late =
                            ev "Yö" "2026-10-17" Nothing
                                |> (\e -> { e | startDate = "2026-10-16T21:00:00.000Z" })
                    in
                    ( (dayMark 2026 10 16 [ late ]).count, (dayMark 2026 10 17 [ late ]).count )
                        |> Expect.equal ( 0, 1 )
            ]
        , describe "weekNumberOf"
            [ test "returns the ISO week number" <|
                \_ -> weekNumberOf 2026 10 12 |> Expect.equal 42
            , test "a Sunday belongs to the week of the preceding Monday" <|
                \_ -> weekNumberOf 2026 10 11 |> Expect.equal 41
            , test "early January can belong to the previous ISO year's last week" <|
                \_ -> weekNumberOf 2027 1 3 |> Expect.equal 53
            ]
        , describe "agendaWeeks"
            [ test "a month without events has no weeks" <|
                \_ -> agendaWeeks 2026 10 [] |> Expect.equal []
            , test "only weeks with events are listed, in order" <|
                \_ ->
                    agendaWeeks 2026 10 [ ev "Klotsi" "2026-10-15" Nothing, ev "Litua" "2026-10-10" (Just "2026-10-11") ]
                        |> List.map .weekNumber
                        |> Expect.equal [ 41, 42 ]
            , test "a week knows its Monday and Sunday" <|
                \_ ->
                    agendaWeeks 2026 10 [ weekend ]
                        |> List.map (\w -> ( w.monday, w.sunday ))
                        |> Expect.equal [ ( ( 2026, 10, 12 ), ( 2026, 10, 18 ) ) ]
            , test "events within a week are ordered by start" <|
                \_ ->
                    agendaWeeks 2026 10 [ weekend, ev "Klotsi" "2026-10-15" Nothing ]
                        |> List.concatMap .events
                        |> List.map .title
                        |> Expect.equal [ "Klotsi", "Pii Poo" ]
            , test "an event spanning two weeks is listed once, in the week it starts" <|
                \_ ->
                    agendaWeeks 2026 10 [ ev "Pitkä" "2026-10-16" (Just "2026-10-20") ]
                        |> List.map (\w -> ( w.weekNumber, List.map .title w.events ))
                        |> Expect.equal [ ( 42, [ "Pitkä" ] ) ]
            , test "events outside the month are left out" <|
                \_ ->
                    agendaWeeks 2026 10 [ ev "Marras" "2026-11-07" Nothing, ev "Syys" "2026-09-05" Nothing ]
                        |> Expect.equal []
            , test "an event continuing from the previous month is listed in the month's first week" <|
                \_ ->
                    -- Runs Mon 21.9.–Fri 2.10.; October's first week is week 40 (28.9.–4.10.).
                    agendaWeeks 2026 10 [ ev "Syys" "2026-09-21" (Just "2026-10-02") ]
                        |> List.map (\w -> ( w.weekNumber, List.map .title w.events ))
                        |> Expect.equal [ ( 40, [ "Syys" ] ) ]
            , test "an event is listed only in the months it touches, even when its week straddles two" <|
                \_ ->
                    let
                        e =
                            ev "Vaihde" "2026-09-30" Nothing
                    in
                    ( List.map .weekNumber (agendaWeeks 2026 9 [ e ]), List.map .weekNumber (agendaWeeks 2026 10 [ e ]) )
                        |> Expect.equal ( [ 40 ], [] )
            ]
        , describe "weekLabel"
            [ test "shows the week number and its date range" <|
                \_ ->
                    agendaWeeks 2026 10 [ weekend ]
                        |> List.map weekLabel
                        |> Expect.equal [ "Viikko 42 · 12.–18.10." ]
            , test "shows both months when the week straddles a month boundary" <|
                \_ ->
                    agendaWeeks 2026 10 [ ev "Alku" "2026-10-01" Nothing ]
                        |> List.map weekLabel
                        |> Expect.equal [ "Viikko 40 · 28.9.–4.10." ]
            ]
        , describe "weekHeadingId"
            [ test "is a stable DOM id per week" <|
                \_ -> weekHeadingId 42 |> Expect.equal "agenda-week-42"
            ]
        , describe "View.Calendar on small screens"
            [ test "the month grid is hidden below md" <|
                \_ ->
                    View.Calendar.view NotAuthenticated (october [ weekend ])
                        |> Query.fromHtml
                        |> Query.find [ Selector.attribute (Attr.attribute "data-testid" "month-grid") ]
                        |> Query.has [ Selector.classes [ "hidden", "md:block" ] ]
            , test "the mobile view is hidden from md up" <|
                \_ ->
                    View.Calendar.view NotAuthenticated (october [ weekend ])
                        |> Query.fromHtml
                        |> Query.find [ Selector.attribute (Attr.attribute "data-testid" "mobile-calendar") ]
                        |> Query.has [ Selector.class "md:hidden" ]
            , test "the agenda lists the event under its week heading with full title and dates" <|
                \_ ->
                    View.Calendar.view NotAuthenticated (october [ weekend ])
                        |> Query.fromHtml
                        |> Query.find [ Selector.attribute (Attr.attribute "data-testid" "mobile-calendar") ]
                        |> Query.has
                            [ Selector.text "Viikko 42 · 12.–18.10."
                            , Selector.text "Pii Poo"
                            , Selector.text "la–su 17.–18.10."
                            ]
            , test "the week heading can receive focus for jump-to-week" <|
                \_ ->
                    View.Calendar.view NotAuthenticated (october [ weekend ])
                        |> Query.fromHtml
                        |> Query.find [ Selector.id "agenda-week-42" ]
                        |> Query.has [ Selector.attribute (Attr.tabindex -1) ]
            , test "the month strip marks event days and leaves other days plain" <|
                \_ ->
                    View.Calendar.view NotAuthenticated (october [ weekend ])
                        |> Query.fromHtml
                        |> Query.find [ Selector.attribute (Attr.attribute "data-testid" "month-strip") ]
                        |> Query.findAll [ Selector.attribute (Attr.attribute "data-has-events" "true") ]
                        |> Query.count (Expect.equal 2)
            , test "an event day in the strip is a button naming the day and its event count" <|
                \_ ->
                    View.Calendar.view NotAuthenticated (october [ weekend ])
                        |> Query.fromHtml
                        |> Query.find [ Selector.attribute (Attr.attribute "data-testid" "month-strip") ]
                        |> Query.findAll [ Selector.tag "button", Selector.attribute (Attr.attribute "aria-label" "17. lokakuuta, 1 tapahtuma") ]
                        |> Query.count (Expect.equal 1)
            , test "tapping an event day jumps to its week in the agenda" <|
                \_ ->
                    View.Calendar.view NotAuthenticated (october [ weekend ])
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "button", Selector.attribute (Attr.attribute "aria-label" "17. lokakuuta, 1 tapahtuma") ]
                        |> Event.simulate Event.click
                        |> Event.expect (CalendarJumpToWeek 42)
            , test "tapping an agenda card opens the event" <|
                \_ ->
                    View.Calendar.view NotAuthenticated (october [ weekend ])
                        |> Query.fromHtml
                        |> Query.find [ Selector.attribute (Attr.attribute "data-testid" "mobile-calendar") ]
                        |> Query.find [ Selector.tag "button", Selector.containing [ Selector.text "Pii Poo" ] ]
                        |> Event.simulate Event.click
                        |> Event.expect (CalendarClickEvent "Pii Poo")
            , test "a month without events says so in the mobile view" <|
                \_ ->
                    View.Calendar.view NotAuthenticated (october [])
                        |> Query.fromHtml
                        |> Query.find [ Selector.attribute (Attr.attribute "data-testid" "mobile-calendar") ]
                        |> Query.has [ Selector.text "Ei tapahtumia tällä kuulla" ]
            ]
        ]
