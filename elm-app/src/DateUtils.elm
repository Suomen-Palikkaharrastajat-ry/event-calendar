module DateUtils exposing
    ( helsinkiOffset
    , isDst
    , toHelsinkiParts
    , parseUtcString
    , formatShortDate
    , formatTime
    , formatFullDate
    , formatEventDateDisplay
    , formDateTimeToUtc
    , utcStringToHelsinkiDateInput
    , utcStringToHelsinkiTimeInput
    , finnishWeekdayAbbr
    , finnishMonthName
    , daysInMonth
    , firstDayOfWeek
    , monthGrid
    , prevMonth
    , nextMonth
    )

import Iso8601
import Time exposing (Month(..), Posix, Weekday(..), Zone)
import Types exposing (Event)


-- HELSINKI TIMEZONE


{-| Helsinki timezone offset in minutes from UTC.
EET (UTC+2) in winter = 120 minutes.
EEST (UTC+3) in summer = 180 minutes.
-}
helsinkiOffset : Posix -> Int
helsinkiOffset posix =
    if isDst posix then
        180

    else
        120


{-| Is this UTC time within Helsinki DST (EEST, UTC+3)?
DST: last Sunday of March 01:00 UTC → last Sunday of October 01:00 UTC.
-}
isDst : Posix -> Bool
isDst posix =
    let
        year =
            Time.toYear Time.utc posix

        dstStart =
            lastSundayOfAt year 3 1

        dstEnd =
            lastSundayOfAt year 10 1
    in
    Time.posixToMillis posix >= Time.posixToMillis dstStart
        && Time.posixToMillis posix < Time.posixToMillis dstEnd


{-| Milliseconds timestamp of the last Sunday of month at the given UTC hour. -}
lastSundayOfAt : Int -> Int -> Int -> Posix
lastSundayOfAt year month hourUtc =
    let
        days =
            daysInMonth year month

        -- Find the last day of month, then walk back to Sunday
        lastDayMs =
            dateToMillis year month days 0 0

        lastDayWeekday =
            Time.toWeekday Time.utc (Time.millisToPosix lastDayMs)

        daysBack =
            weekdayToMondayOffset lastDayWeekday
                -- We want Sunday (6 days after Monday, or 0 if already Sunday)
                |> (\offset ->
                        if offset == 0 then
                            0

                        else
                            offset
                   )
        -- Actually: find how many days back to last Sunday
        sundayBack =
            case lastDayWeekday of
                Sun -> 0
                Mon -> 1
                Tue -> 2
                Wed -> 3
                Thu -> 4
                Fri -> 5
                Sat -> 6
    in
    Time.millisToPosix (lastDayMs - sundayBack * 86400000 + hourUtc * 3600000)


weekdayToMondayOffset : Weekday -> Int
weekdayToMondayOffset w =
    case w of
        Mon -> 0
        Tue -> 1
        Wed -> 2
        Thu -> 3
        Fri -> 4
        Sat -> 5
        Sun -> 6


{-| Convert year/month/day/hour/minute to UTC milliseconds.
Assumes the date is in UTC (no timezone conversion).
-}
dateToMillis : Int -> Int -> Int -> Int -> Int -> Int
dateToMillis year month day hour minute =
    let
        -- Days from epoch (1970-01-01) to start of year
        yearDays =
            List.sum
                (List.map
                    (\y ->
                        if isLeapYear y then
                            366

                        else
                            365
                    )
                    (List.range 1970 (year - 1))
                )

        -- Days from start of year to start of month
        monthDays =
            List.sum
                (List.map
                    (\m -> daysInMonth year m)
                    (List.range 1 (month - 1))
                )

        totalDays =
            yearDays + monthDays + day - 1
    in
    totalDays * 86400000 + hour * 3600000 + minute * 60000


isLeapYear : Int -> Bool
isLeapYear y =
    (modBy 4 y == 0 && modBy 100 y /= 0) || modBy 400 y == 0


{-| Helsinki timezone as a Time.Zone for a given Posix instant. -}
helsinkiZone : Posix -> Zone
helsinkiZone posix =
    Time.customZone (helsinkiOffset posix) []


-- DATE PARTS


type alias DateParts =
    { year : Int
    , month : Int
    , day : Int
    , hour : Int
    , minute : Int
    , weekday : Weekday
    }


{-| Extract Helsinki-local date/time parts from a UTC Posix. -}
toHelsinkiParts : Posix -> DateParts
toHelsinkiParts posix =
    let
        zone =
            helsinkiZone posix
    in
    { year = Time.toYear zone posix
    , month = monthToInt (Time.toMonth zone posix)
    , day = Time.toDay zone posix
    , hour = Time.toHour zone posix
    , minute = Time.toMinute zone posix
    , weekday = Time.toWeekday zone posix
    }


