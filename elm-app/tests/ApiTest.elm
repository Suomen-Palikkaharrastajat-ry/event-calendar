module ApiTest exposing (suite)

import Api exposing (decodeEvent, httpErrorToString, imageUrl)
import Expect
import Http
import Json.Decode as Json
import Test exposing (Test, describe, test)
import Types exposing (EventState(..))


{-| Decode a JSON string using the given decoder.
Returns a Result so tests can pattern-match on Ok/Err.
-}
decodeJson : Json.Decoder a -> String -> Result Json.Error a
decodeJson decoder json =
    Json.decodeString decoder json


{-| A full valid event JSON from PocketBase (all fields present).
-}
timedEventJson : String
timedEventJson =
    """{"id":"abc123",
        "title":"Parkour Jam",
        "description":"Fun event",
        "start_date":"2026-05-05T11:00:00.000Z",
        "end_date":"2026-05-05T14:00:00.000Z",
        "all_day":false,
        "url":"https://example.com",
        "location":"Helsinki, Rautatientori",
        "state":"published",
        "image":"photo.jpg",
        "image_description":"Kuva tapahtumasta",
        "point":{"lat":60.1699,"lon":24.9384},
        "created":"2026-01-01T00:00:00.000Z",
        "updated":"2026-01-02T00:00:00.000Z"}"""


{-| All-day event with empty/null optional fields.
-}
allDayEventJson : String
allDayEventJson =
    """{"id":"def456",
        "title":"Kaupunkifestivaal",
        "description":"",
        "start_date":"2026-06-15T21:00:00.000Z",
        "end_date":null,
        "all_day":true,
        "url":"",
        "location":"",
        "state":"draft",
        "image":"",
        "image_description":"",
        "point":null,
        "created":"2026-01-01T00:00:00.000Z",
        "updated":"2026-01-02T00:00:00.000Z"}"""


suite : Test
suite =
    describe "Api"
        [ describe "decodeEvent"
            [ test "decodes id" <|
                \_ ->
                    decodeJson decodeEvent timedEventJson
                        |> Result.map .id
                        |> Expect.equal (Ok "abc123")
            , test "decodes title" <|
                \_ ->
                    decodeJson decodeEvent timedEventJson
                        |> Result.map .title
                        |> Expect.equal (Ok "Parkour Jam")
            , test "decodes description (non-empty → Just)" <|
                \_ ->
                    decodeJson decodeEvent timedEventJson
                        |> Result.map .description
                        |> Expect.equal (Ok (Just "Fun event"))
            , test "decodes description (empty string → Nothing)" <|
                \_ ->
                    decodeJson decodeEvent allDayEventJson
                        |> Result.map .description
                        |> Expect.equal (Ok Nothing)
            , test "decodes start_date" <|
                \_ ->
                    decodeJson decodeEvent timedEventJson
                        |> Result.map .startDate
                        |> Expect.equal (Ok "2026-05-05T11:00:00.000Z")
            , test "decodes end_date (present → Just)" <|
                \_ ->
                    decodeJson decodeEvent timedEventJson
                        |> Result.map .endDate
                        |> Expect.equal (Ok (Just "2026-05-05T14:00:00.000Z"))
            , test "decodes end_date (null → Nothing)" <|
                \_ ->
                    decodeJson decodeEvent allDayEventJson
                        |> Result.map .endDate
                        |> Expect.equal (Ok Nothing)
            , test "decodes all_day false" <|
                \_ ->
                    decodeJson decodeEvent timedEventJson
                        |> Result.map .allDay
                        |> Expect.equal (Ok False)
            , test "decodes all_day true" <|
                \_ ->
                    decodeJson decodeEvent allDayEventJson
                        |> Result.map .allDay
                        |> Expect.equal (Ok True)
            , test "decodes url (non-empty → Just)" <|
                \_ ->
                    decodeJson decodeEvent timedEventJson
                        |> Result.map .url
                        |> Expect.equal (Ok (Just "https://example.com"))
            , test "decodes url (empty string → Nothing)" <|
                \_ ->
                    decodeJson decodeEvent allDayEventJson
                        |> Result.map .url
                        |> Expect.equal (Ok Nothing)
            , test "decodes location (non-empty → Just)" <|
                \_ ->
                    decodeJson decodeEvent timedEventJson
                        |> Result.map .location
                        |> Expect.equal (Ok (Just "Helsinki, Rautatientori"))
            , test "decodes location (empty string → Nothing)" <|
                \_ ->
                    decodeJson decodeEvent allDayEventJson
                        |> Result.map .location
                        |> Expect.equal (Ok Nothing)
            , test "decodes state published" <|
                \_ ->
                    decodeJson decodeEvent timedEventJson
                        |> Result.map .state
                        |> Expect.equal (Ok Published)
            , test "decodes state draft" <|
                \_ ->
                    decodeJson decodeEvent allDayEventJson
                        |> Result.map .state
                        |> Expect.equal (Ok Draft)
            , test "decodes image (non-empty → Just)" <|
                \_ ->
                    decodeJson decodeEvent timedEventJson
                        |> Result.map .image
                        |> Expect.equal (Ok (Just "photo.jpg"))
            , test "decodes image (empty string → Nothing)" <|
                \_ ->
                    decodeJson decodeEvent allDayEventJson
                        |> Result.map .image
                        |> Expect.equal (Ok Nothing)
            , test "decodes point lat" <|
                \_ ->
                    decodeJson decodeEvent timedEventJson
                        |> Result.map (.point >> Maybe.map .lat)
                        |> Expect.equal (Ok (Just 60.1699))
            , test "decodes point lon" <|
                \_ ->
                    decodeJson decodeEvent timedEventJson
                        |> Result.map (.point >> Maybe.map .lon)
                        |> Expect.equal (Ok (Just 24.9384))
            , test "decodes point null → Nothing" <|
                \_ ->
                    decodeJson decodeEvent allDayEventJson
                        |> Result.map .point
                        |> Expect.equal (Ok Nothing)
            ]
        , describe "imageUrl"
            [ test "builds correct URL" <|
                \_ ->
                    imageUrl "https://data.suomenpalikkayhteiso.fi" "abc123" "photo.jpg"
                        |> Expect.equal
                            "https://data.suomenpalikkayhteiso.fi/api/files/events/abc123/photo.jpg"
            , test "builds correct URL for local instance" <|
                \_ ->
                    imageUrl "http://127.0.0.1:8090" "abc123" "photo.jpg"
                        |> Expect.equal
                            "http://127.0.0.1:8090/api/files/events/abc123/photo.jpg"
            ]
        , describe "httpErrorToString"
            [ test "BadUrl returns Finnish message" <|
                \_ ->
                    httpErrorToString (Http.BadUrl "http://bad")
                        |> String.startsWith "Virheellinen URL"
                        |> Expect.equal True
            , test "Timeout returns Finnish message" <|
                \_ ->
                    httpErrorToString Http.Timeout
                        |> Expect.equal "Pyyntö aikakatkaistiin"
            , test "NetworkError returns Finnish message" <|
                \_ ->
                    httpErrorToString Http.NetworkError
                        |> Expect.equal "Verkkovirhe"
            , test "BadStatus returns code in message" <|
                \_ ->
                    httpErrorToString (Http.BadStatus 404)
                        |> String.contains "404"
                        |> Expect.equal True
            ]
        ]
