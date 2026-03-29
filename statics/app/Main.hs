module Main (main) where

import qualified FeedGen
import qualified GeoJsonGen
import qualified HtmlGen
import qualified ICalGen
import qualified ImageFetcher
import qualified PocketBase

import Control.Exception (SomeException, try)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Time (Day, LocalTime (..), UTCTime (..), ZonedTime (..), getCurrentTime, utctDay)
import qualified DateUtils as DU
import GHC.IO.Encoding (setLocaleEncoding, utf8)
import System.Directory (createDirectoryIfMissing)
import System.Exit (ExitCode (..), exitWith)

-- | Entry point: fetch events from PocketBase and generate all static files.
main :: IO ()
main = do
    -- Ensure all file I/O uses UTF-8 regardless of system locale
    setLocaleEncoding utf8
    result <- try run :: IO (Either SomeException ())
    case result of
        Left err -> do
            putStrLn $ "Error: " ++ show err
            exitWith (ExitFailure 1)
        Right () -> putStrLn "Done."

run :: IO ()
run = do
    putStrLn "Fetching events from PocketBase..."
    events <- PocketBase.fetchPublishedEvents

    putStrLn $ "Fetched " ++ show (length events) ++ " events."

    -- Ensure output directories exist
    createDirectoryIfMissing True "static/events"
    createDirectoryIfMissing True "static/images"

    -- Download images concurrently
    putStrLn "Downloading images..."
    imageMap <- ImageFetcher.downloadAllImages events

    -- Determine upcoming events (used for all feeds and the calendar HTML)
    now <- getCurrentTime
    let todayUtc = UTCTime (utctDay now) 0
        todayHki = localDay (zonedTimeToLocalTime (DU.toHelsinki now))
        upcomingEvents = filter (isUpcoming todayHki todayUtc) events

    -- Generate per-event ICS for ALL events (needed for event HTML pages)
    putStrLn "Generating iCal feeds..."
    icsContentList <-
        mapM
            ( \ev -> do
                ics <- ICalGen.generateEventIcs ev
                writeStaticFile ("static/events/" ++ PocketBase.eventId ev ++ ".ics") ics
                return (PocketBase.eventId ev, ics)
            )
            events

    -- Master ICS: upcoming events only
    masterIcs <- ICalGen.generateMasterIcs upcomingEvents
    writeStaticFile "static/kalenteri.ics" masterIcs

    -- Build generator context (Map lookups are O(log n) vs O(n) for list-of-tuples)
    let genCtx =
            FeedGen.GeneratorContext
                { FeedGen.icsMap = Map.fromList icsContentList
                , FeedGen.imageMap = Map.fromList imageMap
                }

    -- Generate RSS / Atom / JSON feeds (upcoming events only)
    putStrLn "Generating feeds..."
    rss <- FeedGen.generateRss genCtx upcomingEvents
    atom <- FeedGen.generateAtom genCtx upcomingEvents
    json <- FeedGen.generateJsonFeed upcomingEvents
    writeStaticFile "static/kalenteri.rss" rss
    writeStaticFile "static/kalenteri.atom" atom
    writeStaticFile "static/kalenteri.json" json

    -- Generate GeoJSON (upcoming events only)
    putStrLn "Generating GeoJSON..."
    geo <- GeoJsonGen.generateGeoJson upcomingEvents
    writeStaticFile "static/kalenteri.geo.json" geo

    -- Generate HTML (upcoming events only)
    putStrLn "Generating HTML..."
    html <- HtmlGen.generateCalendarHtml upcomingEvents
    writeStaticFile "static/kalenteri.html" html
    mapM_
        ( \ev -> do
            evHtml <- HtmlGen.generateEventHtml ev
            writeStaticFile ("static/events/" ++ PocketBase.eventId ev ++ ".html") evHtml
        )
        events

-- | Write a file to static/ (and build/ if it exists).
writeStaticFile :: FilePath -> String -> IO ()
writeStaticFile path content = do
    writeFile path content

{- | True if an event's effective end (end_date if set, else start_date) is today or later.
All-day events compare by Helsinki calendar date (their dates are stored as Helsinki midnight
converted to UTC, so UTC midnight comparison would incorrectly exclude events ending "today").
-}
isUpcoming :: Day -> UTCTime -> PocketBase.Event -> Bool
isUpcoming todayHki todayUtc ev =
    let effective = fromMaybe (PocketBase.eventStartDate ev) (PocketBase.eventEndDate ev)
     in if PocketBase.eventAllDay ev
            then localDay (zonedTimeToLocalTime (DU.toHelsinki effective)) >= todayHki
            else effective >= todayUtc
