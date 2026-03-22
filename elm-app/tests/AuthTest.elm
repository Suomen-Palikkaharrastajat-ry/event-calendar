module AuthTest exposing (suite)

import Auth exposing (decodeAuthUser, restoreAuthFromFlags)
import Expect
import Json.Decode as Json
import Test exposing (Test, describe, test)
import Types exposing (AuthState(..))


decodeJson : Json.Decoder a -> String -> Result Json.Error a
decodeJson decoder json =
    Json.decodeString decoder json


{-| Minimal valid user JSON as stored in localStorage by the app.
-}
userJson : String
userJson =
    """{"id":"user1","name":"Testi Käyttäjä","email":"testi@example.com"}"""


suite : Test
suite =
    describe "Auth"
        [ describe "decodeAuthUser"
            [ test "decodes id" <|
                \_ ->
                    decodeJson decodeAuthUser userJson
                        |> Result.map .id
                        |> Expect.equal (Ok "user1")
            , test "decodes name" <|
                \_ ->
                    decodeJson decodeAuthUser userJson
                        |> Result.map .name
                        |> Expect.equal (Ok "Testi Käyttäjä")
            , test "decodes email" <|
                \_ ->
                    decodeJson decodeAuthUser userJson
                        |> Result.map .email
                        |> Expect.equal (Ok "testi@example.com")
            , test "token defaults to empty string (set later from localStorage)" <|
                \_ ->
                    decodeJson decodeAuthUser userJson
                        |> Result.map .token
                        |> Expect.equal (Ok "")
            , test "returns Err when required field id is missing" <|
                \_ ->
                    decodeJson decodeAuthUser """{"name":"x","email":"x@x.fi"}"""
                        |> Result.toMaybe
                        |> Expect.equal Nothing
            , test "returns Err on invalid JSON" <|
                \_ ->
                    decodeJson decodeAuthUser "not json"
                        |> Result.toMaybe
                        |> Expect.equal Nothing
            ]
        , describe "restoreAuthFromFlags"
            [ test "returns Authenticated with correct token when both values are valid" <|
                \_ ->
                    restoreAuthFromFlags (Just "my-token") (Just userJson)
                        |> (\auth ->
                                case auth of
                                    Authenticated user ->
                                        user.token == "my-token" && user.id == "user1"

                                    NotAuthenticated ->
                                        False
                           )
                        |> Expect.equal True
            , test "token in result comes from the first argument, not the JSON" <|
                \_ ->
                    restoreAuthFromFlags (Just "tok-abc") (Just userJson)
                        |> (\auth ->
                                case auth of
                                    Authenticated user ->
                                        user.token

                                    NotAuthenticated ->
                                        ""
                           )
                        |> Expect.equal "tok-abc"
            , test "returns NotAuthenticated when token is Nothing" <|
                \_ ->
                    restoreAuthFromFlags Nothing (Just userJson)
                        |> Expect.equal NotAuthenticated
            , test "returns NotAuthenticated when model JSON is Nothing" <|
                \_ ->
                    restoreAuthFromFlags (Just "my-token") Nothing
                        |> Expect.equal NotAuthenticated
            , test "returns NotAuthenticated when both are Nothing" <|
                \_ ->
                    restoreAuthFromFlags Nothing Nothing
                        |> Expect.equal NotAuthenticated
            , test "returns NotAuthenticated when model JSON is malformed" <|
                \_ ->
                    restoreAuthFromFlags (Just "my-token") (Just "not valid json")
                        |> Expect.equal NotAuthenticated
            ]
        ]
