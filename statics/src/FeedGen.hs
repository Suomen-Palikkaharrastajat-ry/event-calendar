{- | RSS 2.0, Atom 1.0, and JSON Feed 1.0 generation.
RSS and Atom are generated as raw XML strings.
JSON Feed is generated using aeson.
-}
module FeedGen (
    GeneratorContext (..),
    generateRss,
    generateAtom,
    generateJsonFeed,
) where

import qualified Config
import Control.Exception (SomeException, try)
import Data.Aeson (Value, encode, object, (.=))
import Data.Either (fromRight)
import qualified Data.Map.Strict as Map
import Data.Maybe (maybeToList)
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Encoding as TLE
import Data.Time (UTCTime, getCurrentTime)
import Data.Time.Format (defaultTimeLocale, formatTime)
import qualified DateUtils as DU
import qualified PocketBase as PB
import System.Directory (getFileSize)

-- ---------------------------------------------------------------------------
-- Feed metadata
-- ---------------------------------------------------------------------------

feedTitle :: String
feedTitle = "Palikkakalenteri"

feedLink :: String
feedLink = "https://kalenteri.palikkaharrastajat.fi/"

feedSelf :: String
feedSelf = "https://kalenteri.palikkaharrastajat.fi/"

feedDescription :: String
feedDescription = "Suomen Palikkaharrastajat ry:n Palikkakalenteri"

feedId :: String
feedId = "https://kalenteri.palikkaharrastajat.fi/"

feedLogoUrl :: String
feedLogoUrl = Config.siteBaseUrl ++ "/logo/square/png/square-smile.png"

{- | Context passed to per-event item/entry builders.
Using 'Map.Map' for O(log n) lookup instead of the O(n) list-of-tuples pattern.
-}
data GeneratorContext = GeneratorContext
    { icsMap :: Map.Map String String
    -- ^ Maps event ID → per-event ICS text (for enclosure length calculation).
    , imageMap :: Map.Map String FilePath
    -- ^ Maps event ID → local downloaded image path (for enclosure file size).
    }

{- | Build the local static image URL for an event, if it has an image.
Images are served from the site itself under /images/{eventId}_{filename}.
-}
eventImageUrl :: PB.Event -> Maybe String
eventImageUrl ev = case PB.eventImage ev of
    Nothing -> Nothing
    Just fname -> Just $ Config.siteBaseUrl ++ "/images/" ++ PB.eventId ev ++ "_" ++ T.unpack fname

{- | Build the feed item title: date prefix + event title + location.
All-day events use the full date range (with weekday abbr); timed events
use just "D.M." (no weekday, no clock time) to match upstream format.
-}
feedItemTitle :: PB.Event -> String
feedItemTitle ev =
    let title = T.unpack (PB.eventTitle ev)
        loc = maybe "" (\l -> " | " ++ T.unpack l) (PB.eventLocation ev)
        dateStr
            | PB.eventAllDay ev = DU.formatEventDate ev
            | otherwise = DU.formatDate (DU.toHelsinki (PB.eventStartDate ev))
     in dateStr ++ " " ++ title ++ loc

-- ---------------------------------------------------------------------------
-- XML helpers
-- ---------------------------------------------------------------------------

-- | Escape XML special characters for element text content.
xmlEscape :: String -> String
xmlEscape = concatMap esc
  where
    esc '<' = "&lt;"
    esc '>' = "&gt;"
    esc '&' = "&amp;"
    esc '"' = "&quot;"
    esc '\'' = "&apos;"
    esc c = [c]

-- | Wrap content in an XML element with the given tag name.
xmlEl :: String -> String -> String
xmlEl tag content = "<" ++ tag ++ ">" ++ content ++ "</" ++ tag ++ ">"

-- | Wrap escaped text content in an XML element.
xmlText :: String -> String -> String
xmlText tag txt = xmlEl tag (xmlEscape txt)

-- | Build an XML element with a CDATA section.
xmlCdata :: String -> String -> String
xmlCdata tag content = "<" ++ tag ++ "><![CDATA[" ++ content ++ "]]></" ++ tag ++ ">"

-- ---------------------------------------------------------------------------
-- Date formatting
-- ---------------------------------------------------------------------------

-- | Format a UTCTime as RFC 822 (for RSS pubDate).
formatRfc822 :: UTCTime -> String
formatRfc822 = formatTime defaultTimeLocale "%a, %d %b %Y %H:%M:%S GMT"

-- | Format a UTCTime as RFC 3339 (for Atom updated).
formatRfc3339 :: UTCTime -> String
formatRfc3339 = formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ"

-- | Format a UTCTime as RFC 3339 with milliseconds (for JSON Feed).
formatRfc3339Ms :: UTCTime -> String
formatRfc3339Ms = formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%S.000Z"

