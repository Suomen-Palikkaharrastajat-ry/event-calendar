module CalendarTest exposing (suite)

import DateUtils exposing (..)
import Expect
import Test exposing (Test, describe, test)
import Time
import Types exposing (Event, EventState(..))


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
    , image = Nothing
    , imageDescription = Nothing
    , point = Nothing
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
                        |> formatEventDateDisplay
                        |> Expect.equal "ti 5.5. klo 14.00–17.00"
            , test "all-day single (no end): shows weekday and date" <|
                \_ ->
                    -- 2026-06-15T21:00Z → June 16 00:00 Helsinki (EEST), Tuesday
                    makeEvent
                        { start = "2026-06-15T21:00:00.000Z"
                        , end = Nothing
                        , allDay = True
                        }
                        |> formatEventDateDisplay
                        |> Expect.equal "ti 16.6."
            , test "all-day cross-month range: shows D.M.–D.M." <|
                \_ ->
                    -- 2026-04-29T21:00Z = Apr 30 Helsinki, 2026-05-01T21:00Z = May 2 Helsinki
                    makeEvent
                        { start = "2026-04-29T21:00:00.000Z"
                        , end = Just "2026-05-01T21:00:00.000Z"
                        , allDay = True
                        }
                        |> formatEventDateDisplay
                        |> Expect.equal "30.4.–2.5."
            , test "all-day same-month range: shows day range with weekdays" <|
                \_ ->
                    -- 2026-05-04T21:00Z = May 5 Helsinki (ti), 2026-05-05T21:00Z = May 6 Helsinki (ke)
                    makeEvent
                        { start = "2026-05-04T21:00:00.000Z"
                        , end = Just "2026-05-05T21:00:00.000Z"
                        , allDay = True
                        }
                        |> formatEventDateDisplay
                        |> Expect.equal "ti–ke 5.–6.5."
            , test "timed no end: shows weekday, date, and start time" <|
                \_ ->
                    -- 2026-05-05T11:00Z → 14:00 Helsinki
                    makeEvent
                        { start = "2026-05-05T11:00:00.000Z"
                        , end = Nothing
                        , allDay = False
                        }
                        |> formatEventDateDisplay
                        |> Expect.equal "ti 5.5. klo 14.00"
            , test "invalid date string falls through to raw string" <|
                \_ ->
                    makeEvent
                        { start = "not-a-date"
                        , end = Nothing
                        , allDay = False
                        }
                        |> formatEventDateDisplay
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
        ]
