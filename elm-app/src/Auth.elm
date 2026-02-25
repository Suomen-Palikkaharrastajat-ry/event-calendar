module Auth exposing
    ( restoreAuthFromFlags
    , decodeAuthUser
    , fetchOAuthToken
    )

import Http
import Json.Decode as Json exposing (Decoder)
import Json.Encode as Encode
import Types exposing (AuthState(..), AuthUser, Msg(..))


pbBaseUrl : String
pbBaseUrl =
    "https://data.suomenpalikkayhteiso.fi"


-- DECODERS


decodeAuthUser : Decoder AuthUser
decodeAuthUser =
    Json.map4 AuthUser
        (Json.field "id" Json.string)
        (Json.field "name" Json.string)
        (Json.field "email" Json.string)
        (Json.succeed "")


{-| Restore auth state from localStorage flags passed on init.
Returns NotAuthenticated if either value is missing or malformed.
-}
restoreAuthFromFlags : Maybe String -> Maybe String -> AuthState
restoreAuthFromFlags maybeToken maybeModelJson =
    case ( maybeToken, maybeModelJson ) of
        ( Just token, Just modelJson ) ->
            case Json.decodeString decodeAuthUser modelJson of
                Ok user ->
                    Authenticated { user | token = token }

                Err _ ->
                    NotAuthenticated

        _ ->
            NotAuthenticated


-- OAUTH


{-| Exchange OAuth2 code + codeVerifier for a PocketBase auth token. -}
fetchOAuthToken : String -> String -> String -> Cmd Msg
fetchOAuthToken code codeVerifier state =
    Http.post
        { url = pbBaseUrl ++ "/api/collections/users/auth-with-oauth2"
        , body =
            Http.jsonBody
                (Encode.object
                    [ ( "provider", Encode.string "oidc" )
                    , ( "code", Encode.string code )
                    , ( "codeVerifier", Encode.string codeVerifier )
                    , ( "redirectUrl", Encode.string (pbBaseUrl ++ "/#/callback") )
                    , ( "state", Encode.string state )
                    ]
                )
        , expect = Http.expectJson GotAuthResult decodeAuthUserResponse
        }


decodeAuthUserResponse : Decoder AuthUser
decodeAuthUserResponse =
    Json.map2 (\token user -> { user | token = token })
        (Json.field "token" Json.string)
        (Json.field "record" decodeAuthUser)
