module View.Layout exposing (viewFooter, viewHeader, viewToasts)

import FeatherIcons
import Html exposing (Html, a, button, div, footer, h3, header, img, nav, p, span, text)
import Html.Attributes exposing (alt, attribute, class, href, src, style, type_)
import Html.Events exposing (onClick)
import I18n exposing (MsgKey(..), t)
import Route exposing (toHref)
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
                    [ src "/logos/square/square-smile.svg"
                    , alt ""
                    , attribute "aria-hidden" "true"
                    , class "h-8 w-8"
                    ]
                    []
                , span [ class "text-lg font-bold text-white" ] [ text (t NavbarTitle) ]
                ]
            , -- Desktop nav + auth (hidden on mobile)
              div [ class "hidden md:flex items-center gap-6" ]
                [ nav [ class "flex gap-4" ]
                    [ a [ href (toHref (Route.RouteCalendar Nothing)), class "text-white/80 hover:text-white hover:underline font-medium text-sm" ]
                        [ text (t NavHome) ]
                    , a [ href (toHref Route.RouteEvents), class "text-white/80 hover:text-white hover:underline font-medium text-sm" ]
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
        , -- Mobile dropdown menu
          if menuOpen then
            div [ class "md:hidden border-t border-white/20 px-4 py-3 flex flex-col items-end gap-3", attribute "id" "ec-mobile-nav" ]
                [ a
                    [ href (toHref (Route.RouteCalendar Nothing))
                    , class "text-white/80 hover:text-white hover:underline font-medium text-sm"
                    ]
                    [ text "Kalenteri" ]
                , a
                    [ href (toHref Route.RouteEvents)
                    , class "text-white/80 hover:text-white hover:underline font-medium text-sm"
                    ]
                    [ text (t NavEvents) ]
                , viewAuthControls authState
                ]

          else
            text ""
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
                    , class "btn-primary text-sm"
                    ]
                    [ text (t LoginButton) ]
                ]

        Authenticated user ->
            div [ class "flex gap-2 items-center" ]
                [ span [ class "text-sm" ] [ text user.name ]
                , button
                    [ onClick LogOut
                    , class "text-sm underline hover:no-underline"
                    ]
                    [ text (t LogoutButton) ]
                ]


viewFooter : Html Msg
viewFooter =
    let
        siteUrl =
            "https://kalenteri.palikkaharrastajat.fi"
    in
    footer [ class "mt-auto border-t border-gray-200 bg-gray-50 p-4" ]
        [ div [ class "mx-auto grid max-w-5xl grid-cols-1 gap-6 md:grid-cols-3" ]
            [ -- iCalendar
              a
                [ href "webcal://kalenteri.palikkaharrastajat.fi/kalenteri.ics"
                , attribute "target" "_blank"
                , class "block rounded-lg p-4 text-left transition-colors hover:bg-gray-100"
                ]
                [ div [ class "mb-3 flex items-center" ]
                    [ div [ class "mr-2 text-brand" ]
                        [ featherIcon FeatherIcons.calendar 32 ]
                    , h3 [ class "type-h3" ] [ text "iCalendar" ]
                    ]
                , p [ class "text-sm text-gray-600" ]
                    [ text "Kalenterivienti (ICS) tilaa tai integroi koko kalenterin helposti. Klikkaa kalenteri puhelimeesi!" ]
                ]
            , -- HTML | PDF
              a
                [ href (siteUrl ++ "/kalenteri.html")
                , attribute "target" "_blank"
                , class "block rounded-lg p-4 text-left transition-colors hover:bg-gray-100"
                ]
                [ div [ class "mb-3 flex items-center" ]
                    [ div [ class "mr-2 text-brand" ]
                        [ featherIcon FeatherIcons.fileText 32 ]
                    , h3 [ class "type-h3" ] [ text "HTML | PDF" ]
                    ]
                , p [ class "text-sm text-gray-600" ]
                    [ text "Upota tai tulosta valmis tapahtumalistaus. Sisältää kalenterilinkit yksittäisiin tapahtumiin." ]
                ]
            , -- Feeds
              div [ class "p-4 text-left" ]
                [ div [ class "mb-3 flex items-center" ]
                    [ div [ class "mr-2 text-brand" ]
                        [ featherIcon FeatherIcons.rss 32 ]
                    , h3 [ class "type-h3" ] [ text "Syötteet" ]
                    ]
                , p [ class "mb-3 text-sm text-gray-600" ]
                    [ text "Syötteet integroivat uudet tapahtumat verkkosivuille. Nämäkin sisältävät kalenterilinkit." ]
                , div [ class "text-center text-sm" ]
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
                    "bg-green-700"

                ToastError ->
                    "bg-red"

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
