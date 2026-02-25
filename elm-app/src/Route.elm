module Route exposing (Route(..), parseUrl, toHref)

import Url exposing (Url)
import Url.Parser exposing (Parser, (</>), (<?>) )
import Url.Parser.Query as Query


type Route
    = RouteCalendar (Maybe String)
    | RouteEvents
    | RouteEventNew
    | RouteEventDetail String
    | RouteEventEdit String
    | RouteAuthCallback
    | RouteNotFound


routeParser : Parser (Route -> a) a
routeParser =
    Url.Parser.oneOf
        [ Url.Parser.map RouteCalendar
            (Url.Parser.top <?> Query.string "date")
        , Url.Parser.map RouteEvents
            (Url.Parser.s "events")
          -- RouteEventNew must come before RouteEventDetail to avoid "new" parsed as ID
        , Url.Parser.map RouteEventNew
            (Url.Parser.s "events" </> Url.Parser.s "new")
        , Url.Parser.map RouteEventEdit
            (Url.Parser.s "events" </> Url.Parser.string </> Url.Parser.s "edit")
        , Url.Parser.map RouteEventDetail
            (Url.Parser.s "events" </> Url.Parser.string)
        , Url.Parser.map RouteAuthCallback
            (Url.Parser.s "callback")
        ]


{-| Parse an Elm Browser.application URL into a Route.

The app uses hash routing: the URL fragment is the "path" the app cares about.
Example: <https://example.com/#/events/abc123>
  → url.fragment = Just "/events/abc123"

We extract the fragment and split it into path + query before parsing.
-}
parseUrl : Url -> Route
parseUrl url =
    let
        fragment =
            Maybe.withDefault "/" url.fragment

        ( path, query ) =
            case String.split "?" fragment of
                p :: q :: _ ->
                    ( p, Just q )

                p :: _ ->
                    ( p, Nothing )

                [] ->
                    ( "/", Nothing )

        pseudoUrl =
            { url | path = path, fragment = Nothing, query = query }
    in
    pseudoUrl
        |> Url.Parser.parse routeParser
        |> Maybe.withDefault RouteNotFound


{-| Convert a Route to a hash-based href string (e.g. "#/events/abc123").
-}
toHref : Route -> String
toHref route =
    "#"
        ++ (case route of
                RouteCalendar Nothing ->
                    "/"

                RouteCalendar (Just date) ->
                    "/?date=" ++ date

                RouteEvents ->
                    "/events"

                RouteEventNew ->
                    "/events/new"

                RouteEventDetail id ->
                    "/events/" ++ id

                RouteEventEdit id ->
                    "/events/" ++ id ++ "/edit"

                RouteAuthCallback ->
                    "/callback"

                RouteNotFound ->
                    "/404"
           )
