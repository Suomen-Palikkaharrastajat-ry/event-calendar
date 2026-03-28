module View.Layout exposing (viewBrandFooter, viewFooter, viewHeader, viewMobileDrawer, viewMobileOverlay, viewToasts)

import Component.MobileDrawer as MobileDrawer
import FeatherIcons
import Html exposing (Html, a, button, div, footer, h3, header, img, li, nav, p, span, text, ul)
import Html.Attributes exposing (alt, attribute, class, href, src, style)
import Html.Events exposing (onClick)
import I18n exposing (MsgKey(..), t)
import Route exposing (Route(..), toHref)
import Svg
import Svg.Attributes as SvgA
import Types exposing (AuthState(..), Msg(..), Toast, ToastKind(..))


viewHeader : AuthState -> Bool -> Html Msg
viewHeader authState menuOpen =
    header [ class "bg-brand border-b border-brand sticky top-0 z-50" ]
        [ -- Short toolbar (h-14, matches planet design)
          div [ class "flex items-center justify-between px-4 h-14" ]
            [ -- Square logo + site name
              a [ href (toHref (Route.RouteCalendar Nothing)), class "flex items-center gap-2" ]
                [ img
                    [ src "/logo/square/square-smile.svg"
                    , alt ""
                    , attribute "aria-hidden" "true"
                    , class "h-8 w-8"
                    ]
                    []
                , span [ class "type-h4 text-white" ] [ text (t NavbarTitle) ]
                ]
            , -- Desktop nav + auth (hidden on mobile)
              div [ class "hidden md:flex items-center gap-6" ]
                [ nav [ class "flex gap-4" ]
                    [ a [ href (toHref (Route.RouteCalendar Nothing)), class "type-caption text-white/80 hover:text-white hover:underline" ]
                        [ text (t NavHome) ]
                    , a [ href (toHref Route.RouteEvents), class "type-caption text-white/80 hover:text-white hover:underline" ]
                        [ text (t NavEvents) ]
                    ]
                , viewAuthControls authState
                ]
            , -- Hamburger button (mobile only)
              button
                [ onClick ToggleMenu
                , class "md:hidden p-2 rounded-lg text-white"
                , style "cursor" "pointer"
                , attribute "aria-label"
                    (if menuOpen then
                        "Sulje valikko"

                     else
                        "Avaa valikko"
                    )
                , attribute "aria-expanded"
                    (if menuOpen then
                        "true"

                     else
                        "false"
                    )
                ]
                [ featherIcon
                    (if menuOpen then
                        FeatherIcons.x

                     else
                        FeatherIcons.menu
                    )
                    24
                ]
            ]
        ]


featherIcon : FeatherIcons.Icon -> Float -> Html Msg
featherIcon icon size =
    icon
        |> FeatherIcons.withSize size
        |> FeatherIcons.toHtml []


viewAuthControls : AuthState -> Html Msg
viewAuthControls authState =
    case authState of
        NotAuthenticated ->
            div [ class "flex gap-2 items-center" ]
                [ button
                    [ onClick LoginClicked
                    , class "btn-primary type-caption"
                    ]
                    [ text (t LoginButton) ]
                ]

        Authenticated user ->
            div [ class "flex gap-2 items-center" ]
                [ span [ class "type-caption" ] [ text user.name ]
                , button
                    [ onClick LogOut
                    , class "type-caption underline hover:no-underline"
                    ]
                    [ text (t LogoutButton) ]
                ]


viewFooter : Html Msg
viewFooter =
    let
        siteUrl =
            "https://kalenteri.palikkaharrastajat.fi"
    in
    footer [ class "mt-auto border-t border-border-default bg-bg-subtle p-4" ]
        [ div [ class "mx-auto grid max-w-5xl grid-cols-1 gap-6 md:grid-cols-3" ]
            [ -- iCalendar
              a
                [ href "webcal://kalenteri.palikkaharrastajat.fi/kalenteri.ics"
                , attribute "target" "_blank"
                , class "block rounded-lg p-4 text-left motion-safe:transition-colors hover:bg-bg-subtle"
                ]
                [ div [ class "mb-3 flex items-center" ]
                    [ div [ class "mr-2 text-brand" ]
                        [ featherIcon FeatherIcons.calendar 32 ]
                    , h3 [ class "type-h3" ] [ text "iCalendar" ]
                    ]
                , p [ class "type-caption text-text-muted" ]
                    [ text "Kalenterivienti (ICS) tilaa tai integroi koko kalenterin helposti. Klikkaa kalenteri puhelimeesi!" ]
                ]
            , -- HTML | PDF
              a
                [ href (siteUrl ++ "/kalenteri.html")
                , attribute "target" "_blank"
                , class "block rounded-lg p-4 text-left motion-safe:transition-colors hover:bg-bg-subtle"
                ]
                [ div [ class "mb-3 flex items-center" ]
                    [ div [ class "mr-2 text-brand" ]
                        [ featherIcon FeatherIcons.fileText 32 ]
                    , h3 [ class "type-h3" ] [ text "HTML | PDF" ]
                    ]
                , p [ class "type-caption text-text-muted" ]
                    [ text "Upota tai tulosta valmis tapahtumalistaus. Sisältää kalenterilinkit yksittäisiin tapahtumiin." ]
                ]
            , -- Feeds
              div [ class "p-4 text-left" ]
                [ div [ class "mb-3 flex items-center" ]
                    [ div [ class "mr-2 text-brand" ]
                        [ featherIcon FeatherIcons.rss 32 ]
                    , h3 [ class "type-h3" ] [ text "Syötteet" ]
                    ]
                , p [ class "mb-3 type-caption text-text-muted" ]
                    [ text "Syötteet integroivat uudet tapahtumat verkkosivuille. Nämäkin sisältävät kalenterilinkit." ]
                , div [ class "text-center type-caption" ]
                    [ feedLink (siteUrl ++ "/kalenteri.atom") "ATOM"
                    , text " | "
                    , feedLink (siteUrl ++ "/kalenteri.rss") "RSS"
                    , text " | "
                    , feedLink (siteUrl ++ "/kalenteri.json") "JSON"
                    , text " | "
                    , feedLink (siteUrl ++ "/kalenteri.geo.json") "GeoJSON"
                    ]
                ]
            ]
        ]


