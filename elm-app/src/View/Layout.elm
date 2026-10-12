module View.Layout exposing (viewBrandFooter, viewFooter, viewHeader, viewMobileDrawer, viewMobileOverlay, viewToasts)

{-| Page chrome: header, mobile drawer, footers and toasts.
-}

import Component.Button as Button
import Component.FeedLinks as FeedLinks
import Component.Footer as Footer
import Component.Footer.Family as Family
import Component.MobileDrawer as MobileDrawer
import Component.Navbar as Navbar
import Component.Toast as Toast
import FeatherIcons
import Html exposing (Html, div, nav, span, text, ul)
import Html.Attributes exposing (attribute, class)
import I18n exposing (MsgKey(..), t)
import Route exposing (Route(..), toHref)
import Types exposing (AuthState(..), AuthUser, Msg(..), Toast, ToastKind(..))


viewHeader : AuthState -> Bool -> Maybe Route -> Html Msg
viewHeader authState menuOpen activeRoute =
    let
        isActive route =
            Just route == activeRoute
    in
    Navbar.viewAppHeader
        { brand =
            Navbar.viewBrand
                { href = toHref (RouteCalendar Nothing)
                , iconSrc = "/logo/square/square-smile.svg"
                , title = t NavbarTitle
                , onClick = Nothing
                }
        , navLabel = t A11yNavMain
        , links =
            [ { label = t NavHome
              , href = toHref (RouteCalendar Nothing)
              , mobileOnly = False
              , isActive = isActive (RouteCalendar Nothing)
              }
            , { label = t NavEvents
              , href = toHref RouteEvents
              , mobileOnly = False
              , isActive = isActive RouteEvents
              }
            ]
        , trailing =
            [ viewDesktopAuthControls authState ]
        , menuToggle =
            Just
                (Navbar.viewMenuToggle
                    { isOpen = menuOpen
                    , onToggle = ToggleMenu
                    , controls = "mobile-nav"
                    , openLabel = "Avaa valikko"
                    , closeLabel = "Sulje valikko"
                    }
                )
        , sticky = True
        }


viewDesktopAuthControls : AuthState -> Html Msg
viewDesktopAuthControls authState =
    case authState of
        NotAuthenticated ->
            div [ class "hidden md:flex gap-2 items-center" ]
                [ authButton LoginClicked (t LoginButton) ]

        Authenticated user ->
            div [ class "hidden md:flex gap-2 items-center" ]
                [ span [ class "type-caption text-white/80" ] [ text user.name ]
                , span [ attribute "title" (userTooltip user), class "inline-flex" ]
                    [ authButton LogOut (t LogoutButton) ]
                ]


viewMobileAuthControls : AuthState -> Html Msg
viewMobileAuthControls authState =
    case authState of
        NotAuthenticated ->
            div [ class "flex" ]
                [ authButton LoginClicked (t LoginButton) ]

        Authenticated user ->
            div [ class "flex flex-col items-start gap-3" ]
                [ span [ class "type-caption text-text-muted" ] [ text user.name ]
                , span [ attribute "title" (userTooltip user), class "inline-flex" ]
                    [ authButton LogOut (t LogoutButton) ]
                ]


authButton : Msg -> String -> Html Msg
authButton msg label =
    Button.new { label = label, onClick = msg }
        |> Button.withVariant Button.Primary
        |> Button.withSize Button.Small
        |> Button.toHtml


userTooltip : AuthUser -> String
userTooltip user =
    let
        namePart =
            String.trim user.name

        emailPart =
            String.trim user.email
    in
    if String.isEmpty namePart then
        "Kirjautunut: " ++ emailPart

    else if String.isEmpty emailPart then
        "Kirjautunut: " ++ namePart

    else
        "Kirjautunut: " ++ namePart ++ " (" ++ emailPart ++ ")"