monthToInt : Month -> Int
monthToInt m =
    case m of
        Jan -> 1
        Feb -> 2
        Mar -> 3
        Apr -> 4
        May -> 5
        Jun -> 6
        Jul -> 7
        Aug -> 8
        Sep -> 9
        Oct -> 10
        Nov -> 11
        Dec -> 12


-- PARSING


{-| Parse a UTC ISO 8601 string to a Posix time. -}
parseUtcString : String -> Maybe Posix
parseUtcString s =
    -- PocketBase returns dates with a space separator ("2025-05-05 14:00:00.000Z").
    -- Iso8601.toTime requires the "T" separator, so normalize first.
    case Iso8601.toTime (String.replace " " "T" s) of
        Ok posix ->
            Just posix

        Err _ ->
            Nothing


-- FORMATTING


finnishWeekdayAbbr : Weekday -> String
finnishWeekdayAbbr w =
    case w of
        Mon -> "ma"
        Tue -> "ti"
        Wed -> "ke"
        Thu -> "to"
        Fri -> "pe"
        Sat -> "la"
        Sun -> "su"


finnishMonthName : Int -> String
finnishMonthName m =
    Maybe.withDefault "" <|
        List.head <|
            List.drop (m - 1)
                [ "Tammikuu", "Helmikuu", "Maaliskuu", "Huhtikuu"
                , "Toukokuu", "Kesäkuu", "Heinäkuu", "Elokuu"
                , "Syyskuu", "Lokakuu", "Marraskuu", "Joulukuu"
                ]


{-| Format a Posix as "D.M." in Helsinki time. -}
formatShortDate : Posix -> String
formatShortDate posix =
    let
        parts =
            toHelsinkiParts posix
    in
    String.fromInt parts.day ++ "." ++ String.fromInt parts.month ++ "."


{-| Format a Posix as "H.MM" (Finnish time, dot separator) in Helsinki time. -}
formatTime : Posix -> String
formatTime posix =
    let
        parts =
            toHelsinkiParts posix

        paddedMin =
            if parts.minute < 10 then
                "0" ++ String.fromInt parts.minute

            else
                String.fromInt parts.minute
    in
    String.fromInt parts.hour ++ "." ++ paddedMin


{-| Format a Posix as "ma 5.5.2025" in Helsinki time. -}
formatFullDate : Posix -> String
formatFullDate posix =
    let
        parts =
            toHelsinkiParts posix
    in
    finnishWeekdayAbbr parts.weekday
        ++ " "
        ++ String.fromInt parts.day
        ++ "."
        ++ String.fromInt parts.month
        ++ "."
        ++ String.fromInt parts.year


