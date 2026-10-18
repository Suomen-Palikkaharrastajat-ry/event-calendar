module Main (main) where

import qualified Archive
import qualified FeedGen
import qualified GeoJsonGen
import qualified HtmlGen
import qualified ICalGen
import qualified ImageFetcher
import qualified PocketBase

import Control.Exception (SomeException, try)
import qualified Data.Map.Strict as Map
import Data.Time (LocalTime (..), UTCTime (..), ZonedTime (..), getCurrentTime, utctDay)
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

-- | Adapt PocketBase events to the shared image fetcher.
eventImageSource :: ImageFetcher.ImageSource PocketBase.Event
eventImageSource =
    ImageFetcher.ImageSource
        { ImageFetcher.sourceId = PocketBase.eventId
        , ImageFetcher.sourceImage = PocketBase.eventImage
        , ImageFetcher.sourceImageUrl = PocketBase.imageUrl
        , ImageFetcher.destDir = "assets/images"
        }

run :: IO ()
run = do
    putStrLn "Fetching events from PocketBase..."
    events <- PocketBase.fetchPublishedEvents

    putStrLn $ "Fetched " ++ show (length events) ++ " events."

    -- Ensure output directories exist
    createDirectoryIfMissing True "assets/events"
    createDirectoryIfMissing True "assets/images"

    -- Download images concurrently
    putStrLn "Downloading images..."
    imageMap <- ImageFetcher.downloadAllImages eventImageSource events

    -- Determine upcoming events (used for all feeds and the calendar HTML)
    now <- getCurrentTime
    let todayUtc = UTCTime (utctDay now) 0
        todayHki = localDay (zonedTimeToLocalTime (DU.toHelsinki now))
        upcomingEvents = filter (Archive.isUpcoming todayHki todayUtc) events
        pastByYear = Archive.pastEventsByYear (filter (not . Archive.isUpcoming todayHki todayUtc) events)

    -- Generate per-event ICS for ALL events (needed for event HTML pages)
    putStrLn "Generating iCal feeds..."
    icsContentList <-
        mapM
            ( \ev -> do
                ics <- ICalGen.generateEventIcs ev
                writeStaticFile ("assets/events/" ++ PocketBase.eventId ev ++ ".ics") ics
                return (PocketBase.eventId ev, ics)
            )
            events

    -- Master ICS: upcoming events only
    masterIcs <- ICalGen.generateMasterIcs upcomingEvents
    writeStaticFile "assets/kalenteri.ics" masterIcs

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
    json <- FeedGen.generateJsonFeed genCtx (reverse (Map.keys pastByYear)) upcomingEvents
    writeStaticFile "assets/kalenteri.rss" rss
    writeStaticFile "assets/kalenteri.atom" atom
    writeStaticFile "assets/kalenteri.json" json

    -- Yearly archives of past events, read by the SPA when nobody is signed in
    putStrLn "Generating yearly archives..."
    mapM_
        ( \(year, yearEvents) -> do
            yearJson <- FeedGen.generateJsonFeedYear genCtx year yearEvents
            writeStaticFile ("assets/kalenteri-" ++ show year ++ ".json") yearJson
        )
        (Map.toList pastByYear)

    -- Generate GeoJSON (upcoming events only)
    putStrLn "Generating GeoJSON..."
    geo <- GeoJsonGen.generateGeoJson upcomingEvents
    writeStaticFile "assets/kalenteri.geo.json" geo

    -- Generate HTML (upcoming events only)
    putStrLn "Generating HTML..."
    html <- HtmlGen.generateCalendarHtml upcomingEvents
    writeStaticFile "assets/kalenteri.html" html
    mapM_
        ( \ev -> do
            evHtml <- HtmlGen.generateEventHtml ev
            writeStaticFile ("assets/events/" ++ PocketBase.eventId ev ++ ".html") evHtml
        )
        events

-- | Write a file to assets/ (and dist/ if it exists).
writeStaticFile :: FilePath -> String -> IO ()
writeStaticFile = writeFile
