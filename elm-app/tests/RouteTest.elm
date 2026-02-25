module RouteTest exposing (suite)

import Expect
import Route exposing (Route(..), parseUrl, toHref)
import Test exposing (Test, describe, test)
import Url


{-| Helper to parse a full URL string via parseUrl. -}
parse : String -> Route
parse urlStr =
    case Url.fromString ("http://localhost" ++ urlStr) of
        Just url ->
            parseUrl url

        Nothing ->
            RouteNotFound


suite : Test
suite =
    describe "Route"
        [ describe "parseUrl"
            [ test "root → RouteCalendar Nothing" <|
                \_ ->
                    parse "#/"
                        |> Expect.equal (RouteCalendar Nothing)
            , test "with date → RouteCalendar (Just date)" <|
                \_ ->
                    parse "#/?date=2025-05-01"
                        |> Expect.equal (RouteCalendar (Just "2025-05-01"))
            , test "/events → RouteEvents" <|
                \_ ->
                    parse "#/events"
                        |> Expect.equal RouteEvents
            , test "/events/new → RouteEventNew (not detail)" <|
                \_ ->
                    parse "#/events/new"
                        |> Expect.equal RouteEventNew
            , test "/events/abc123 → RouteEventDetail" <|
                \_ ->
                    parse "#/events/abc123"
                        |> Expect.equal (RouteEventDetail "abc123")
            , test "/events/abc123/edit → RouteEventEdit" <|
                \_ ->
                    parse "#/events/abc123/edit"
                        |> Expect.equal (RouteEventEdit "abc123")
            , test "/callback → RouteAuthCallback" <|
                \_ ->
                    parse "#/callback"
                        |> Expect.equal RouteAuthCallback
            , test "/nonexistent → RouteNotFound" <|
                \_ ->
                    parse "#/nonexistent/path/that/does/not/exist"
                        |> Expect.equal RouteNotFound
            ]
        , describe "toHref"
            [ test "RouteCalendar Nothing" <|
                \_ -> toHref (RouteCalendar Nothing) |> Expect.equal "#/"
            , test "RouteCalendar (Just date)" <|
                \_ -> toHref (RouteCalendar (Just "2025-05-01")) |> Expect.equal "#/?date=2025-05-01"
            , test "RouteEvents" <|
                \_ -> toHref RouteEvents |> Expect.equal "#/events"
            , test "RouteEventNew" <|
                \_ -> toHref RouteEventNew |> Expect.equal "#/events/new"
            , test "RouteEventDetail" <|
                \_ -> toHref (RouteEventDetail "abc") |> Expect.equal "#/events/abc"
            , test "RouteEventEdit" <|
                \_ -> toHref (RouteEventEdit "abc") |> Expect.equal "#/events/abc/edit"
            ]
        ]
