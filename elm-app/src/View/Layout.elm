module View.Layout exposing (view)

{-| Page chrome: the shared family shell with this app's navigation, account
controls, feed links and toasts.
-}

import Component.Button as Button
import Component.FeedLinks as FeedLinks
import Component.Layout as Layout
import Component.Toast as Toast
import FeatherIcons
import Html exposing (Html, div, nav, span, text)
import Html.Attributes exposing (attribute, class)
import I18n exposing (MsgKey(..), t)
import Lang exposing (Lang)
import Route exposing (Route(..), toHref)
import SiteSettings exposing (SiteSettings)
import Types exposing (AuthState(..), AuthUser, Msg(..), Toast, ToastKind(..))
import UiStrings exposing (UiStrings)


{-| The whole page: `main` is the app's `<main id="main-content">`.
-}
view :
    { site : SiteSettings
    , lang : Lang
    , authState : AuthState
    , menuOpen : Bool
    , activeRoute : Maybe Route
    , toasts : List Toast
    , main : Html Msg
    }
    -> List (Html Msg)
view config =
    let
        lang =
            config.lang

        strings =
            UiStrings.forLang lang

        link route label =
            { label = label
            , href = toHref route
            , mobileOnly = False
            , isActive = Just route == config.activeRoute
            }
    in
    Layout.view
        { site = config.site
        , strings = strings
        , attributes = [ class "min-h-screen flex flex-col" ]
        , home = { href = toHref (RouteCalendar Nothing), onClick = Nothing }
        , links =
            [ link (RouteCalendar Nothing) (t lang NavHome)
            , link RouteEvents (t lang NavEvents)
            ]
        , headerActions = [ viewDesktopAuthControls lang config.authState ]
        , showHeader = True
        , menu =
            Just
                { isOpen = config.menuOpen
                , onToggle = ToggleMenu
                , onClose = CloseMenu
                , content =
                    \links ->
                        [ nav [ class "p-4", attribute "aria-label" strings.mainNav ] [ links ]
                        , div [ class "p-4 border-t border-border-default" ]
                            [ viewMobileAuthControls lang config.authState ]
                        ]
                }
        , main = config.main
        , aboveFooter = [ viewFeedLinks lang strings config.site ]
        , footer = Just { topMargin = False, extra = [] }
        , scrollToTop = Nothing
        , toasts = Just (List.map toSharedToast config.toasts)
        , overlays = []
        }


viewDesktopAuthControls : Lang -> AuthState -> Html Msg
viewDesktopAuthControls lang authState =
    case authState of
        NotAuthenticated ->
            div [ class "hidden md:flex gap-2 items-center" ]
                [ authButton LoginClicked (t lang LoginButton) ]

        Authenticated user ->
            div [ class "hidden md:flex gap-2 items-center" ]
                [ span [ class "type-caption text-white/80" ] [ text user.name ]
                , span [ attribute "title" (userTooltip lang user), class "inline-flex" ]
                    [ authButton LogOut (t lang LogoutButton) ]
                ]


viewMobileAuthControls : Lang -> AuthState -> Html Msg
viewMobileAuthControls lang authState =
    case authState of
        NotAuthenticated ->
            div [ class "flex" ]
                [ authButton LoginClicked (t lang LoginButton) ]

        Authenticated user ->
            div [ class "flex flex-col items-start gap-3" ]
                [ span [ class "type-caption text-text-muted" ] [ text user.name ]
                , span [ attribute "title" (userTooltip lang user), class "inline-flex" ]
                    [ authButton LogOut (t lang LogoutButton) ]
                ]


authButton : Msg -> String -> Html Msg
authButton msg label =
    Button.new { label = label, onClick = msg }
        |> Button.withVariant Button.Primary
        |> Button.withSize Button.Small
        |> Button.toHtml


userTooltip : Lang -> AuthUser -> String
userTooltip lang user =
    let
        namePart =
            String.trim user.name

        emailPart =
            String.trim user.email
    in
    if String.isEmpty namePart then
        t lang LoggedInAs ++ emailPart

    else if String.isEmpty emailPart then
        t lang LoggedInAs ++ namePart

    else
        t lang LoggedInAs ++ namePart ++ " (" ++ emailPart ++ ")"


viewFeedLinks : Lang -> UiStrings -> SiteSettings -> Html Msg
viewFeedLinks lang strings site =
    let
        siteUrl =
            site.site.url

        host =
            siteUrl
                |> String.split "://"
                |> List.drop 1
                |> String.join "://"
    in
    FeedLinks.view
        { label = t lang A11yFeedLinks
        , newTabHint = strings.newTabHint
        , cards =
            [ { icon = FeatherIcons.calendar
              , title = "iCalendar"
              , description = t lang FeedIcalDescription
              , href = "webcal://" ++ host ++ "/kalenteri.ics"
              }
            , { icon = FeatherIcons.fileText
              , title = "HTML | PDF"
              , description = t lang FeedHtmlDescription
              , href = siteUrl ++ "/kalenteri.html"
              }
            ]
        , feeds =
            Just
                { icon = FeatherIcons.rss
                , title = t lang FeedsTitle
                , description = t lang FeedsDescription
                , links =
                    [ { label = "ATOM", href = siteUrl ++ "/kalenteri.atom" }
                    , { label = "RSS", href = siteUrl ++ "/kalenteri.rss" }
                    , { label = "JSON", href = siteUrl ++ "/kalenteri.json" }
                    , { label = "GeoJSON", href = siteUrl ++ "/kalenteri.geo.json" }
                    ]
                }
        }


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