viewFooter : Html Msg
viewFooter =
    let
        siteUrl =
            "https://kalenteri.palikkaharrastajat.fi"
    in
    FeedLinks.view
        { label = t A11yFeedLinks
        , newTabHint = t NewTabHint
        , cards =
            [ { icon = FeatherIcons.calendar
              , title = "iCalendar"
              , description = "Kalenterivienti (ICS) tilaa tai integroi koko kalenterin helposti. Klikkaa kalenteri puhelimeesi!"
              , href = "webcal://kalenteri.palikkaharrastajat.fi/kalenteri.ics"
              }
            , { icon = FeatherIcons.fileText
              , title = "HTML | PDF"
              , description = "Upota tai tulosta valmis tapahtumalistaus. Sisältää kalenterilinkit yksittäisiin tapahtumiin."
              , href = siteUrl ++ "/kalenteri.html"
              }
            ]
        , feeds =
            Just
                { icon = FeatherIcons.rss
                , title = "Syötteet"
                , description = "Syötteet integroivat uudet tapahtumat verkkosivuille. Nämäkin sisältävät kalenterilinkit."
                , links =
                    [ { label = "ATOM", href = siteUrl ++ "/kalenteri.atom" }
                    , { label = "RSS", href = siteUrl ++ "/kalenteri.rss" }
                    , { label = "JSON", href = siteUrl ++ "/kalenteri.json" }
                    , { label = "GeoJSON", href = siteUrl ++ "/kalenteri.geo.json" }
                    ]
                }
        }


viewToasts : List Toast -> Html Msg
viewToasts toasts =
    Toast.region
        { label = t ToastRegionLabel
        , closeLabel = t ToastClose
        }
        (List.map toSharedToast toasts)


toSharedToast : Toast -> Toast.Toast Msg
toSharedToast toast =
    { id = String.fromInt toast.id
    , title = Nothing
    , body = toast.message
    , variant =
        case toast.kind of
            ToastSuccess ->
                Toast.Success

            ToastError ->
                Toast.Danger

            ToastInfo ->
                Toast.Default
    , onClose = Just (DismissToast toast.id)
    }


viewMobileOverlay : Bool -> Html Msg
viewMobileOverlay menuOpen =
    MobileDrawer.viewOverlay { isOpen = menuOpen, onClose = CloseMenu, breakpoint = MobileDrawer.Md }


viewMobileDrawer : Bool -> Maybe Route -> AuthState -> Html Msg
viewMobileDrawer menuOpen activeRoute authState =
    let
        isActive route =
            Just route == activeRoute
    in
    MobileDrawer.view
        { isOpen = menuOpen
        , id = "mobile-nav"
        , label = t A11yNavMobile
        , onClose = CloseMenu
        , breakpoint = MobileDrawer.Md
        , content =
            [ nav [ class "p-4", attribute "aria-label" (t A11yNavMain) ]
                [ ul [ class "flex flex-col gap-1 list-none m-0 p-0" ]
                    [ MobileDrawer.viewNavLink { href = toHref (RouteCalendar Nothing), label = t NavHome, isActive = isActive (RouteCalendar Nothing), onClose = CloseMenu }
                    , MobileDrawer.viewNavLink { href = toHref RouteEvents, label = t NavEvents, isActive = isActive RouteEvents, onClose = CloseMenu }
                    ]
                ]
            , div [ class "p-4 border-t border-border-default" ]
                [ viewMobileAuthControls authState ]
            ]
        }


viewBrandFooter : Html Msg
viewBrandFooter =
    Footer.viewWith
        { topMargin = False
        , extra = []
        }
        { logo = Just Family.logo
        , siteLabel = Just "Palikkaharrastajat"
        , links =
            [ { label = "Kotisivut", href = "https://palikkaharrastajat.fi" }
            , { label = "Palikkakalenteri", href = "https://kalenteri.palikkaharrastajat.fi" }
            , { label = "Palikkalinkit", href = "https://linkit.palikkaharrastajat.fi" }
            ]
        , groups = []
        , copyright = Family.copyright 2026
        , disclaimer = Just Family.disclaimer
        }
