module LayoutTest exposing (suite)

{-| Unit tests for page layout components (Layout.elm).
-}

import Component.Footer.Family as Family
import Component.SkipLink as SkipLink
import Expect
import Html exposing (div)
import Html.Attributes
import Route exposing (Route(..))
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import Types exposing (AuthState(..), Toast, ToastKind(..))
import View.Layout as Layout


suite : Test
suite =
    describe "View.Layout"
        [ describe "viewHeader"
            [ test "renders header element with brand title" <|
                \_ ->
                    Layout.viewHeader NotAuthenticated False (Just (RouteCalendar Nothing))
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "Palikkakalenteri" ]
            , test "renders navigation links" <|
                \_ ->
                    Layout.viewHeader NotAuthenticated False (Just (RouteCalendar Nothing))
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "Kalenteri", Selector.text "Tulevat tapahtumat" ]
            ]
        , describe "viewFooter"
            [ test "renders export panel as a section, not a footer" <|
                \_ ->
                    Layout.viewFooter
                        |> Query.fromHtml
                        |> Query.has [ Selector.tag "section" ]
            , test "contains export links" <|
                \_ ->
                    Layout.viewFooter
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "iCalendar", Selector.text "HTML | PDF", Selector.text "Syötteet" ]
            ]
        , describe "viewBrandFooter"
            [ test "renders footer element" <|
                \_ ->
                    Layout.viewBrandFooter
                        |> Query.fromHtml
                        |> Query.has [ Selector.tag "footer" ]
            , test "contains copyright" <|
                \_ ->
                    Layout.viewBrandFooter
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "© 2026 Suomen Palikkaharrastajat ry" ]
            , test "is the shared family footer, unmodified" <|
                \_ ->
                    Layout.viewBrandFooter
                        |> Expect.equal
                            (Family.view
                                { currentSite = "https://kalenteri.palikkaharrastajat.fi"
                                , year = 2026
                                , topMargin = False
                                , extra = []
                                }
                            )
            , test "links to every other family site and not to itself" <|
                \_ ->
                    Layout.viewBrandFooter
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "ul" ]
                        |> Expect.all
                            [ Query.findAll [ Selector.tag "a" ]
                                >> Query.count (Expect.equal (List.length Family.links - 1))
                            , Query.hasNot
                                [ Selector.attribute (Html.Attributes.href "https://kalenteri.palikkaharrastajat.fi") ]
                            ]
            ]
        , describe "Landmark count"
            [ test "layout has exactly one footer landmark" <|
                \_ ->
                    div []
                        [ Layout.viewHeader NotAuthenticated False Nothing
                        , Layout.viewFooter
                        , Layout.viewBrandFooter
                        ]
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.tag "footer" ]
                        |> Query.count (Expect.equal 1)
            ]
        , describe "SkipLink"
            [ test "renders skip link targeting main-content" <|
                \_ ->
                    SkipLink.view { target = "main-content", label = "Hyppää pääsisältöön" }
                        |> Query.fromHtml
                        |> Query.has
                            [ Selector.attribute (Html.Attributes.href "#main-content")
                            , Selector.text "Hyppää pääsisältöön"
                            ]
            ]
        , describe "viewToasts"
            [ test "renders region landmark for notifications" <|
                \_ ->
                    let
                        toasts : List Toast
                        toasts =
                            [ { id = 1, message = "Tapahtuma tallennettu", kind = ToastSuccess } ]
                    in
                    Layout.viewToasts toasts
                        |> Query.fromHtml
                        |> Query.has
                            [ Selector.attribute (Html.Attributes.attribute "role" "region")
                            , Selector.text "Tapahtuma tallennettu"
                            ]
            ]
        , describe "viewMobileDrawer"
            [ test "renders mobile drawer nav links" <|
                \_ ->
                    Layout.viewMobileDrawer True (Just (RouteCalendar Nothing)) NotAuthenticated
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "Kalenteri", Selector.text "Tulevat tapahtumat" ]
            , test "renders dialog role for mobile menu" <|
                \_ ->
                    Layout.viewMobileDrawer True Nothing NotAuthenticated
                        |> Query.fromHtml
                        |> Query.has [ Selector.attribute (Html.Attributes.attribute "role" "dialog") ]
            ]
        , describe "Authenticated header"
            [ test "renders user display name when authenticated" <|
                \_ ->
                    let
                        user =
                            { id = "u1", email = "test@example.com", name = "Matti Meikäläinen", token = "tok" }
                    in
                    Layout.viewHeader (Authenticated user) False Nothing
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "Matti Meikäläinen" ]
            ]
        ]