{-| Format an event's date/time for display. Implements the 6 format variants. -}
formatEventDateDisplay : Event -> String
formatEventDateDisplay event =
    case parseUtcString event.startDate of
        Nothing ->
            event.startDate

        Just startPosix ->
            let
                start =
                    toHelsinkiParts startPosix

                allDay =
                    event.allDay
            in
            case event.endDate |> Maybe.andThen parseUtcString of
                Nothing ->
                    if allDay then
                        finnishWeekdayAbbr start.weekday ++ " " ++ formatShortDate startPosix

                    else
                        finnishWeekdayAbbr start.weekday
                            ++ " "
                            ++ formatShortDate startPosix
                            ++ " klo "
                            ++ formatTime startPosix

                Just endPosix ->
                    let
                        end =
                            toHelsinkiParts endPosix

                        sameDay =
                            start.year == end.year && start.month == end.month && start.day == end.day

                        sameMonth =
                            start.year == end.year && start.month == end.month
                    in
                    if allDay then
                        if sameDay then
                            finnishWeekdayAbbr start.weekday ++ " " ++ formatShortDate startPosix

                        else if sameMonth then
                            finnishWeekdayAbbr start.weekday
                                ++ "–"
                                ++ finnishWeekdayAbbr end.weekday
                                ++ " "
                                ++ String.fromInt start.day
                                ++ ".–"
                                ++ formatShortDate endPosix

                        else
                            formatShortDate startPosix ++ "–" ++ formatShortDate endPosix

                    else if sameDay then
                        finnishWeekdayAbbr start.weekday
                            ++ " "
                            ++ formatShortDate startPosix
                            ++ " klo "
                            ++ formatTime startPosix
                            ++ "–"
                            ++ formatTime endPosix

                    else
                        formatShortDate startPosix
                            ++ " "
                            ++ formatTime startPosix
                            ++ "–"
                            ++ formatShortDate endPosix
                            ++ " "
                            ++ formatTime endPosix


{-| Convert Helsinki-local date/time input strings to a UTC ISO 8601 string.
Returns Nothing if the date string is malformed.

Properly converts from Europe/Helsinki (EET/EEST) to UTC using a two-pass
approach: estimate UTC with EET offset, check DST at that UTC time, then
subtract the correct offset (120 min EET or 180 min EEST).
-}
formDateTimeToUtc : String -> String -> Bool -> Maybe String
formDateTimeToUtc dateStr timeStr allDay =
    case String.split "-" dateStr of
        [ yearS, monthS, dayS ] ->
            case ( String.toInt yearS, String.toInt monthS, String.toInt dayS ) of
                ( Just year, Just month, Just day ) ->
                    let
                        ( hour, minute ) =
                            if allDay then
                                ( 0, 0 )

                            else
                                case String.split ":" timeStr of
                                    [ hS, mS ] ->
                                        ( Maybe.withDefault 0 (String.toInt hS)
                                        , Maybe.withDefault 0 (String.toInt mS)
                                        )

                                    _ ->
                                        ( 0, 0 )

                        -- Local Helsinki time as if it were UTC (no offset applied yet)
                        localMs =
                            dateToMillis year month day hour minute

                        -- First pass: estimate UTC using EET (UTC+2 = 120 min)
                        approxUtcPosix =
                            Time.millisToPosix (localMs - 120 * 60000)

                        -- Check DST at estimated UTC; refine offset if needed
                        offsetMins =
                            helsinkiOffset approxUtcPosix

                        -- Final UTC milliseconds
                        utcPosix =
                            Time.millisToPosix (localMs - offsetMins * 60000)
                    in
                    Just (Iso8601.fromTime utcPosix)

                _ ->
                    Nothing

        _ ->
            Nothing


{-| Convert a UTC ISO string to a "YYYY-MM-DD" string in Helsinki time. -}
utcStringToHelsinkiDateInput : String -> String
utcStringToHelsinkiDateInput utcStr =
    case parseUtcString utcStr of
        Nothing ->
            ""

        Just posix ->
            let
                parts =
                    toHelsinkiParts posix
            in
            String.fromInt parts.year
                ++ "-"
                ++ pad2 parts.month
                ++ "-"
                ++ pad2 parts.day


{-| Convert a UTC ISO string to a "HH:MM" string in Helsinki time. -}
utcStringToHelsinkiTimeInput : String -> String
utcStringToHelsinkiTimeInput utcStr =
    case parseUtcString utcStr of
        Nothing ->
            ""

        Just posix ->
            let
                parts =
                    toHelsinkiParts posix
            in
            pad2 parts.hour ++ ":" ++ pad2 parts.minute


pad2 : Int -> String
pad2 n =
    if n < 10 then
        "0" ++ String.fromInt n

    else
        String.fromInt n


-- CALENDAR GRID UTILITIES


{-| Number of days in a given month (1-indexed). Handles leap years. -}
daysInMonth : Int -> Int -> Int
daysInMonth year month =
    case month of
        2 ->
            if isLeapYear year then
                29

            else
                28

        m ->
            if List.member m [ 4, 6, 9, 11 ] then
                30

            else
                31


{-| Day of week of the 1st of the month, where 0=Monday, 6=Sunday (Finnish calendar). -}
firstDayOfWeek : Int -> Int -> Int
firstDayOfWeek year month =
    let
        firstMs =
            dateToMillis year month 1 0 0

        weekday =
            Time.toWeekday Time.utc (Time.millisToPosix firstMs)
    in
    weekdayToMondayOffset weekday


{-| Generate a 6×7 month grid (rows of weeks, days as Maybe Int).
Nothing = padding day outside the month. Just n = day number.
-}
monthGrid : Int -> Int -> List (List (Maybe Int))
monthGrid year month =
    let
        offset =
            firstDayOfWeek year month

        days =
            daysInMonth year month

        total =
            6 * 7

        cells =
            List.map
                (\i ->
                    if i < offset || i >= offset + days then
                        Nothing

                    else
                        Just (i - offset + 1)
                )
                (List.range 0 (total - 1))
    in
    chunk 7 cells


chunk : Int -> List a -> List (List a)
chunk n list =
    if List.isEmpty list then
        []

    else
        List.take n list :: chunk n (List.drop n list)


{-| Previous month as (year, month). -}
prevMonth : Int -> Int -> ( Int, Int )
prevMonth year month =
    if month == 1 then
        ( year - 1, 12 )

    else
        ( year, month - 1 )


{-| Next month as (year, month). -}
nextMonth : Int -> Int -> ( Int, Int )
nextMonth year month =
    if month == 12 then
        ( year + 1, 1 )

    else
        ( year, month + 1 )
