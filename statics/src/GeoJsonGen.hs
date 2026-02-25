{- | GeoJSON FeatureCollection generation for events with coordinates.
Uses aeson for correct JSON encoding.
-}
module GeoJsonGen (
    generateGeoJson,
) where

import Data.Aeson (Value (..), encode, object, toJSON, (.=))
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Encoding as TLE
import Data.Time (UTCTime)
import Data.Time.Format (defaultTimeLocale, formatTime)
import qualified ICalGen
import qualified PocketBase as PB

-- | Format an optional UTCTime as RFC 3339 JSON value.
toRfc3339 :: Maybe UTCTime -> Value
toRfc3339 Nothing = Null
toRfc3339 (Just t) = toJSON (formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ" t)

-- | Build a GeoJSON Feature for an event that has coordinates.
eventToFeature :: Map.Map String String -> PB.Event -> Maybe Value
eventToFeature icsMap ev = case PB.eventPoint ev of
    Nothing -> Nothing
    Just pt ->
        let ics = Map.findWithDefault "" (PB.eventId ev) icsMap
         in Just $
                object
                    [ "type" .= ("Feature" :: String)
                    , "geometry"
                        .= object
                            [ "type" .= ("Point" :: String)
                            , -- GeoJSON coordinate order: [longitude, latitude]
                              "coordinates" .= toJSON [PB.geoLon pt, PB.geoLat pt]
                            ]
                    , "properties"
                        .= object
                            [ "id" .= PB.eventId ev
                            , "title" .= T.unpack (PB.eventTitle ev)
                            , "description" .= maybe Null (toJSON . T.unpack) (PB.eventDescription ev)
                            , "start" .= formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ" (PB.eventStartDate ev)
                            , "end" .= toRfc3339 (PB.eventEndDate ev)
                            , "all_day" .= PB.eventAllDay ev
                            , "location" .= maybe Null (toJSON . T.unpack) (PB.eventLocation ev)
                            , "url" .= maybe Null (toJSON . T.unpack) (PB.eventUrl ev)
                            , "ics" .= ics
                            ]
                    ]

-- | Generate a GeoJSON FeatureCollection for events with coordinates.
generateGeoJson :: [PB.Event] -> IO String
generateGeoJson events = do
    -- Pre-generate per-event ICS strings; keyed by event ID
    icsMap <- Map.fromList <$> mapM buildIcs events
    let features = [f | ev <- events, Just f <- [eventToFeature icsMap ev]]
    return $
        TL.unpack $
            TLE.decodeUtf8 $
                encode $
                    object
                        [ "type" .= ("FeatureCollection" :: String)
                        , "features" .= features
                        ]
  where
    buildIcs ev = do
        ics <- ICalGen.generateEventIcs ev
        return (PB.eventId ev, ics)
