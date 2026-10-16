module CalendarTest exposing (suite)

{-| Unit tests for the Calendar module.
-}

import DateUtils exposing (formatEventDateDisplay)
import Expect
import FinnishTime exposing (firstDayOfWeek, formDateTimeToUtc, utcStringToHelsinkiDateInput, utcStringToHelsinkiTimeInput)
import Lang
import Page.Calendar as PageCalendar
import RemoteData
import Route exposing (toHref)
import Test exposing (Test, describe, test)
import Time
import Types exposing (CalendarPage, CalendarViewMode(..), Event, EventState(..), Msg(..))
import View.EventDetail as EventDetail


{-| Build a minimal Event record for testing formatEventDateDisplay.
-}
makeEvent :
    { start : String
    , end : Maybe String
    , allDay : Bool
    }
    -> Event
makeEvent { start, end, allDay } =
    { id = "test"
    , title = "Test Event"
    , description = Nothing
    , startDate = start
    , endDate = end
    , allDay = allDay
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


suite : Test
suite =
    describe "Calendar"
        [ describe "formatEventDateDisplay"
            [ test "timed same-day: shows weekday, date, and time range" <|
                \_ ->
                    -- 2026-05-05T11:00Z → 14:00 Helsinki (EEST=UTC+3), Tuesday
                    -- 2026-05-05T14:00Z → 17:00 Helsinki
                    makeEvent
                        { start = "2026-05-05T11:00:00.000Z"
                        , end = Just "2026-05-05T14:00:00.000Z"
                        , allDay = False
                        }
                        |> formatEventDateDisplay Lang.Fi
                        |> Expect.equal "ti 5.5. klo 14.00–17.00"
            , test "timed same-day in English" <|
                \_ ->
                    makeEvent
                        { start = "2026-05-05T11:00:00.000Z"
                        , end = Just "2026-05-05T14:00:00.000Z"
                        , allDay = False
                        }
                        |> formatEventDateDisplay Lang.En
                        |> Expect.equal "Tue 5/5 at 14:00–17:00"
            , test "all-day single (no end): shows weekday and date" <|
                \_ ->
                    -- 2026-06-15T21:00Z → June 16 00:00 Helsinki (EEST), Tuesday
                    makeEvent
                        { start = "2026-06-15T21:00:00.000Z"
                        , end = Nothing
                        , allDay = True
                        }
                        |> formatEventDateDisplay Lang.Fi
                        |> Expect.equal "ti 16.6."
            , test "all-day cross-month range: shows D.M.–D.M." <|
                \_ ->
                    -- 2026-04-29T21:00Z = Apr 30 Helsinki, 2026-05-01T21:00Z = May 2 Helsinki
                    makeEvent
                        { start = "2026-04-29T21:00:00.000Z"
                        , end = Just "2026-05-01T21:00:00.000Z"
                        , allDay = True
                        }
                        |> formatEventDateDisplay Lang.Fi
                        |> Expect.equal "30.4.–2.5."
            , test "all-day same-month range: shows day range with weekdays" <|
                \_ ->
                    -- 2026-05-04T21:00Z = May 5 Helsinki (ti), 2026-05-05T21:00Z = May 6 Helsinki (ke)
                    makeEvent
                        { start = "2026-05-04T21:00:00.000Z"
                        , end = Just "2026-05-05T21:00:00.000Z"
                        , allDay = True
                        }
                        |> formatEventDateDisplay Lang.Fi
                        |> Expect.equal "ti–ke 5.–6.5."
            , test "timed no end: shows weekday, date, and start time" <|
                \_ ->
                    -- 2026-05-05T11:00Z → 14:00 Helsinki
                    makeEvent
                        { start = "2026-05-05T11:00:00.000Z"
                        , end = Nothing
                        , allDay = False
                        }
                        |> formatEventDateDisplay Lang.Fi
                        |> Expect.equal "ti 5.5. klo 14.00"
            , test "invalid date string falls through to raw string" <|
                \_ ->
                    makeEvent
                        { start = "not-a-date"
                        , end = Nothing
                        , allDay = False
                        }
                        |> formatEventDateDisplay Lang.Fi
                        |> Expect.equal "not-a-date"
            ]
        , describe "utcStringToHelsinkiDateInput"
            [ test "converts UTC to Helsinki date (EEST summer)" <|
                \_ ->
                    -- 2026-05-05T11:00:00Z = 14:00 in Helsinki → date 2026-05-05
                    utcStringToHelsinkiDateInput "2026-05-05T11:00:00.000Z"
                        |> Expect.equal "2026-05-05"
            , test "converts UTC to Helsinki date crossing midnight" <|
                \_ ->
                    -- 2026-06-15T21:00:00Z = June 16 00:00 Helsinki
                    utcStringToHelsinkiDateInput "2026-06-15T21:00:00.000Z"
                        |> Expect.equal "2026-06-16"
            , test "returns empty for invalid string" <|
                \_ ->
                    utcStringToHelsinkiDateInput "not-a-date"
                        |> Expect.equal ""
            ]
        , describe "calendar date query"
            [ test "valid full date opens that month" <|
                \_ ->
                    PageCalendar.dateQueryToYearMonth (Time.millisToPosix 0) (Just "2026-05-05")
                        |> Expect.equal ( 2026, 5 )
            , test "year-month without day falls back to current Helsinki month" <|
                \_ ->
                    PageCalendar.dateQueryToYearMonth (Time.millisToPosix 0) (Just "2026-05")
                        |> Expect.equal ( 1970, 1 )
            , test "invalid date falls back to current Helsinki month" <|
                \_ ->
                    PageCalendar.dateQueryToYearMonth (Time.millisToPosix 0) (Just "bad-date")
                        |> Expect.equal ( 1970, 1 )
            ]
        , describe "event detail calendar back link"
            [ test "uses Helsinki-local start date" <|
                \_ ->
                    makeEvent
                        { start = "2026-06-15T21:00:00.000Z"
                        , end = Nothing
                        , allDay = True
                        }
                        |> EventDetail.eventCalendarRoute
                        |> toHref
                        |> Expect.equal "#/?date=2026-06-16"
            ]
        , describe "utcStringToHelsinkiTimeInput"
            [ test "converts UTC to Helsinki time (EEST = UTC+3)" <|
                \_ ->
                    -- 2026-05-05T11:00:00Z = 14:00 Helsinki
                    utcStringToHelsinkiTimeInput "2026-05-05T11:00:00.000Z"
                        |> Expect.equal "14:00"
            , test "converts UTC to Helsinki time (EET = UTC+2, winter)" <|
                \_ ->
                    -- 2026-01-15T10:00:00Z = 12:00 Helsinki (EET)
                    utcStringToHelsinkiTimeInput "2026-01-15T10:00:00.000Z"
                        |> Expect.equal "12:00"
            ]
        , describe "firstDayOfWeek"
            [ test "2026-01 starts on Thursday (3, Mon=0)" <|
                \_ ->
                    -- Jan 1, 2026 is a Thursday
                    firstDayOfWeek 2026 1
                        |> Expect.equal 3
            , test "2026-05 starts on Friday (4, Mon=0)" <|
                \_ ->
                    -- May 1, 2026 is a Friday
                    firstDayOfWeek 2026 5
                        |> Expect.equal 4
            , test "2025-01 starts on Wednesday (2, Mon=0)" <|
                \_ ->
                    -- Jan 1, 2025 is a Wednesday
                    firstDayOfWeek 2025 1
                        |> Expect.equal 2
            ]
        , describe "formDateTimeToUtc"
            [ test "all-day (summer EEST UTC+3): Helsinki midnight → UTC-3h" <|
                \_ ->
                    -- 2026-05-05 00:00 EEST = 2026-05-04 21:00 UTC
                    formDateTimeToUtc "2026-05-05" "00:00" True
                        |> Expect.equal (Just "2026-05-04T21:00:00.000Z")
            , test "timed (summer EEST UTC+3): Helsinki 14:00 → UTC-3h" <|
                \_ ->
                    -- 2026-05-05 14:00 EEST = 2026-05-05 11:00 UTC
                    formDateTimeToUtc "2026-05-05" "14:00" False
                        |> Expect.equal (Just "2026-05-05T11:00:00.000Z")
            , test "all-day (winter EET UTC+2): Helsinki midnight → UTC-2h" <|
                \_ ->
                    -- 2026-02-25 00:00 EET = 2026-02-24 22:00 UTC
                    formDateTimeToUtc "2026-02-25" "00:00" True
                        |> Expect.equal (Just "2026-02-24T22:00:00.000Z")
            , test "timed (winter EET UTC+2): Helsinki 10:00 → UTC-2h" <|
                \_ ->
                    -- 2026-02-25 10:00 EET = 2026-02-25 08:00 UTC
                    formDateTimeToUtc "2026-02-25" "10:00" False
                        |> Expect.equal (Just "2026-02-25T08:00:00.000Z")
            , test "invalid date returns Nothing" <|
                \_ ->
                    formDateTimeToUtc "bad-date" "10:00" False
                        |> Expect.equal Nothing
            ]
        , describe "swipe support"
            [ test "swipe left navigates to next month" <|
                \_ ->
                    let
                        initialPage : CalendarPage
                        initialPage =
                            { events = RemoteData.NotAsked
                            , year = 2026
                            , month = 10
                            , todayYear = 2026
                            , todayMonth = 10
                            , todayDay = 16
                            , viewMode = MonthGrid
                            , touchStart = Nothing
                            }

                        ( pageWithTouch, _ ) =
                            PageCalendar.update (CalendarTouchStart 200 100) initialPage

                        ( finalPage, _ ) =
                            PageCalendar.update (CalendarTouchEnd 100 105) pageWithTouch
                    in
                    Expect.equal ( finalPage.year, finalPage.month, finalPage.touchStart )
                        ( 2026, 11, Nothing )
            , test "swipe right navigates to previous month" <|
                \_ ->
                    let
                        initialPage : CalendarPage
                        initialPage =
                            { events = RemoteData.NotAsked
                            , year = 2026
                            , month = 10
                            , todayYear = 2026
                            , todayMonth = 10
                            , todayDay = 16
                            , viewMode = MonthGrid
                            , touchStart = Nothing
                            }

                        ( pageWithTouch, _ ) =
                            PageCalendar.update (CalendarTouchStart 100 100) initialPage

                        ( finalPage, _ ) =
                            PageCalendar.update (CalendarTouchEnd 200 95) pageWithTouch
                    in
                    Expect.equal ( finalPage.year, finalPage.month, finalPage.touchStart )
                        ( 2026, 9, Nothing )
            , test "vertical scroll does not trigger month change" <|
                \_ ->
                    let
                        initialPage : CalendarPage
                        initialPage =
                            { events = RemoteData.NotAsked
                            , year = 2026
                            , month = 10
                            , todayYear = 2026
                            , todayMonth = 10
                            , todayDay = 16
                            , viewMode = MonthGrid
                            , touchStart = Nothing
                            }

                        ( pageWithTouch, _ ) =
                            PageCalendar.update (CalendarTouchStart 100 200) initialPage

                        ( finalPage, _ ) =
                            PageCalendar.update (CalendarTouchEnd 80 50) pageWithTouch
                    in
                    Expect.equal ( finalPage.year, finalPage.month )
                        ( 2026, 10 )
            , test "short tap does not trigger month change" <|
                \_ ->
                    let
                        initialPage : CalendarPage
                        initialPage =
                            { events = RemoteData.NotAsked
                            , year = 2026
                            , month = 10
                            , todayYear = 2026
                            , todayMonth = 10
                            , todayDay = 16
                            , viewMode = MonthGrid
                            , touchStart = Nothing
                            }

                        ( pageWithTouch, _ ) =
                            PageCalendar.update (CalendarTouchStart 100 100) initialPage

                        ( finalPage, _ ) =
                            PageCalendar.update (CalendarTouchEnd 105 102) pageWithTouch
                    in
                    Expect.equal ( finalPage.year, finalPage.month )
                        ( 2026, 10 )
            , test "touch cancel resets touchStart" <|
                \_ ->
                    let
                        initialPage : CalendarPage
                        initialPage =
                            { events = RemoteData.NotAsked
                            , year = 2026
                            , month = 10
                            , todayYear = 2026
                            , todayMonth = 10
                            , todayDay = 16
                            , viewMode = MonthGrid
                            , touchStart = Nothing
                            }

                        ( pageWithTouch, _ ) =
                            PageCalendar.update (CalendarTouchStart 100 100) initialPage

                        ( finalPage, _ ) =
                            PageCalendar.update CalendarTouchCancel pageWithTouch
                    in
                    Expect.equal finalPage.touchStart Nothing
            , test "swipe left in December rolls over to January next year" <|
                \_ ->
                    let
                        decemberPage : CalendarPage
                        decemberPage =
                            { events = RemoteData.NotAsked
                            , year = 2026
                            , month = 12
                            , todayYear = 2026
                            , todayMonth = 10
                            , todayDay = 16
                            , viewMode = MonthGrid
                            , touchStart = Nothing
                            }

                        ( pageWithTouch, _ ) =
                            PageCalendar.update (CalendarTouchStart 200 100) decemberPage

                        ( finalPage, _ ) =
                            PageCalendar.update (CalendarTouchEnd 100 100) pageWithTouch
                    in
                    Expect.equal ( finalPage.year, finalPage.month )
                        ( 2027, 1 )
            , test "swipe right in January rolls back to December previous year" <|
                \_ ->
                    let
                        januaryPage : CalendarPage
                        januaryPage =
                            { events = RemoteData.NotAsked
                            , year = 2026
                            , month = 1
                            , todayYear = 2026
                            , todayMonth = 10
                            , todayDay = 16
                            , viewMode = MonthGrid
                            , touchStart = Nothing
                            }

                        ( pageWithTouch, _ ) =
                            PageCalendar.update (CalendarTouchStart 100 100) januaryPage

                        ( finalPage, _ ) =
                            PageCalendar.update (CalendarTouchEnd 200 100) pageWithTouch
                    in
                    Expect.equal ( finalPage.year, finalPage.month )
                        ( 2025, 12 )
            , test "CalendarTouchEnd with no touchStart does nothing" <|
                \_ ->
                    let
                        initialPage : CalendarPage
                        initialPage =
                            { events = RemoteData.NotAsked
                            , year = 2026
                            , month = 10
                            , todayYear = 2026
                            , todayMonth = 10
                            , todayDay = 16
                            , viewMode = MonthGrid
                            , touchStart = Nothing
                            }

                        ( finalPage, _ ) =
                            PageCalendar.update (CalendarTouchEnd 100 100) initialPage
                    in
                    Expect.equal ( finalPage.year, finalPage.month, finalPage.touchStart )
                        ( 2026, 10, Nothing )
            , test "CalendarSetMonth clears touchStart" <|
                \_ ->
                    let
                        initialPage : CalendarPage
                        initialPage =
                            { events = RemoteData.NotAsked
                            , year = 2026
                            , month = 10
                            , todayYear = 2026
                            , todayMonth = 10
                            , todayDay = 16
                            , viewMode = MonthGrid
                            , touchStart = Just ( 100, 100 )
                            }

                        ( finalPage, _ ) =
                            PageCalendar.update (CalendarSetMonth 2026 11) initialPage
                    in
                    Expect.equal finalPage.touchStart Nothing
            , test "yearMonthToDateQuery formats canonical YYYY-MM-01 query string" <|
                \_ ->
                    PageCalendar.yearMonthToDateQuery 2026 5
                        |> Expect.equal "2026-05-01"
            ]
        ]