-- ---------------------------------------------------------------------------
-- RSS 2.0
-- ---------------------------------------------------------------------------

rssItemTitle :: PB.Event -> String
rssItemTitle = feedItemTitle

-- | Description: body text first, formatted date appended on a new paragraph.
rssItemDescription :: PB.Event -> String
rssItemDescription ev =
    let date = DU.formatEventDate ev
        desc = maybe "" T.unpack (PB.eventDescription ev)
     in if null desc then date else desc ++ "\n\n" ++ date

-- | Build a single RSS item.
buildRssItem :: GeneratorContext -> PB.Event -> IO String
buildRssItem ctx ev = do
    -- ICS enclosure (primary, present for every event)
    let icsUrl = Config.siteBaseUrl ++ "/events/" ++ PB.eventId ev ++ ".ics"
    let icsLen = maybe 0 length (Map.lookup (PB.eventId ev) (icsMap ctx))
    let icsEncl =
            "      <enclosure url=\""
                ++ xmlEscape icsUrl
                ++ "\" length=\""
                ++ show icsLen
                ++ "\" type=\"text/calendar\"/>"
    -- Image enclosure (secondary, only when event has an image)
    imgEncl <- case eventImageUrl ev of
        Nothing -> return Nothing
        Just imgUrl -> do
            let maybeLocalPath = Map.lookup (PB.eventId ev) (imageMap ctx)
            fileSize <- case maybeLocalPath of
                Nothing -> return (0 :: Integer)
                Just fp -> do
                    result <- try (getFileSize fp) :: IO (Either SomeException Integer)
                    return (fromRight 0 result)
            return $
                Just $
                    "      <enclosure url=\""
                        ++ xmlEscape imgUrl
                        ++ "\" length=\""
                        ++ show fileSize
                        ++ "\" type=\"image/jpeg\"/>"
    return $
        unlines $
            [ "    <item>"
            , "      " ++ xmlCdata "title" (rssItemTitle ev)
            , "      " ++ xmlCdata "description" (rssItemDescription ev)
            , "      <guid isPermaLink=\"false\">"
                ++ Config.siteBaseUrl
                ++ "/#/events/"
                ++ PB.eventId ev
                ++ "</guid>"
            , "      " ++ xmlText "pubDate" (formatRfc822 (PB.eventUpdated ev))
            ]
                ++ maybe
                    []
                    (\u -> ["      " ++ xmlEl "link" (xmlEscape (T.unpack u))])
                    (PB.eventUrl ev)
                ++ [icsEncl]
                ++ maybeToList imgEncl
                ++ ["    </item>"]

-- | Generate an RSS 2.0 feed.
generateRss :: GeneratorContext -> [PB.Event] -> IO String
generateRss ctx events = do
    now <- getCurrentTime
    items <- mapM (buildRssItem ctx) events
    return $
        unlines
            [ "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
            , "<rss version=\"2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom\">"
            , "  <channel>"
            , "    " ++ xmlText "title" feedTitle
            , "    " ++ xmlEl "link" feedLink
            , "    " ++ xmlText "description" feedDescription
            , "    " ++ xmlText "lastBuildDate" (formatRfc822 now)
            , "    " ++ xmlEl "docs" "https://validator.w3.org/feed/docs/rss2.html"
            , "    " ++ xmlText "generator" "Emmet"
            , "    " ++ xmlText "language" "fi"
            , "    <image>"
            , "      " ++ xmlText "title" feedTitle
            , "      " ++ xmlEl "url" feedLogoUrl
            , "      " ++ xmlEl "link" feedLink
            , "    </image>"
            , "    " ++ xmlText "copyright" "Suomen Palikkaharrastajat ry"
            , "    <atom:link href=\""
                ++ feedSelf
                ++ "kalenteri.rss\" rel=\"self\" type=\"application/rss+xml\"/>"
            , concat items
            , "  </channel>"
            , "</rss>"
            ]

-- ---------------------------------------------------------------------------
-- Atom 1.0
-- ---------------------------------------------------------------------------

