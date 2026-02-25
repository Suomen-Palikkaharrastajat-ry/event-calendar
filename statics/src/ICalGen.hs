{- | iCalendar (.ics) generation using manual RFC 5545 text generation.
The iCalendar Hackage package is unmaintained; text generation is sufficient.
-}
module ICalGen (
    generateMasterIcs,
    generateEventIcs,
) where

import qualified Data.Text as T
import Data.Time (LocalTime (..), UTCTime, ZonedTime (..), getCurrentTime)
import Data.Time.Calendar (addDays, toGregorian)
import Data.Time.Format (defaultTimeLocale, formatTime)
import qualified DateUtils as DU
import qualified PocketBase as PB

-- | Site base URL used for VEVENT UIDs (consistent with RSS/Atom GUIDs).
siteBaseUrl :: String
siteBaseUrl = "https://kalenteri.suomenpalikkayhteiso.fi"

{- | Wrap a long iCal property line at 75 octets (RFC 5545 §3.1).
Continuation lines are prefixed with a single space.
-}
foldLine :: String -> [String]
foldLine [] = []
foldLine s =
    let (first, rest) = splitAt 75 s
     in if null rest
            then [first]
            else first : foldLine (' ' : rest)

-- | Render a list of property lines as CRLF-terminated, line-folded text.
renderLines :: [String] -> String
renderLines = concatMap (\l -> concatMap (\f -> f ++ "\r\n") (foldLine l))

-- | Escape special iCal characters in text values (RFC 5545 §3.3.11).
escapeIcal :: String -> String
escapeIcal = concatMap escape
  where
    escape '\n' = "\\n"
    escape ',' = "\\,"
    escape ';' = "\\;"
    escape '\\' = "\\\\"
    escape c = [c]

pad2 :: Int -> String
pad2 n = if n < 10 then "0" ++ show n else show n

{- | Next calendar day in Helsinki local time, formatted as iCal DATE (YYYYMMDD).
Used for all-day DTEND when no explicit end date is given (RFC 5545: exclusive end).
-}
nextICalDay :: UTCTime -> String
nextICalDay t =
    let zt = DU.toHelsinki t
        d = localDay (zonedTimeToLocalTime zt)
        (y, m, day) = toGregorian (addDays 1 d)
     in show y ++ pad2 m ++ pad2 day

-- | Format a UTC time as iCal DTSTAMP (YYYYMMDDTHHMMSSZ).
formatDtStamp :: UTCTime -> String
formatDtStamp = formatTime defaultTimeLocale "%Y%m%dT%H%M%SZ"

-- | Build property lines for a single VEVENT.
eventToVEventLines :: UTCTime -> PB.Event -> [String]
eventToVEventLines now ev =
    [ "BEGIN:VEVENT"
    , "UID:" ++ siteBaseUrl ++ "/#/events/" ++ PB.eventId ev
    , "SEQUENCE:0"
    , "SUMMARY:" ++ escapeIcal (T.unpack (PB.eventTitle ev))
    , dtstart
    , dtend
    ]
        ++ msAllDayLines
        ++ descLine
        ++ urlLine
        ++ locationLine
        ++ geoLine
        ++ [ "DTSTAMP:" ++ formatDtStamp now
           , "END:VEVENT"
           ]
  where
    allDay = PB.eventAllDay ev
    start = PB.eventStartDate ev
    dtstart
        | allDay = "DTSTART;VALUE=DATE:" ++ DU.formatICalDate start True
        | otherwise = "DTSTART;TZID=Europe/Helsinki:" ++ DU.formatICalDate start False
    dtend = case PB.eventEndDate ev of
        Just end ->
            if allDay
                then "DTEND;VALUE=DATE:" ++ DU.formatICalDate end True
                else "DTEND;TZID=Europe/Helsinki:" ++ DU.formatICalDate end False
        Nothing ->
            if allDay
                -- All-day DTEND is exclusive: must be the day after DTSTART
                then "DTEND;VALUE=DATE:" ++ nextICalDay start
                else "DTEND;TZID=Europe/Helsinki:" ++ DU.formatICalDate start False
    -- Microsoft Outlook requires explicit all-day markers
    msAllDayLines
        | allDay =
            [ "X-MICROSOFT-CDO-ALLDAYEVENT:TRUE"
            , "X-MICROSOFT-MSNCALENDAR-ALLDAYEVENT:TRUE"
            ]
        | otherwise = []
    descLine = case PB.eventDescription ev of
        Nothing -> []
        Just d -> ["DESCRIPTION:" ++ escapeIcal (T.unpack d)]
    urlLine = case PB.eventUrl ev of
        Nothing -> []
        Just u -> ["URL;VALUE=URI:" ++ T.unpack u]
    locationLine = case PB.eventLocation ev of
        Nothing -> []
        Just l -> ["LOCATION:" ++ escapeIcal (T.unpack l)]
    geoLine = case PB.eventPoint ev of
        Nothing -> []
        Just pt -> ["GEO:" ++ show (PB.geoLat pt) ++ ";" ++ show (PB.geoLon pt)]

-- | Helsinki VTIMEZONE component (simplified fixed rules valid from 1996 onward).
helsinkiVTimezone :: [String]
helsinkiVTimezone =
    [ "BEGIN:VTIMEZONE"
    , "TZID:Europe/Helsinki"
    , "BEGIN:STANDARD"
    , "TZOFFSETFROM:+0300"
    , "TZOFFSETTO:+0200"
    , "TZNAME:EET"
    , "DTSTART:19701025T040000"
    , "RRULE:FREQ=YEARLY;BYDAY=-1SU;BYMONTH=10"
    , "END:STANDARD"
    , "BEGIN:DAYLIGHT"
    , "TZOFFSETFROM:+0200"
    , "TZOFFSETTO:+0300"
    , "TZNAME:EEST"
    , "DTSTART:19700329T030000"
    , "RRULE:FREQ=YEARLY;BYDAY=-1SU;BYMONTH=3"
    , "END:DAYLIGHT"
    , "END:VTIMEZONE"
    ]

-- | Wrap property lines in a VCALENDAR container.
wrapCalendar :: [String] -> String
wrapCalendar innerLines =
    renderLines $
        [ "BEGIN:VCALENDAR"
        , "VERSION:2.0"
        , "PRODID:-//Suomen Palikkayhteisö ry//Tapahtumat//FI"
        , "CALSCALE:GREGORIAN"
        , "METHOD:PUBLISH"
        , "X-WR-CALNAME:Suomen Palikkayhteisö \x2014 Tapahtumat"
        , "X-WR-TIMEZONE:Europe/Helsinki"
        ]
            ++ helsinkiVTimezone
            ++ innerLines
            ++ ["END:VCALENDAR"]

-- | Generate the master iCal feed for all published events.
generateMasterIcs :: [PB.Event] -> IO String
generateMasterIcs events = do
    now <- getCurrentTime
    return $ wrapCalendar (concatMap (eventToVEventLines now) events)

-- | Generate a single-event iCal file.
generateEventIcs :: PB.Event -> IO String
generateEventIcs ev = do
    now <- getCurrentTime
    return $ wrapCalendar (eventToVEventLines now ev)
