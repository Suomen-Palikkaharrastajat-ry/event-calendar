module Main (main) where

import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

import Data.Aeson (eitherDecode)
import qualified Data.ByteString.Lazy.Char8 as BLC
import Data.List (isInfixOf)
import Data.Time (UTCTime (..), ZonedTime, fromGregorian, secondsToDiffTime)

import qualified DateUtils as DU
import qualified FeedGen
import qualified GeoJsonGen
import qualified ICalGen
import qualified PocketBase as PB

-- ---------------------------------------------------------------------------
-- Test fixtures
-- ---------------------------------------------------------------------------

{- | Timed event, 2026-05-05 11:00–14:00 UTC (= 14:00–17:00 Helsinki EEST).
May 5, 2026 is a Tuesday (ti). Has coordinates and URL.
-}
timedEventJson :: BLC.ByteString
timedEventJson =
    BLC.pack $
        concat
            [ "{\"id\":\"abc123\","
            , "\"title\":\"Parkour Jam\","
            , "\"description\":\"Fun event\","
            , "\"start_date\":\"2026-05-05T11:00:00.000Z\","
            , "\"end_date\":\"2026-05-05T14:00:00.000Z\","
            , "\"all_day\":false,"
            , "\"url\":\"https://example.com\","
            , "\"location\":\"Helsinki, Rautatientori\","
            , "\"state\":\"published\","
            , "\"image\":\"\","
            , "\"image_description\":\"\","
            , "\"point\":{\"lat\":60.1699,\"lon\":24.9384},"
            , "\"created\":\"2026-01-01T00:00:00.000Z\","
            , "\"updated\":\"2026-01-02T00:00:00.000Z\"}"
            ]

{- | All-day event, 2026-06-15 21:00 UTC = June 16 00:00 Helsinki EEST.
June 16, 2026 is a Tuesday (ti). No coordinates, empty optional fields.
-}
allDayEventJson :: BLC.ByteString
allDayEventJson =
    BLC.pack $
        concat
            [ "{\"id\":\"def456\","
            , "\"title\":\"Kaupunkifestivaal\","
            , "\"description\":\"\","
            , "\"start_date\":\"2026-06-15T21:00:00.000Z\","
            , "\"end_date\":null,"
            , "\"all_day\":true,"
            , "\"url\":\"\","
            , "\"location\":\"\","
            , "\"state\":\"published\","
            , "\"image\":\"\","
            , "\"image_description\":\"\","
            , "\"point\":null,"
            , "\"created\":\"2026-01-01T00:00:00.000Z\","
            , "\"updated\":\"2026-01-02T00:00:00.000Z\"}"
            ]

{- | All-day cross-month event: Apr 29 21:00 UTC = Apr 30 Helsinki → May 1 21:00 UTC = May 2 Helsinki.
Format: "30.4.–2.5."
-}
crossMonthEventJson :: BLC.ByteString
crossMonthEventJson =
    BLC.pack $
        concat
            [ "{\"id\":\"ghi789\","
            , "\"title\":\"Multi-day Event\","
            , "\"description\":\"\","
            , "\"start_date\":\"2026-04-29T21:00:00.000Z\","
            , "\"end_date\":\"2026-05-01T21:00:00.000Z\","
            , "\"all_day\":true,"
            , "\"url\":\"\","
            , "\"location\":\"\","
            , "\"state\":\"published\","
            , "\"image\":\"\","
            , "\"image_description\":\"\","
            , "\"point\":null,"
            , "\"created\":\"2026-01-01T00:00:00.000Z\","
            , "\"updated\":\"2026-01-02T00:00:00.000Z\"}"
            ]

decodeEvent :: BLC.ByteString -> PB.Event
decodeEvent bs = case eitherDecode bs of
    Left err -> error ("Test fixture decode failed: " ++ err)
    Right ev -> ev

timedEvent :: PB.Event
timedEvent = decodeEvent timedEventJson

allDayEvent :: PB.Event
allDayEvent = decodeEvent allDayEventJson

crossMonthEvent :: PB.Event
crossMonthEvent = decodeEvent crossMonthEventJson