feedLink : String -> String -> Html Msg
feedLink url label =
    a
        [ href url
        , attribute "target" "_blank"
        , class "mx-1 text-brand no-underline hover:underline"
        ]
        [ text label ]


viewToasts : List Toast -> Html Msg
viewToasts toasts =
    div [ class "fixed bottom-4 right-4 flex flex-col gap-2 z-50" ]
        (List.map viewToast toasts)


viewToast : Toast -> Html Msg
viewToast toast =
    let
        colorClass =
            case toast.kind of
                ToastSuccess ->
                    "bg-brand-nougat-dark"

                ToastError ->
                    "bg-brand-red"

                ToastInfo ->
                    "bg-brand"
    in
    div
        [ class ("flex items-center gap-2 px-4 py-2 rounded text-white shadow-lg " ++ colorClass)
        ]
        [ text toast.message
        , button
            [ onClick (DismissToast toast.id)
            , class "ml-2 hover:opacity-75"
            ]
            [ featherIcon FeatherIcons.x 16 ]
        ]


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
        , onClose = CloseMenu
        , breakpoint = MobileDrawer.Md
        , content =
            [ nav [ class "p-4" ]
                [ ul [ class "flex flex-col gap-1 list-none m-0 p-0" ]
                    [ MobileDrawer.viewNavLink { href = toHref (RouteCalendar Nothing), label = t NavHome, isActive = isActive (RouteCalendar Nothing), onClose = CloseMenu }
                    , MobileDrawer.viewNavLink { href = toHref RouteEvents, label = t NavEvents, isActive = isActive RouteEvents, onClose = CloseMenu }
                    ]
                ]
            , div [ class "p-4 border-t border-border-default" ]
                [ viewAuthControls authState ]
            ]
        }


viewBrandFooter : Html Msg
viewBrandFooter =
    footer
        [ class "bg-brand text-white py-12 px-4" ]
        [ div [ class "max-w-5xl mx-auto" ]
            [ div
                [ class "grid grid-cols-1 sm:grid-cols-[auto_1fr] gap-8 sm:items-end" ]
                [ -- Col 1: service links + logo
                  div [ class "flex items-start gap-4" ]
                    [ img
                        [ src "/logo/square/square-smile-full-dark-bold.svg"
                        , alt ""
                        , attribute "aria-hidden" "true"
                        , class "h-35 w-35 flex-shrink-0"
                        ]
                        []
                    , div [ class "space-y-3" ]
                        [ p [ class "text-xs font-semibold text-white/50 uppercase tracking-wider" ]
                            [ text "Palikkaharrastajat" ]
                        , ul [ class "space-y-2 list-none m-0 p-0" ]
                            [ li []
                                [ a
                                    [ href "https://palikkaharrastajat.fi"
                                    , class "text-sm text-white/80 hover:text-white underline transition-colors"
                                    ]
                                    [ text "Kotisivut" ]
                                ]
                            , li []
                                [ a
                                    [ href "https://kalenteri.palikkaharrastajat.fi"
                                    , class "text-sm text-white/80 hover:text-white underline transition-colors"
                                    ]
                                    [ text "Palikkakalenteri" ]
                                ]
                            , li []
                                [ a
                                    [ href "https://linkit.palikkaharrastajat.fi"
                                    , class "text-sm text-white/80 hover:text-white underline transition-colors"
                                    ]
                                    [ text "Palikkalinkit" ]
                                ]
                            ]
                        ]
                    ]
                , -- Col 2: org name & legal
                  div [ class "space-y-1 sm:text-right" ]
                    [ div [ class "space-y-1 text-xs text-white/50" ]
                        [ p [] [ text "© 2026 Suomen Palikkaharrastajat ry" ]
                        , p [] [ text "LEGO® on LEGO Groupin rekisteröity tavaramerkki" ]
                        ]
                    ]
                ]
            ]
        ]