buildAtomEntry :: GeneratorContext -> PB.Event -> IO String
buildAtomEntry ctx ev = do
    -- ICS enclosure link
    let icsUrl = Config.siteBaseUrl ++ "/events/" ++ PB.eventId ev ++ ".ics"
    let icsLen = maybe 0 length (Map.lookup (PB.eventId ev) (icsMap ctx))
    let icsLink =
            "    <link rel=\"enclosure\" type=\"text/calendar\" href=\""
                ++ xmlEscape icsUrl
                ++ "\" length=\""
                ++ show icsLen
                ++ "\"/>"
    -- Image enclosure link
    imgLink <- case eventImageUrl ev of
        Nothing -> return Nothing
        Just imgUrl -> do
            let maybeLocalPath = Map.lookup (PB.eventId ev) (imageMap ctx)
            fileSize <- case maybeLocalPath of
                Nothing -> return (0 :: Integer)
                Just fp -> do
                    result <- try (getFileSize fp) :: IO (Either SomeException Integer)
                    return (fromRight 0 result)
            return $
                Just $
                    "    <link rel=\"enclosure\" type=\"image/jpeg\" href=\""
                        ++ xmlEscape imgUrl
                        ++ "\" length=\""
                        ++ show fileSize
                        ++ "\"/>"
    let summaryContent =
            let desc = maybe "" T.unpack (PB.eventDescription ev)
                date = DU.formatEventDate ev
             in if null desc then date else desc ++ "\n\n" ++ date
    return $
        unlines $
            [ "  <entry>"
            , "    " ++ xmlText "id" (Config.siteBaseUrl ++ "/#/events/" ++ PB.eventId ev)
            , "    <title type=\"html\">" ++ xmlEscape (feedItemTitle ev) ++ "</title>"
            , "    " ++ xmlText "published" (formatRfc3339 (PB.eventCreated ev))
            , "    " ++ xmlText "updated" (formatRfc3339 (PB.eventUpdated ev))
            , "    <author><name>Suomen Palikkaharrastajat ry</name></author>"
            , "    <link rel=\"alternate\" href=\""
                ++ maybe "" (xmlEscape . T.unpack) (PB.eventUrl ev)
                ++ "\"/>"
            , icsLink
            ]
                ++ maybeToList imgLink
                ++ [ "    <summary type=\"html\"><![CDATA[" ++ summaryContent ++ "]]></summary>"
                   , "  </entry>"
                   ]

-- | Generate an Atom 1.0 feed.
generateAtom :: GeneratorContext -> [PB.Event] -> IO String
generateAtom ctx events = do
    now <- getCurrentTime
    entries <- mapM (buildAtomEntry ctx) events
    return $
        unlines
            [ "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
            , "<feed xmlns=\"http://www.w3.org/2005/Atom\">"
            , "  " ++ xmlText "title" feedTitle
            , "  <link href=\"" ++ feedLink ++ "\" rel=\"alternate\"/>"
            , "  <link href=\"" ++ feedSelf ++ "kalenteri.atom\" rel=\"self\"/>"
            , "  " ++ xmlText "id" feedId
            , "  " ++ xmlText "subtitle" feedDescription
            , "  " ++ xmlText "updated" (formatRfc3339 now)
            , "  " ++ xmlText "rights" "Suomen Palikkaharrastajat ry"
            , "  " ++ xmlEl "logo" feedLogoUrl
            , "  " ++ xmlEl "icon" (Config.siteBaseUrl ++ "/favicon.ico")
            , "  " ++ xmlText "generator" "Emmet"
            , "  <author><name>Suomen Palikkaharrastajat ry</name><email>palikkaharrastajatry@outlook.com</email><uri>https://palikkaharrastajat.fi/</uri></author>"
            , concat entries
            , "</feed>"
            ]

-- ---------------------------------------------------------------------------
-- JSON Feed 1.0
-- ---------------------------------------------------------------------------

jsonFeedItem :: PB.Event -> Value
jsonFeedItem ev =
    let contentHtml =
            let desc = maybe "" T.unpack (PB.eventDescription ev)
                date = DU.formatEventDate ev
             in if null desc then date else desc ++ "\n\n" ++ date
        baseFields =
            [ "id" .= (Config.siteBaseUrl ++ "/#/events/" ++ PB.eventId ev)
            , "title" .= feedItemTitle ev
            , "content_html" .= contentHtml
            , "date_published" .= formatRfc3339Ms (PB.eventCreated ev)
            , "date_modified" .= formatRfc3339Ms (PB.eventUpdated ev)
            , "author" .= object ["name" .= ("Suomen Palikkaharrastajat ry" :: String)]
            ]
        urlField = case PB.eventUrl ev of
            Just u -> ["url" .= T.unpack u]
            Nothing -> []
        imgField = case eventImageUrl ev of
            Just img -> ["image" .= img]
            Nothing -> []
     in object (baseFields ++ urlField ++ imgField)

-- | Generate a JSON Feed 1.0 document.
generateJsonFeed :: [PB.Event] -> IO String
generateJsonFeed events =
    return $
        TL.unpack $
            TLE.decodeUtf8 $
                encode $
                    object
                        [ "version" .= ("https://jsonfeed.org/version/1" :: String)
                        , "title" .= feedTitle
                        , "home_page_url" .= feedLink
                        , "description" .= feedDescription
                        , "icon" .= feedLogoUrl
                        , "author"
                            .= object
                                [ "name" .= ("Suomen Palikkaharrastajat ry" :: String)
                                , "url" .= ("https://palikkaharrastajat.fi/" :: String)
                                ]
                        , "items" .= map jsonFeedItem events
                        ]
