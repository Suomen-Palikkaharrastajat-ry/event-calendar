module Geocoding exposing
    ( decodeGeocodeResponse
    , decodeReverseGeocode
    , geocode
    , reverseGeocode
    )

import Http
import Json.Decode as Json exposing (Decoder)
import Types exposing (GeoPoint, Msg(..))
import Url


nominatimBase : String
nominatimBase =
    "https://nominatim.openstreetmap.org"


userAgent : Http.Header
userAgent =
    Http.header "User-Agent" "SuomenPalikkayhteiso-Kalenteri/1.0"


{-| Geocode a location name to coordinates via Nominatim.
-}
geocode : String -> (Result Http.Error (Maybe GeoPoint) -> Msg) -> Cmd Msg
geocode locationName toMsg =
    Http.request
        { method = "GET"
        , headers = [ userAgent ]
        , url =
            nominatimBase
                ++ "/search"
                ++ "?q="
                ++ Url.percentEncode locationName
                ++ "&format=json&limit=1"
        , body = Http.emptyBody
        , expect = Http.expectJson toMsg decodeGeocodeResponse
        , timeout = Just 10000
        , tracker = Nothing
        }


{-| Reverse geocode coordinates to a place name via Nominatim.
-}
reverseGeocode : Float -> Float -> (Result Http.Error String -> Msg) -> Cmd Msg
reverseGeocode lat lon toMsg =
    Http.request
        { method = "GET"
        , headers = [ userAgent ]
        , url =
            nominatimBase
                ++ "/reverse"
                ++ "?lat="
                ++ String.fromFloat lat
                ++ "&lon="
                ++ String.fromFloat lon
                ++ "&format=json"
        , body = Http.emptyBody
        , expect = Http.expectJson toMsg decodeReverseGeocode
        , timeout = Just 10000
        , tracker = Nothing
        }



-- DECODERS


decodeGeocodeResponse : Decoder (Maybe GeoPoint)
decodeGeocodeResponse =
    Json.list decodeGeocodingResult
        |> Json.map
            (List.head
                >> Maybe.map (\r -> { lat = r.lat, lon = r.lon })
            )


type alias GeocodingResult =
    { lat : Float
    , lon : Float
    , displayName : String
    }


decodeGeocodingResult : Decoder GeocodingResult
decodeGeocodingResult =
    Json.map3 GeocodingResult
        (Json.field "lat" decodeStringFloat)
        (Json.field "lon" decodeStringFloat)
        (Json.field "display_name" Json.string)


{-| Nominatim returns lat/lon as strings, not numbers.
-}
decodeStringFloat : Decoder Float
decodeStringFloat =
    Json.string
        |> Json.andThen
            (\s ->
                case String.toFloat s of
                    Just f ->
                        Json.succeed f

                    Nothing ->
                        Json.fail ("Expected a float string, got: " ++ s)
            )


decodeReverseGeocode : Decoder String
decodeReverseGeocode =
    Json.field "display_name" Json.string