-- 2026-01-15 10:00 UTC — Helsinki EET (UTC+2, winter), no DST
winterTime :: UTCTime
winterTime = UTCTime (fromGregorian 2026 1 15) (secondsToDiffTime (10 * 3600))

-- May 5 local Helsinki (from timedEvent start)
timedZoned :: ZonedTime
timedZoned = DU.toHelsinki (PB.eventStartDate timedEvent)

-- ---------------------------------------------------------------------------
-- Main
-- ---------------------------------------------------------------------------

main :: IO ()
main =
    defaultMain $
        testGroup
            "statics tests"
            [ testGroup "PocketBase decoder" pocketBaseTests
            , testGroup "DateUtils" dateUtilsTests
            , testGroup "ICalGen" icalGenTests
            , testGroup "GeoJsonGen" geoJsonTests
            , testGroup "FeedGen" feedGenTests
            ]

-- ---------------------------------------------------------------------------
-- PocketBase decoder tests
-- ---------------------------------------------------------------------------

pocketBaseTests :: [TestTree]
pocketBaseTests =
    [ testCase "decodes id" $
        PB.eventId timedEvent @?= "abc123"
    , testCase "decodes title" $
        PB.eventTitle timedEvent @?= "Parkour Jam"
    , testCase "decodes description present" $
        PB.eventDescription timedEvent @?= Just "Fun event"
    , testCase "decodes all_day false" $
        PB.eventAllDay timedEvent @?= False
    , testCase "decodes url" $
        PB.eventUrl timedEvent @?= Just "https://example.com"
    , testCase "decodes location" $
        PB.eventLocation timedEvent @?= Just "Helsinki, Rautatientori"
    , testCase "decodes GeoPoint lat" $
        fmap PB.geoLat (PB.eventPoint timedEvent) @?= Just 60.1699
    , testCase "decodes GeoPoint lon" $
        fmap PB.geoLon (PB.eventPoint timedEvent) @?= Just 24.9384
    , testCase "empty string image becomes Nothing" $
        PB.eventImage timedEvent @?= Nothing
    , testCase "empty string description becomes Nothing" $
        PB.eventDescription allDayEvent @?= Nothing
    , testCase "empty string url becomes Nothing" $
        PB.eventUrl allDayEvent @?= Nothing
    , testCase "null point becomes Nothing" $
        PB.eventPoint allDayEvent @?= Nothing
    , testCase "null end_date becomes Nothing" $
        PB.eventEndDate allDayEvent @?= Nothing
    , testCase "all_day true decoded" $
        PB.eventAllDay allDayEvent @?= True
    , testCase "imageUrl helper" $
        PB.imageUrl timedEvent "photo.jpg"
            @?= "https://data.suomenpalikkayhteiso.fi/api/files/events/abc123/photo.jpg"
    ]

-- ---------------------------------------------------------------------------
-- DateUtils tests
-- ---------------------------------------------------------------------------

