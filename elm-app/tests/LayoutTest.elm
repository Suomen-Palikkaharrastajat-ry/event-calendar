module LayoutTest exposing (suite)

{-| Unit tests for the page chrome (View.Layout).

The shell is rendered from this app's own `config.toml` (SiteFixture), so the
tests cover what a visitor gets: brand, navigation, feed links and the family
footer.

-}

import Expect
import Html exposing (Html, div, main_, text)
import Html.Attributes as Attr
import Json.Decode as Decode
import Lang exposing (Lang(..))
import Route exposing (Route(..))
import SiteFixture
import SiteSettings exposing (SiteSettings)
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import Types exposing (AuthState(..), Msg, Toast, ToastKind(..))
import View.Layout as Layout


site : SiteSettings
site =
    Decode.decodeString SiteSettings.localizedDecoder SiteFixture.json
        |> Result.toMaybe
        |> Maybe.andThen (SiteSettings.forLang Fi)
        |> Maybe.withDefault (SiteSettings.placeholder Fi)


shell : AuthState -> List Toast -> Html Msg
shell authState toasts =
    div []
        (Layout.view
            { site = site
            , lang = Fi
            , authState = authState
            , menuOpen = True
            , activeRoute = Just (RouteCalendar Nothing)
            , toasts = toasts
            , main = main_ [ Attr.id "main-content" ] [ text "Sisältö" ]
            }
        )


page : Html Msg
page =
    shell NotAuthenticated []


suite : Test
suite =
    describe "View.Layout"
        [ test "config.toml resolves and decodes" <|
            \_ ->
                site.site.title
                    |> Expect.equal "Palikkakalenteri"
        , describe "header"
            [ test "renders the brand title from config.toml" <|
                \_ ->
                    page
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "header" ]
                        |> Query.has [ Selector.text "Palikkakalenteri" ]
            , test "renders navigation links" <|
                \_ ->
                    page
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "header" ]
                        |> Query.has [ Selector.text "Kalenteri", Selector.text "Tulevat tapahtumat" ]
            , test "renders user display name when authenticated" <|
                \_ ->
                    shell (Authenticated { id = "u1", email = "test@example.com", name = "Matti Meikäläinen", token = "tok" }) []
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "header" ]
                        |> Query.has [ Selector.text "Matti Meikäläinen" ]
            ]
        , describe "feed links"
            [ test "renders export panel as a section, not a footer" <|
                \_ ->
                    page
                        |> Query.fromHtml
                        |> Query.has [ Selector.tag "section", Selector.containing [ Selector.text "iCalendar" ] ]
            , test "contains export links" <|
                \_ ->
                    page
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "iCalendar", Selector.text "HTML | PDF", Selector.text "Syötteet" ]
            , test "links are built from the configured site URL" <|
                \_ ->
                    page
                        |> Query.fromHtml
                        |> Query.has
                            [ Selector.attribute (Attr.href "webcal://kalenteri.palikkaharrastajat.fi/kalenteri.ics")
                            , Selector.attribute (Attr.href "https://kalenteri.palikkaharrastajat.fi/kalenteri.atom")
                            ]
            ]
        , describe "footer"
            [ test "layout has exactly one footer landmark" <|
                \_ ->
                    page
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.tag "footer" ]
                        |> Query.count (Expect.equal 1)
            , test "contains copyright" <|
                \_ ->
                    page
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "footer" ]
                        |> Query.has [ Selector.text "© 2026 Suomen Palikkaharrastajat ry" ]
            , test "links to every other family site and not to itself" <|
                \_ ->
                    page
                        |> Query.fromHtml
                        |> Query.find [ Selector.tag "footer" ]
                        |> Query.find [ Selector.tag "ul" ]
                        |> Expect.all
                            [ Query.findAll [ Selector.tag "a" ] >> Query.count (Expect.equal 7)
                            , Query.has [ Selector.attribute (Attr.href "https://kartta.palikkaharrastajat.fi") ]
                            , Query.hasNot [ Selector.attribute (Attr.href "https://kalenteri.palikkaharrastajat.fi") ]
                            ]
            ]
        , describe "skip link"
            [ test "targets main-content" <|
                \_ ->
                    page
                        |> Query.fromHtml
                        |> Query.has [ Selector.attribute (Attr.href "#main-content"), Selector.id "main-content" ]
            ]
        , describe "toasts"
            [ test "renders region landmark for notifications" <|
                \_ ->
                    shell NotAuthenticated [ { id = 1, message = "Tapahtuma tallennettu", kind = ToastSuccess } ]
                        |> Query.fromHtml
                        |> Query.find [ Selector.attribute (Attr.attribute "role" "region") ]
                        |> Query.has [ Selector.text "Tapahtuma tallennettu" ]
            ]
        , describe "mobile drawer"
            [ test "renders dialog role with the nav links" <|
                \_ ->
                    page
                        |> Query.fromHtml
                        |> Query.find [ Selector.attribute (Attr.attribute "role" "dialog") ]
                        |> Query.has [ Selector.text "Kalenteri", Selector.text "Tulevat tapahtumat" ]
            ]
        ]
