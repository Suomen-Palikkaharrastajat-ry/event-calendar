module View.Layout exposing (viewHeader, viewFooter, viewToasts)

import Html exposing (Html, a, button, div, footer, h3, header, nav, p, span, text)
import Html.Attributes exposing (attribute, class, href)
import Html.Events exposing (onClick)
import Svg
import Svg.Attributes as SvgA
import I18n exposing (MsgKey(..), t)
import Route exposing (toHref)
import Types exposing (AuthState(..), Msg(..), Toast, ToastKind(..))


viewHeader : AuthState -> Html Msg
viewHeader authState =
    header [ class "bg-primary text-white p-4 flex items-center justify-between" ]
        [ nav [ class "flex gap-4" ]
            [ a [ href (toHref (Route.RouteCalendar Nothing)), class "hover:underline" ]
                [ text (t NavHome) ]
            , a [ href (toHref Route.RouteEvents), class "hover:underline" ]
                [ text (t NavEvents) ]
            ]
        , viewAuthControls authState
        ]


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
            "https://kalenteri.suomenpalikkayhteiso.fi"
    in
    footer [ class "mt-auto border-t border-gray-200 bg-gray-50 p-4" ]
        [ div [ class "mx-auto grid max-w-4xl grid-cols-1 gap-6 md:grid-cols-3" ]
            [ -- iCalendar
              a
                [ href "webcal://kalenteri.suomenpalikkayhteiso.fi/kalenteri.ics"
                , attribute "target" "_blank"
                , class "block rounded-lg p-4 text-left transition-colors hover:bg-gray-100"
                ]
                [ div [ class "mb-3 flex items-center" ]
                    [ footerIcon "M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                    , h3 [ class "text-lg font-semibold" ] [ text "iCalendar" ]
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
                    [ footerIcon "M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                    , h3 [ class "text-lg font-semibold" ] [ text "HTML | PDF" ]
                    ]
                , p [ class "text-sm text-gray-600" ]
                    [ text "Upota tai tulosta valmis tapahtumalistaus. Sisältää kalenterilinkit yksittäisiin tapahtumiin." ]
                ]
            , -- Feeds
              div [ class "p-4 text-left" ]
                [ div [ class "mb-3 flex items-center" ]
                    [ footerIcon "M6 5c7.18 0 13 5.82 13 13M6 11a7 7 0 017 7m-6 0a1 1 0 11-2 0 1 1 0 012 0m6 0a1 1 0 11-2 0 1 1 0 012 0m6 0a1 1 0 11-2 0 1 1 0 012 0"
                    , h3 [ class "text-lg font-semibold" ] [ text "Syötteet" ]
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


footerIcon : String -> Html Msg
footerIcon d =
    Svg.svg
        [ SvgA.class "mr-2 h-8 w-8 text-primary flex-shrink-0"
        , SvgA.fill "none"
        , SvgA.stroke "currentColor"
        , SvgA.viewBox "0 0 24 24"
        ]
        [ Svg.path
            [ SvgA.strokeLinecap "round"
            , SvgA.strokeLinejoin "round"
            , SvgA.strokeWidth "2"
            , SvgA.d d
            ]
            []
        ]


feedLink : String -> String -> Html Msg
feedLink url label =
    a
        [ href url
        , attribute "target" "_blank"
        , class "mx-1 text-primary no-underline hover:underline"
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
                    "bg-green-600"

                ToastError ->
                    "bg-red-600"

                ToastInfo ->
                    "bg-blue-600"
    in
    div
        [ class ("flex items-center gap-2 px-4 py-2 rounded text-white shadow-lg " ++ colorClass)
        ]
        [ text toast.message
        , button
            [ onClick (DismissToast toast.id)
            , class "ml-2 font-bold hover:opacity-75"
            ]
            [ text "×" ]
        ]