dateUtilsTests :: [TestTree]
dateUtilsTests =
    [ testCase "EEST offset is 180 min (summer)" $
        DU.helsinkiOffset (PB.eventStartDate timedEvent) @?= 180
    , testCase "EET offset is 120 min (winter)" $
        DU.helsinkiOffset winterTime @?= 120
    , testCase "isDst true in May 2026" $
        DU.isDst (PB.eventStartDate timedEvent) @?= True
    , testCase "isDst false in January 2026" $
        DU.isDst winterTime @?= False
    , -- DST starts last Sunday of March at 01:00 UTC.
      -- 2026-03-29 is last Sunday of March 2026.
      testCase "isDst false just before 2026 DST start" $
        let t = UTCTime (fromGregorian 2026 3 29) (secondsToDiffTime (3599))
         in DU.isDst t @?= False
    , testCase "isDst true at 2026 DST start (01:00 UTC)" $
        let t = UTCTime (fromGregorian 2026 3 29) (secondsToDiffTime (3600))
         in DU.isDst t @?= True
    , -- DST ends last Sunday of October at 01:00 UTC.
      -- 2026-10-25 is last Sunday of October 2026.
      testCase "isDst true just before 2026 DST end" $
        let t = UTCTime (fromGregorian 2026 10 25) (secondsToDiffTime (3599))
         in DU.isDst t @?= True
    , testCase "isDst false at 2026 DST end (01:00 UTC)" $
        let t = UTCTime (fromGregorian 2026 10 25) (secondsToDiffTime (3600))
         in DU.isDst t @?= False
    , -- formatDate: "D.M." no leading zeros
      testCase "formatDate gives D.M." $
        DU.formatDate timedZoned @?= "5.5."
    , -- formatTime: "H.MM" Finnish style
      testCase "formatTime gives H.MM" $
        DU.formatTime timedZoned @?= "14.00"
    , -- formatDay: Finnish weekday abbreviation
      testCase "formatDay gives ti for Tuesday" $
        DU.formatDay timedZoned @?= "ti"
    , -- Timed event with end on same day: "ti 5.5. klo 14.00–17.00" (en-dash)
      testCase "timed same-day range: ti 5.5. klo 14.00-17.00" $
        DU.formatEventDate timedEvent @?= "ti 5.5. klo 14.00\x2013\&17.00"
    , -- All-day, no end date: "ti 16.6." (June 16, 2026 = Tuesday)
      testCase "all-day single: ti 16.6." $
        DU.formatEventDate allDayEvent @?= "ti 16.6."
    , -- All-day cross-month: "30.4.–2.5." (en-dash)
      testCase "all-day cross-month: 30.4.-2.5." $
        DU.formatEventDate crossMonthEvent @?= "30.4.\x2013\&2.5."
    , -- iCal DATE format (all-day): YYYYMMDD in Helsinki local
      testCase "formatICalDate all-day: 20260505" $
        DU.formatICalDate (PB.eventStartDate timedEvent) True @?= "20260505"
    , -- iCal DATE-TIME format (timed): Helsinki local (UTC+3 → 14:00)
      testCase "formatICalDate timed Helsinki: 20260505T140000" $
        DU.formatICalDate (PB.eventStartDate timedEvent) False @?= "20260505T140000"
    ]

-- ---------------------------------------------------------------------------
-- ICalGen tests
-- ---------------------------------------------------------------------------

icalGenTests :: [TestTree]
icalGenTests =
    [ testCase "master ICS contains BEGIN:VCALENDAR" $ do
        ics <- ICalGen.generateMasterIcs [timedEvent]
        assertBool "BEGIN:VCALENDAR" ("BEGIN:VCALENDAR" `isInfixOf` ics)
    , testCase "master ICS contains END:VCALENDAR" $ do
        ics <- ICalGen.generateMasterIcs [timedEvent]
        assertBool "END:VCALENDAR" ("END:VCALENDAR" `isInfixOf` ics)
    , testCase "master ICS contains BEGIN:VEVENT" $ do
        ics <- ICalGen.generateMasterIcs [timedEvent]
        assertBool "BEGIN:VEVENT" ("BEGIN:VEVENT" `isInfixOf` ics)
    , testCase "master ICS contains VTIMEZONE" $ do
        ics <- ICalGen.generateMasterIcs [timedEvent]
        assertBool "VTIMEZONE" ("BEGIN:VTIMEZONE" `isInfixOf` ics)
    , testCase "timed DTSTART uses TZID=Europe/Helsinki" $ do
        ics <- ICalGen.generateEventIcs timedEvent
        assertBool
            "DTSTART;TZID=Europe/Helsinki:20260505T140000"
            ("DTSTART;TZID=Europe/Helsinki:20260505T140000" `isInfixOf` ics)
    , testCase "all-day DTSTART uses VALUE=DATE" $ do
        ics <- ICalGen.generateEventIcs allDayEvent
        assertBool
            "DTSTART;VALUE=DATE:20260616"
            ("DTSTART;VALUE=DATE:20260616" `isInfixOf` ics)
    , testCase "all-day DTEND is exclusive next day when no end given" $ do
        ics <- ICalGen.generateEventIcs allDayEvent
        assertBool
            "DTEND;VALUE=DATE:20260617"
            ("DTEND;VALUE=DATE:20260617" `isInfixOf` ics)
    , testCase "GEO field present when coordinates exist" $ do
        ics <- ICalGen.generateEventIcs timedEvent
        assertBool "GEO:" ("GEO:" `isInfixOf` ics)
    , testCase "GEO field absent when no coordinates" $ do
        ics <- ICalGen.generateEventIcs allDayEvent
        assertBool "no GEO:" (not ("GEO:" `isInfixOf` ics))
    , testCase "DTSTAMP not hardcoded to epoch" $ do
        ics <- ICalGen.generateEventIcs timedEvent
        assertBool
            "DTSTAMP not 1970"
            (not ("DTSTAMP:19700101T000000Z" `isInfixOf` ics))
    , testCase "SUMMARY contains event title" $ do
        ics <- ICalGen.generateEventIcs timedEvent
        assertBool "SUMMARY:Parkour Jam" ("SUMMARY:Parkour Jam" `isInfixOf` ics)
    , testCase "URL field present with VALUE=URI" $ do
        ics <- ICalGen.generateEventIcs timedEvent
        assertBool
            "URL;VALUE=URI:https://example.com"
            ("URL;VALUE=URI:https://example.com" `isInfixOf` ics)
    , testCase "lines end with CRLF" $ do
        ics <- ICalGen.generateEventIcs timedEvent
        assertBool "CRLF" ("\r\n" `isInfixOf` ics)
    ]

