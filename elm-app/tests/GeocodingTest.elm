module GeocodingTest exposing (suite)

import Expect
import Geocoding exposing (decodeGeocodeResponse, decodeReverseGeocode)
import Json.Decode as Json
import Test exposing (Test, describe, test)


decodeJson : Json.Decoder a -> String -> Result Json.Error a
decodeJson decoder json =
    Json.decodeString decoder json


{-| Nominatim returns lat/lon as string-encoded floats, not numbers.
-}
singleResultJson : String
singleResultJson =
    """[{"lat":"60.1699","lon":"24.9384","display_name":"Helsinki, Finland"}]"""


emptyResultJson : String
emptyResultJson =
    """[]"""


reverseResultJson : String
reverseResultJson =
    """{"display_name":"Rautatientori, Helsinki, Finland","lat":"60.1699","lon":"24.9384"}"""


suite : Test
suite =
    describe "Geocoding"
        [ describe "decodeGeocodeResponse"
            [ test "decodes single result to Just GeoPoint" <|
                \_ ->
                    decodeJson decodeGeocodeResponse singleResultJson
                        |> Expect.equal (Ok (Just { lat = 60.1699, lon = 24.9384 }))
            , test "decodes empty list to Nothing" <|
                \_ ->
                    decodeJson decodeGeocodeResponse emptyResultJson
                        |> Expect.equal (Ok Nothing)
            , test "returns Err on completely invalid JSON" <|
                \_ ->
                    decodeJson decodeGeocodeResponse "not json"
                        |> Result.toMaybe
                        |> Expect.equal Nothing
            , test "returns Err when lat is not a float string" <|
                \_ ->
                    decodeJson decodeGeocodeResponse
                        """[{"lat":"not-a-float","lon":"24.9384","display_name":"Helsinki"}]"""
                        |> Result.toMaybe
                        |> Expect.equal Nothing
            , test "decodes multiple results, returns first as Just GeoPoint" <|
                \_ ->
                    decodeJson decodeGeocodeResponse
                        """[{"lat":"60.1699","lon":"24.9384","display_name":"Helsinki"},
                            {"lat":"61.0","lon":"25.0","display_name":"Other"}]"""
                        |> Expect.equal (Ok (Just { lat = 60.1699, lon = 24.9384 }))
            ]
        , describe "decodeReverseGeocode"
            [ test "extracts display_name" <|
                \_ ->
                    decodeJson decodeReverseGeocode reverseResultJson
                        |> Expect.equal (Ok "Rautatientori, Helsinki, Finland")
            , test "returns Err when display_name field is missing" <|
                \_ ->
                    decodeJson decodeReverseGeocode """{"lat":"60.1699"}"""
                        |> Result.toMaybe
                        |> Expect.equal Nothing
            , test "returns Err on invalid JSON" <|
                \_ ->
                    decodeJson decodeReverseGeocode "not json"
                        |> Result.toMaybe
                        |> Expect.equal Nothing
            ]
        ]
