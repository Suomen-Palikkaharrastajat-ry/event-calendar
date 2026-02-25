module DateUtilsTest exposing (suite)

import DateUtils exposing (..)
import Expect
import Test exposing (Test, describe, test)
import Time


posixFromStr : String -> Time.Posix
posixFromStr s =
    -- Hardcoded POSIX millis for test dates
    case s of
        "2025-06-15T12:00:00Z" ->
            Time.millisToPosix 1750082400000

        "2025-01-15T12:00:00Z" ->
            Time.millisToPosix 1736942400000

        "2025-03-30T00:30:00Z" ->
            -- Just after DST start (last Sunday of March 2025 is March 30, 01:00 UTC)
            Time.millisToPosix 1743295800000

        _ ->
            Time.millisToPosix 0


suite : Test
suite =
    describe "DateUtils"
        [ describe "isDst"
            [ test "summer date is DST" <|
                \_ ->
                    isDst (posixFromStr "2025-06-15T12:00:00Z")
                        |> Expect.equal True
            , test "winter date is not DST" <|
                \_ ->
                    isDst (posixFromStr "2025-01-15T12:00:00Z")
                        |> Expect.equal False
            ]
        , describe "helsinkiOffset"
            [ test "summer offset is 180" <|
                \_ ->
                    helsinkiOffset (posixFromStr "2025-06-15T12:00:00Z")
                        |> Expect.equal 180
            , test "winter offset is 120" <|
                \_ ->
                    helsinkiOffset (posixFromStr "2025-01-15T12:00:00Z")
                        |> Expect.equal 120
            ]
        , describe "daysInMonth"
            [ test "February 2024 (leap) = 29" <|
                \_ -> daysInMonth 2024 2 |> Expect.equal 29
            , test "February 2025 = 28" <|
                \_ -> daysInMonth 2025 2 |> Expect.equal 28
            , test "January = 31" <|
                \_ -> daysInMonth 2025 1 |> Expect.equal 31
            , test "April = 30" <|
                \_ -> daysInMonth 2025 4 |> Expect.equal 30
            ]
        , describe "prevMonth / nextMonth"
            [ test "prevMonth Jan → Dec of prev year" <|
                \_ -> prevMonth 2025 1 |> Expect.equal ( 2024, 12 )
            , test "nextMonth Dec → Jan of next year" <|
                \_ -> nextMonth 2025 12 |> Expect.equal ( 2026, 1 )
            , test "nextMonth May → June" <|
                \_ -> nextMonth 2025 5 |> Expect.equal ( 2025, 6 )
            ]
        , describe "monthGrid"
            [ test "monthGrid produces 6 rows" <|
                \_ ->
                    monthGrid 2025 5
                        |> List.length
                        |> Expect.equal 6
            , test "each row has 7 days" <|
                \_ ->
                    monthGrid 2025 5
                        |> List.all (\row -> List.length row == 7)
                        |> Expect.equal True
            ]
        , describe "finnishMonthName"
            [ test "January" <|
                \_ -> finnishMonthName 1 |> Expect.equal "Tammikuu"
            , test "December" <|
                \_ -> finnishMonthName 12 |> Expect.equal "Joulukuu"
            ]
        ]