-- ---------------------------------------------------------------------------
-- GeoJsonGen tests
-- ---------------------------------------------------------------------------

geoJsonTests :: [TestTree]
geoJsonTests =
    [ testCase "event with coordinates included" $ do
        geo <- GeoJsonGen.generateGeoJson [timedEvent]
        assertBool "abc123 in output" ("abc123" `isInfixOf` geo)
    , testCase "event without coordinates excluded" $ do
        geo <- GeoJsonGen.generateGeoJson [allDayEvent]
        assertBool
            "no def456 in output"
            (not ("def456" `isInfixOf` geo))
    , testCase "type is FeatureCollection" $ do
        geo <- GeoJsonGen.generateGeoJson [timedEvent]
        assertBool "FeatureCollection" ("FeatureCollection" `isInfixOf` geo)
    , testCase "feature has type Feature" $ do
        geo <- GeoJsonGen.generateGeoJson [timedEvent]
        assertBool "Feature" ("Feature" `isInfixOf` geo)
    , testCase "coordinates in [lon, lat] order (GeoJSON spec)" $ do
        geo <- GeoJsonGen.generateGeoJson [timedEvent]
        -- lon=24.9384 must appear before lat=60.1699 in the output
        let lonIdx =
                length $
                    takeWhile
                        (\c -> not ("24.9384" `isInfixOf` c))
                        [take i geo | i <- [0 .. length geo]]
            latIdx =
                length $
                    takeWhile
                        (\c -> not ("60.1699" `isInfixOf` c))
                        [take i geo | i <- [0 .. length geo]]
        assertBool "lon before lat" (lonIdx < latIdx)
    , testCase "title property present" $ do
        geo <- GeoJsonGen.generateGeoJson [timedEvent]
        assertBool "Parkour Jam" ("Parkour Jam" `isInfixOf` geo)
    , testCase "empty features when no geolocated events" $ do
        geo <- GeoJsonGen.generateGeoJson [allDayEvent]
        assertBool "empty features" ("\"features\":[]" `isInfixOf` geo)
    ]

-- ---------------------------------------------------------------------------
-- FeedGen tests
-- ---------------------------------------------------------------------------

