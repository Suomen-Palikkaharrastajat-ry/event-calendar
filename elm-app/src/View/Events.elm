module View.Events exposing (view)

import DateUtils exposing (formatEventDateDisplay)
import File
import Html exposing (Html, a, button, div, h2, input, label, option, p, select, span, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (accept, class, href, selected, type_, value)
import Html.Events exposing (on, onClick, onInput)
import I18n exposing (MsgKey(..), stateLabel, t)
import Json.Decode as Json
import RemoteData exposing (RemoteData)
import Route exposing (Route(..), toHref)
import Types
    exposing
        ( AuthState(..)
        , Event
        , EventState(..)
        , EventsPage
        , FormStatus(..)
        , KmlImportStatus
        , Msg(..)
        , PbList
        , eventStateFromString
        , isAuthenticated
        )
import View.EventForm


view : AuthState -> EventsPage -> Html Msg
view authState evPage =
    div [ class "max-w-5xl mx-auto p-4" ]
        [ h2 [ class "text-xl font-bold mb-4" ] [ text (t EventListTitle) ]
        , viewKmlSection authState evPage
        , if evPage.showNewForm then
            div [ class "mb-6 p-4 border rounded bg-gray-50" ]
                [ h2 [ class "text-lg font-semibold mb-3" ] [ text (t EventListNewEvent) ]
                , View.EventForm.view evPage.form evPage.formStatus False
                ]

          else if isAuthenticated authState then
            button
                [ onClick (NavigateTo RouteEventNew)
                , class "mb-4 px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700"
                ]
                [ text ("+ " ++ t EventListNewEvent) ]

          else
            text ""
        , viewEventsTable evPage
        ]


-- ── KML IMPORT SECTION ───────────────────────────────────────────────────────


viewKmlSection : AuthState -> EventsPage -> Html Msg
viewKmlSection authState evPage =
    if not (isAuthenticated authState) then
        text ""

    else
        div [ class "mb-4 flex items-center gap-3 flex-wrap" ]
            [ label [ class "text-sm font-medium" ] [ text (t KmlImport) ]
            , input
                [ type_ "file"
                , accept ".kml"
                , on "change" (Json.map EventsKmlFileSelected kmlFileDecoder)
                , class "text-sm"
                ]
                []
            , viewKmlStatus evPage.kmlImportStatus
            ]


viewKmlStatus : KmlImportStatus -> Html Msg
viewKmlStatus status =
    case status of
        Types.KmlIdle ->
            text ""

        Types.KmlParsing ->
            span [ class "text-sm text-gray-500" ] [ text (t I18n.KmlImporting) ]

        Types.KmlImporting done total ->
            span [ class "text-sm text-blue-600" ]
                [ text (String.fromInt done ++ " / " ++ String.fromInt total) ]

        Types.KmlDone n ->
            span [ class "text-sm text-green-600" ]
                [ text (String.fromInt n ++ " " ++ t I18n.KmlDone) ]

        Types.KmlError err ->
            span [ class "text-sm text-red-600" ] [ text (t I18n.KmlError ++ ": " ++ err) ]


-- ── EVENTS TABLE ─────────────────────────────────────────────────────────────


viewEventsTable : EventsPage -> Html Msg
viewEventsTable evPage =
    case evPage.events of
        RemoteData.NotAsked ->
            text ""

        RemoteData.Loading ->
            div [ class "text-gray-500 text-center py-8" ] [ text (t Loading) ]

        RemoteData.Failure _ ->
            div [ class "text-red-600 py-4" ] [ text (t ErrorUnknown) ]

        RemoteData.Success pbList ->
            if List.isEmpty pbList.items then
                div [ class "text-gray-500 text-center py-8" ] [ text (t EventListEmpty) ]

            else
                div []
                    [ table [ class "w-full text-sm border-collapse" ]
                        [ thead []
                            [ tr [ class "bg-gray-100 text-left" ]
                                [ th [ class "p-2 border" ] [ text "Nimi" ]
                                , th [ class "p-2 border" ] [ text "Sijainti" ]
                                , th [ class "p-2 border" ] [ text "Päivämäärä" ]
                                , th [ class "p-2 border" ] [ text "Tila" ]
                                , th [ class "p-2 border" ] [ text "" ]
                                ]
                            ]
                        , tbody [] (List.map viewEventRow pbList.items)
                        ]
                    , viewPagination pbList evPage.currentPage
                    ]


viewEventRow : Event -> Html Msg
viewEventRow event =
    tr [ class "hover:bg-gray-50 border-b" ]
        [ td [ class "p-2 border" ]
            [ a
                [ href (toHref (RouteEventDetail event.id))
                , class "hover:underline font-medium"
                ]
                [ text (String.left 40 event.title
                    ++ (if String.length event.title > 40 then "…" else "")
                  )
                ]
            ]
        , td [ class "p-2 border text-gray-600" ]
            [ case event.location of
                Nothing ->
                    text "—"

                Just loc ->
                    case event.point of
                        Just pt ->
                            a
                                [ href
                                    ("https://www.openstreetmap.org/?mlat="
                                        ++ String.fromFloat pt.lat
                                        ++ "&mlon="
                                        ++ String.fromFloat pt.lon
                                        ++ "&zoom=15"
                                    )
                                , class "hover:underline text-blue-600"
                                ]
                                [ text (String.left 30 loc) ]

                        Nothing ->
                            text (String.left 30 loc)
            ]
        , td [ class "p-2 border text-gray-600 whitespace-nowrap" ]
            [ text (String.left 10 event.startDate) ]
        , td [ class "p-2 border" ]
            [ select
                [ onInput
                    (\v ->
                        case eventStateFromString v of
                            Just state ->
                                EventsStatusChanged event.id state

                            Nothing ->
                                EventsStatusChanged event.id event.state
                    )
                , class "appearance-auto border rounded px-1 py-0.5 text-xs"
                ]
                [ option [ value "draft", selected (event.state == Draft) ] [ text (stateLabel Draft) ]
                , option [ value "pending", selected (event.state == Pending) ] [ text (stateLabel Pending) ]
                , option [ value "published", selected (event.state == Published) ] [ text (stateLabel Published) ]
                , option [ value "deleted", selected (event.state == Deleted) ] [ text (stateLabel Deleted) ]
                ]
            ]
        , td [ class "p-2 border" ]
            [ a
                [ href (toHref (RouteEventEdit event.id))
                , class "text-blue-600 hover:underline text-xs"
                ]
                [ text (t EventListEdit) ]
            ]
        ]


viewPagination : PbList a -> Int -> Html Msg
viewPagination pbList currentPage =
    if pbList.totalPages <= 1 then
        text ""

    else
        div [ class "flex items-center gap-3 mt-4 text-sm" ]
            [ button
                [ onClick (EventsSetPage (currentPage - 1))
                , Html.Attributes.disabled (currentPage <= 1)
                , class "px-3 py-1 border rounded hover:bg-gray-100 disabled:opacity-50"
                ]
                [ text "‹ Edellinen" ]
            , span []
                [ text
                    (t EventListPage
                        ++ " "
                        ++ String.fromInt currentPage
                        ++ " "
                        ++ t EventListOf
                        ++ " "
                        ++ String.fromInt pbList.totalPages
                    )
                ]
            , button
                [ onClick (EventsSetPage (currentPage + 1))
                , Html.Attributes.disabled (currentPage >= pbList.totalPages)
                , class "px-3 py-1 border rounded hover:bg-gray-100 disabled:opacity-50"
                ]
                [ text "Seuraava ›" ]
            ]


-- ── FILE DECODER ─────────────────────────────────────────────────────────────


kmlFileDecoder : Json.Decoder File.File
kmlFileDecoder =
    Json.at [ "target", "files" ] (Json.index 0 File.decoder)
