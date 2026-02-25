-- | Downloads event images concurrently from PocketBase.
module ImageFetcher (
    downloadAllImages,
    downloadImage,
) where

import Control.Concurrent.Async (mapConcurrently)
import qualified Data.ByteString.Lazy as BL
import Data.Maybe (catMaybes)
import qualified Data.Text as T
import Network.HTTP.Simple (getResponseBody, getResponseStatusCode, httpLBS, parseRequest)
import qualified PocketBase as PB

{- | Download all event images concurrently.
Returns a list of (eventId, localFilePath) pairs for events with images.
-}
downloadAllImages :: [PB.Event] -> IO [(String, FilePath)]
downloadAllImages events = do
    let eventsWithImages = [(ev, T.unpack img) | ev <- events, Just img <- [PB.eventImage ev]]
    results <- mapConcurrently (uncurry downloadImage) eventsWithImages
    return (catMaybes results)

{- | Download a single event image.
Returns Nothing on failure (logs warning but does not abort).
-}
downloadImage :: PB.Event -> String -> IO (Maybe (String, FilePath))
downloadImage ev filename = do
    let url = PB.imageUrl ev (T.pack filename)
        dest = "static/images/" ++ PB.eventId ev ++ "_" ++ filename
    result <- try' (fetchAndWrite url dest)
    case result of
        Left err -> do
            putStrLn $ "Warning: Failed to download image for " ++ PB.eventId ev ++ ": " ++ err
            return Nothing
        Right () ->
            return (Just (PB.eventId ev, dest))
  where
    try' :: IO () -> IO (Either String ())
    try' action = fmap Right action

fetchAndWrite :: String -> FilePath -> IO ()
fetchAndWrite url dest = do
    req <- parseRequest ("GET " ++ url)
    resp <- httpLBS req
    let status = getResponseStatusCode resp
    if status == 200
        then BL.writeFile dest (getResponseBody resp)
        else putStrLn $ "Warning: HTTP " ++ show status ++ " for " ++ url
