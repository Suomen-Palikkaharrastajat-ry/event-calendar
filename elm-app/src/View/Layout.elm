module View.Layout exposing (view)

{-| Page chrome: the shared family shell with this app's navigation, account
controls, feed links and toasts.
-}

import Component.Account as Account
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
        , headerActions = [ Account.viewHeader (account strings config.authState) ]
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
                            [ Account.viewDrawer (account strings config.authState) ]
                        ]
                }
        , main = config.main
        , aboveFooter = [ viewFeedLinks lang strings config.site ]
        , footer = Just { topMargin = False, extra = [] }
        , scrollToTop = Nothing
        , toasts = Just (List.map toSharedToast config.toasts)
        , overlays = []
        }


{-| What the shared account controls need: the signed-in user, if any.
-}
account : UiStrings -> AuthState -> { strings : UiStrings, user : Maybe AuthUser, onSignIn : Msg, onSignOut : Msg }
account strings authState =
    { strings = strings
    , user =
        case authState of
            Authenticated user ->
                Just user

            NotAuthenticated ->
                Nothing
    , onSignIn = LoginClicked
    , onSignOut = LogOut
    }


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
