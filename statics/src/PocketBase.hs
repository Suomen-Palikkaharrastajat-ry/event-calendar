module PocketBase (
    Event (..),
    GeoPoint (..),
    PbList (..),
    fetchPublishedEvents,
    imageUrl,
) where

import Data.Aeson (FromJSON (..), eitherDecode, withObject, (.:), (.:?))
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime)
import Network.HTTP.Simple (getResponseBody, getResponseStatusCode, httpLBS, parseRequest)
import System.Environment (lookupEnv)

-- | Production base URL for the PocketBase instance.
-- Used for image URLs in generated output (always points to production).
pbBaseUrl :: String
pbBaseUrl = "https://data.suomenpalikkayhteiso.fi"

-- | Resolve the effective PocketBase base URL for fetching events.
-- Honours the POCKETBASE_URL environment variable when set, so the statics
-- generator can target a local devenv PocketBase without source changes:
--
--   POCKETBASE_URL=http://127.0.0.1:8090 make statics   -- local devenv
--   make statics                                          -- production (default)
getPbBaseUrl :: IO String
getPbBaseUrl = do
    mUrl <- lookupEnv "POCKETBASE_URL"
    return $ case mUrl of
        Just url | not (null url) -> url
        _ -> pbBaseUrl

-- | A geographic point (latitude/longitude).
data GeoPoint = GeoPoint
    { geoLat :: Double
    , geoLon :: Double
    }
    deriving (Show, Eq)

instance FromJSON GeoPoint where
    parseJSON = withObject "GeoPoint" $ \o ->
        GeoPoint
            <$> o .: "lat"
            <*> o .: "lon"

-- | A PocketBase event record.
data Event = Event
    { eventId :: String
    , eventTitle :: Text
    , eventDescription :: Maybe Text
    , eventStartDate :: UTCTime
    , eventEndDate :: Maybe UTCTime
    , eventAllDay :: Bool
    , eventUrl :: Maybe Text
    , eventLocation :: Maybe Text
    , eventState :: Text -- "draft"|"pending"|"published"|"deleted"
    , eventImage :: Maybe Text -- filename only
    , eventImageDesc :: Maybe Text
    , eventPoint :: Maybe GeoPoint
    , eventCreated :: UTCTime
    , eventUpdated :: UTCTime
    }
    deriving (Show)

instance FromJSON Event where
    parseJSON = withObject "Event" $ \o ->
        Event
            <$> o .: "id"
            <*> o .: "title"
            <*> (nullableText <$> o .:? "description")
            <*> o .: "start_date"
            <*> o .:? "end_date"
            <*> o .: "all_day"
            <*> (nullableText <$> o .:? "url")
            <*> (nullableText <$> o .:? "location")
            <*> o .: "state"
            <*> (nullableText <$> o .:? "image")
            <*> (nullableText <$> o .:? "image_description")
            <*> o .:? "point"
            <*> o .: "created"
            <*> o .: "updated"

-- | Convert empty strings to Nothing (PocketBase returns "" for optional fields).
nullableText :: Maybe Text -> Maybe Text
nullableText (Just t)
    | T.null t = Nothing
    | otherwise = Just t
nullableText Nothing = Nothing

-- | PocketBase list response wrapper.
data PbList a = PbList
    { pbItems :: [a]
    , pbTotalItems :: Int
    , pbPage :: Int
    , pbPerPage :: Int
    }
    deriving (Show)

instance (FromJSON a) => FromJSON (PbList a) where
    parseJSON = withObject "PbList" $ \o ->
        PbList
            <$> o .: "items"
            <*> o .: "totalItems"
            <*> o .: "page"
            <*> o .: "perPage"

{- | Fetch all published events from PocketBase.
Uses perPage=500; paginates if needed.
Respects the POCKETBASE_URL environment variable (see getPbBaseUrl).
-}
fetchPublishedEvents :: IO [Event]
fetchPublishedEvents = do
    baseUrl <- getPbBaseUrl
    putStrLn $ "Using PocketBase URL: " ++ baseUrl
    fetchPage baseUrl (1 :: Int) []
  where
    fetchPage baseUrl page acc = do
        let url =
                baseUrl
                    ++ "/api/collections/events/records"
                    ++ "?filter="
                    ++ urlEncode "(state=\"published\")"
                    ++ "&sort=start_date"
                    ++ "&perPage=500"
                    ++ "&page="
                    ++ show page
        req <- parseRequest ("GET " ++ url)
        resp <- httpLBS req
        let status = getResponseStatusCode resp
        if status /= 200
            then do
                putStrLn $ "Warning: PocketBase returned status " ++ show status
                return acc
            else do
                let body = getResponseBody resp
                case eitherDecode body :: Either String (PbList Event) of
                    Left err -> do
                        putStrLn $ "Warning: Failed to decode events: " ++ err
                        return acc
                    Right pbList -> do
                        let events = acc ++ pbItems pbList
                        let total = pbTotalItems pbList
                        let fetched = length events
                        if fetched < total
                            then fetchPage baseUrl (page + 1) events
                            else return events

-- | Build the full URL for an event image.
imageUrl :: Event -> Text -> String
imageUrl ev filename =
    pbBaseUrl
        ++ "/api/files/events/"
        ++ eventId ev
        ++ "/"
        ++ T.unpack filename

-- | Minimal URL percent-encoding for PocketBase filter strings.
urlEncode :: String -> String
urlEncode = concatMap encodeChar
  where
    encodeChar c
        | c `elem` ("-_.~" :: String) || isAlphaNum c = [c]
        | otherwise = '%' : hexByte (fromEnum c)
    hexByte n =
        let (q, r) = n `divMod` 16
         in [hexDigit q, hexDigit r]
    hexDigit n
        | n < 10 = toEnum (fromEnum '0' + n)
        | otherwise = toEnum (fromEnum 'A' + n - 10)
    isAlphaNum c =
        (c >= 'a' && c <= 'z')
            || (c >= 'A' && c <= 'Z')
            || (c >= '0' && c <= '9')
