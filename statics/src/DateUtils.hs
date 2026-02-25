module DateUtils (
    toHelsinki,
    helsinkiOffset,
    isDst,
    formatDay,
    formatDate,
    formatTime,
    formatEventDate,
    formatICalDate,
    finnishWeekdayAbbr,
    finnishMonthName,
) where

import Data.Time (
    DayOfWeek (..),
    LocalTime (..),
    TimeOfDay (..),
    TimeZone (..),
    UTCTime (..),
    ZonedTime (..),
    addDays,
    dayOfWeek,
    fromGregorian,
    toGregorian,
    utcToZonedTime,
 )
import Data.Time.Calendar (Day)
import qualified PocketBase as PB

-- | Helsinki timezone offset in minutes (EET=120, EEST=180).
helsinkiOffset :: UTCTime -> Int
helsinkiOffset t = if isDst t then 180 else 120

{- | Is Helsinki currently observing DST (EEST, UTC+3)?
DST: last Sunday of March 01:00 UTC → last Sunday of October 01:00 UTC
-}
isDst :: UTCTime -> Bool
isDst t =
    let (year, _, _) = toGregorian (utctDay t)
        dstStart = UTCTime (lastSundayOf year 3) (fromIntegral (1 * 3600 :: Int))
        dstEnd = UTCTime (lastSundayOf year 10) (fromIntegral (1 * 3600 :: Int))
     in t >= dstStart && t < dstEnd

-- | Find the last Sunday of a given year/month.
lastSundayOf :: Integer -> Int -> Day
lastSundayOf year month =
    let lastDay = fromGregorian year month (daysInMonth year month)
        offset = case dayOfWeek lastDay of
            Sunday -> 0 :: Int
            Monday -> 1
            Tuesday -> 2
            Wednesday -> 3
            Thursday -> 4
            Friday -> 5
            Saturday -> 6
     in addDays (negate (toInteger offset)) lastDay

-- | Number of days in a given month (handles leap years).
daysInMonth :: Integer -> Int -> Int
daysInMonth year month
    | month == 2 = if isLeap year then 29 else 28
    | month `elem` [4, 6, 9, 11] = 30
    | otherwise = 31
  where
    isLeap y = (y `mod` 4 == 0 && y `mod` 100 /= 0) || y `mod` 400 == 0

-- | Convert UTC to Helsinki local time.
toHelsinki :: UTCTime -> ZonedTime
toHelsinki t =
    let offsetMins = helsinkiOffset t
        tzName = if offsetMins == 180 then "EEST" else "EET"
        tz = TimeZone offsetMins True tzName
     in utcToZonedTime tz t

-- | Finnish weekday abbreviation (Mon=ma … Sun=su).
finnishWeekdayAbbr :: DayOfWeek -> String
finnishWeekdayAbbr Monday = "ma"
finnishWeekdayAbbr Tuesday = "ti"
finnishWeekdayAbbr Wednesday = "ke"
finnishWeekdayAbbr Thursday = "to"
finnishWeekdayAbbr Friday = "pe"
finnishWeekdayAbbr Saturday = "la"
finnishWeekdayAbbr Sunday = "su"

-- | Finnish month name (1-indexed, January=1).
finnishMonthName :: Int -> String
finnishMonthName m =
    [ "Tammikuu"
    , "Helmikuu"
    , "Maaliskuu"
    , "Huhtikuu"
    , "Toukokuu"
    , "Kesäkuu"
    , "Heinäkuu"
    , "Elokuu"
    , "Syyskuu"
    , "Lokakuu"
    , "Marraskuu"
    , "Joulukuu"
    ]
        !! (m - 1)

-- | Format weekday abbreviation for a ZonedTime.
formatDay :: ZonedTime -> String
formatDay zt = finnishWeekdayAbbr (dayOfWeek (localDay (zonedTimeToLocalTime zt)))

-- | Format date as "D.M." (no leading zeros, trailing dot).
formatDate :: ZonedTime -> String
formatDate zt =
    let (_, m, d) = toGregorian (localDay (zonedTimeToLocalTime zt))
     in show d ++ "." ++ show m ++ "."

-- | Format time as "H.MM" (Finnish style, dot separator).
formatTime :: ZonedTime -> String
formatTime zt =
    let tod = localTimeOfDay (zonedTimeToLocalTime zt)
     in show (todHour tod) ++ "." ++ pad2 (todMin tod)

pad2 :: Int -> String
pad2 n = if n < 10 then "0" ++ show n else show n

{- | Format an event's date range for display (Finnish format).
Implements the 6 format variants from the plan doc 02.
-}
formatEventDate :: PB.Event -> String
formatEventDate ev =
    let start = toHelsinki (PB.eventStartDate ev)
        allDay = PB.eventAllDay ev
     in case PB.eventEndDate ev of
            Nothing ->
                if allDay
                    then formatDay start ++ " " ++ formatDate start
                    else formatDay start ++ " " ++ formatDate start ++ " klo " ++ formatTime start
            Just endUtc ->
                let end = toHelsinki endUtc
                    (_, sm, sd) = toGregorian (localDay (zonedTimeToLocalTime start))
                    (_, em, ed) = toGregorian (localDay (zonedTimeToLocalTime end))
                    sameDay = sm == em && sd == ed
                 in if allDay
                        then formatAllDayRange start end sameDay sm em
                        else formatTimedRange start end sameDay

formatDayNum :: ZonedTime -> String
formatDayNum zt =
    let (_, _, d) = toGregorian (localDay (zonedTimeToLocalTime zt))
     in show d ++ "."

formatAllDayRange :: ZonedTime -> ZonedTime -> Bool -> Int -> Int -> String
formatAllDayRange start end sameDay sm em
    | sameDay = formatDay start ++ " " ++ formatDate start
    | sm == em =
        formatDay start
            ++ "–"
            ++ formatDay end
            ++ " "
            ++ formatDayNum start
            ++ "–"
            ++ formatDate end
    | otherwise = formatDate start ++ "–" ++ formatDate end

formatTimedRange :: ZonedTime -> ZonedTime -> Bool -> String
formatTimedRange start end sameDay
    | sameDay =
        formatDay start
            ++ " "
            ++ formatDate start
            ++ " klo "
            ++ formatTime start
            ++ "–"
            ++ formatTime end
    | otherwise =
        formatDate start
            ++ " "
            ++ formatTime start
            ++ "–"
            ++ formatDate end
            ++ " "
            ++ formatTime end

{- | Format a UTCTime for iCal DTSTART/DTEND.
All-day events: DATE format (YYYYMMDD).
Timed events:   DATE-TIME in Helsinki local (YYYYMMDDTHHMMSS, no Z).
-}
formatICalDate :: UTCTime -> Bool -> String
formatICalDate t True =
    let zt = toHelsinki t
        (y, m, d) = toGregorian (localDay (zonedTimeToLocalTime zt))
     in show y ++ pad2 m ++ pad2 d
formatICalDate t False =
    let zt = toHelsinki t
        local = zonedTimeToLocalTime zt
        (y, m, d) = toGregorian (localDay local)
        tod = localTimeOfDay local
     in show y
            ++ pad2 m
            ++ pad2 d
            ++ "T"
            ++ pad2 (todHour tod)
            ++ pad2 (todMin tod)
            ++ "00"
