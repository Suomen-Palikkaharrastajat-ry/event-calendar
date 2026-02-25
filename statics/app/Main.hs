module Main (main) where

import qualified FeedGen
import qualified GeoJsonGen
import qualified HtmlGen
import qualified ICalGen
import qualified ImageFetcher
import qualified PocketBase

import Control.Exception (SomeException, try)
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

    -- Generate iCal feeds
    putStrLn "Generating iCal feeds..."
    masterIcs <- ICalGen.generateMasterIcs events
    writeStaticFile "static/kalenteri.ics" masterIcs
    icsContentList <- mapM
        ( \ev -> do
            ics <- ICalGen.generateEventIcs ev
            writeStaticFile ("static/events/" ++ PocketBase.eventId ev ++ ".ics") ics
            return (PocketBase.eventId ev, ics)
        )
        events

    -- Generate RSS / Atom / JSON feeds
    putStrLn "Generating feeds..."
    rss <- FeedGen.generateRss icsContentList imageMap events
    atom <- FeedGen.generateAtom icsContentList imageMap events
    json <- FeedGen.generateJsonFeed events
    writeStaticFile "static/kalenteri.rss" rss
    writeStaticFile "static/kalenteri.atom" atom
    writeStaticFile "static/kalenteri.json" json

    -- Generate GeoJSON
    putStrLn "Generating GeoJSON..."
    geo <- GeoJsonGen.generateGeoJson events
    writeStaticFile "static/kalenteri.geo.json" geo

    -- Generate HTML
    putStrLn "Generating HTML..."
    html <- HtmlGen.generateCalendarHtml events
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