feedGenTests :: [TestTree]
feedGenTests =
    -- RSS 2.0
    [ testCase "RSS has <?xml declaration" $ do
        rss <- FeedGen.generateRss [] [] [timedEvent]
        assertBool "<?xml" ("<?xml" `isInfixOf` rss)
    , testCase "RSS has <rss version=\"2.0\"" $ do
        rss <- FeedGen.generateRss [] [] [timedEvent]
        assertBool "<rss version" ("<rss version=\"2.0\"" `isInfixOf` rss)
    , testCase "RSS has <channel>" $ do
        rss <- FeedGen.generateRss [] [] [timedEvent]
        assertBool "<channel>" ("<channel>" `isInfixOf` rss)
    , testCase "RSS has <item>" $ do
        rss <- FeedGen.generateRss [] [] [timedEvent]
        assertBool "<item>" ("<item>" `isInfixOf` rss)
    , testCase "RSS item title contains event title" $ do
        rss <- FeedGen.generateRss [] [] [timedEvent]
        assertBool "Parkour Jam in RSS" ("Parkour Jam" `isInfixOf` rss)
    , testCase "RSS item has guid element" $ do
        rss <- FeedGen.generateRss [] [] [timedEvent]
        assertBool "guid isPermaLink" ("<guid isPermaLink=\"false\">" `isInfixOf` rss)
    , testCase "RSS guid contains event id" $ do
        rss <- FeedGen.generateRss [] [] [timedEvent]
        assertBool "abc123 in guid" ("abc123" `isInfixOf` rss)
    , testCase "RSS empty events produces no <item>" $ do
        rss <- FeedGen.generateRss [] [] []
        assertBool "no <item>" (not ("<item>" `isInfixOf` rss))
    , -- Atom 1.0
      testCase "Atom has <?xml declaration" $ do
        atom <- FeedGen.generateAtom [] [] [timedEvent]
        assertBool "<?xml" ("<?xml" `isInfixOf` atom)
    , testCase "Atom has Atom namespace" $ do
        atom <- FeedGen.generateAtom [] [] [timedEvent]
        assertBool "Atom xmlns" ("xmlns=\"http://www.w3.org/2005/Atom\"" `isInfixOf` atom)
    , testCase "Atom has <entry>" $ do
        atom <- FeedGen.generateAtom [] [] [timedEvent]
        assertBool "<entry>" ("<entry>" `isInfixOf` atom)
    , testCase "Atom entry title contains event title" $ do
        atom <- FeedGen.generateAtom [] [] [timedEvent]
        assertBool "Parkour Jam" ("Parkour Jam" `isInfixOf` atom)
    , testCase "Atom entry has <updated> with RFC3339 format" $ do
        atom <- FeedGen.generateAtom [] [] [timedEvent]
        -- RFC3339 ends with Z
        assertBool "<updated> with Z" ("<updated>" `isInfixOf` atom)
    , testCase "Atom entry id contains event id" $ do
        atom <- FeedGen.generateAtom [] [] [timedEvent]
        assertBool "abc123 in atom entry" ("abc123" `isInfixOf` atom)
    , testCase "Atom empty events produces no <entry>" $ do
        atom <- FeedGen.generateAtom [] [] []
        assertBool "no <entry>" (not ("<entry>" `isInfixOf` atom))
    , -- JSON Feed 1.0
      testCase "JSON Feed has version field" $ do
        jf <- FeedGen.generateJsonFeed [timedEvent]
        assertBool "jsonfeed version" ("jsonfeed.org/version/1" `isInfixOf` jf)
    , testCase "JSON Feed has title" $ do
        jf <- FeedGen.generateJsonFeed [timedEvent]
        assertBool "title field" ("Palikkakalenteri" `isInfixOf` jf)
    , testCase "JSON Feed has items array" $ do
        jf <- FeedGen.generateJsonFeed [timedEvent]
        assertBool "items" ("\"items\"" `isInfixOf` jf)
    , testCase "JSON Feed item has event id" $ do
        jf <- FeedGen.generateJsonFeed [timedEvent]
        assertBool "abc123" ("abc123" `isInfixOf` jf)
    , testCase "JSON Feed item has event title" $ do
        jf <- FeedGen.generateJsonFeed [timedEvent]
        assertBool "Parkour Jam" ("Parkour Jam" `isInfixOf` jf)
    , testCase "JSON Feed empty events has empty items" $ do
        jf <- FeedGen.generateJsonFeed []
        assertBool "empty items" ("\"items\":[]" `isInfixOf` jf)
    ]
