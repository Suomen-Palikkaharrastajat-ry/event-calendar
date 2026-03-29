module View.Events exposing (view)

import DateUtils exposing (formatEventDateDisplay, parseUtcString, toHelsinkiParts)
import File
import Html exposing (Html, a, button, div, h2, input, label, option, p, select, span, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (accept, class, href, selected, type_, value)
import Html.Events exposing (on, onClick, onInput)
import I18n exposing (MsgKey(..), stateLabel, t)
import Json.Decode as Json
import RemoteData exposing (RemoteData)
import Route exposing (Route(..), toHref)
import Time exposing (Posix, posixToMillis)
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


view : AuthState -> Posix -> EventsPage -> Html Msg
view authState now evPage =
    div [ class "max-w-5xl mx-auto p-4" ]
        [ h2 [ class "type-h3 mb-4" ] [ text (t EventListTitle) ]
        , viewKmlSection authState evPage
        , if evPage.showNewForm then
            div [ class "mb-6 p-4 border rounded bg-bg-subtle" ]
                [ h2 [ class "type-h4 mb-3" ] [ text (t EventListNewEvent) ]
                , View.EventForm.view evPage.form evPage.formStatus False
                ]

          else if isAuthenticated authState then
            button
                [ onClick (NavigateTo RouteEventNew)
                , class "mb-4 px-4 py-2 bg-brand text-white rounded hover:opacity-90"
                ]
                [ text ("+ " ++ t EventListNewEvent) ]

          else
            text ""
        , viewEventsTable now evPage
        ]



-- ── KML IMPORT SECTION ───────────────────────────────────────────────────────


viewKmlSection : AuthState -> EventsPage -> Html Msg
viewKmlSection authState evPage =
    if not (isAuthenticated authState) then
        text ""

    else
        div [ class "mb-4 flex items-center gap-3 flex-wrap" ]
            [ label [ class "type-body-small" ] [ text (t KmlImport) ]
            , input
                [ type_ "file"
                , accept ".kml"
                , on "change" (Json.map EventsKmlFileSelected kmlFileDecoder)
                , class "type-caption"
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
            span [ class "type-caption text-text-muted" ] [ text (t I18n.KmlImporting) ]

        Types.KmlImporting done total ->
            span [ class "type-caption text-brand" ]
                [ text (String.fromInt done ++ " / " ++ String.fromInt total) ]

        Types.KmlDone n ->
            span [ class "type-caption text-brand" ]
                [ text (String.fromInt n ++ " " ++ t I18n.KmlDone) ]

        Types.KmlError err ->
            span [ class "type-caption text-brand-red" ] [ text (t I18n.KmlError ++ ": " ++ err) ]



-- ── EVENTS TABLE ─────────────────────────────────────────────────────────────


viewEventsTable : Posix -> EventsPage -> Html Msg
viewEventsTable now evPage =
    case evPage.events of
        RemoteData.NotAsked ->
            text ""

        RemoteData.Loading ->
            div [ class "text-text-muted text-center py-8" ] [ text (t Loading) ]

        RemoteData.Failure _ ->
            div [ class "text-brand-red py-4" ] [ text (t ErrorUnknown) ]

        RemoteData.Success pbList ->
            if List.isEmpty pbList.items then
                div [ class "text-text-muted text-center py-8" ] [ text (t EventListEmpty) ]

            else
                div []
                    [ table [ class "w-full type-caption border-collapse" ]
                        [ thead []
                            [ tr [ class "bg-bg-subtle text-left" ]
                                [ th [ class "p-2 border" ] [ text "Nimi" ]
                                , th [ class "p-2 border" ] [ text "Sijainti" ]
                                , th [ class "p-2 border" ] [ text "Päivämäärä" ]
                                , th [ class "p-2 border" ] [ text "Tila" ]
                                , th [ class "p-2 border" ] [ text "" ]
                                ]
                            ]
                        , let
                            items =
                                reorderEvents now pbList.items
                          in
                          tbody [] (List.map (viewEventRow now) items)
                        ]
                    , viewPagination pbList evPage.currentPage
                    ]


{-| Reorder events so all upcoming events (end or start ≥ now) appear before past events.
Preserves relative order within each group.
-}
eventIsPast : Posix -> Event -> Bool
eventIsPast now event =
    let
        dateIsPast posix =
            let
                p =
                    toHelsinkiParts posix

                n =
                    toHelsinkiParts now
            in
            ( p.year, p.month, p.day ) < ( n.year, n.month, n.day )
    in
    if event.allDay then
        case event.endDate |> Maybe.andThen parseUtcString of
            Just endPosix ->
                dateIsPast endPosix

            Nothing ->
                case parseUtcString event.startDate of
                    Just startPosix ->
                        dateIsPast startPosix

                    Nothing ->
                        False

    else
        case event.endDate |> Maybe.andThen parseUtcString of
            Just endPosix ->
                posixToMillis endPosix < posixToMillis now

            Nothing ->
                case parseUtcString event.startDate of
                    Just startPosix ->
                        posixToMillis startPosix < posixToMillis now

                    Nothing ->
                        False


reorderEvents : Posix -> List Event -> List Event
reorderEvents now eventsList =
    let
        ( past, upcoming ) =
            List.foldl
                (\r ( ps, us ) ->
                    if eventIsPast now r then
                        ( ps ++ [ r ], us )

                    else
                        ( ps, us ++ [ r ] )
                )
                ( [], [] )
                eventsList

        eventMillis e =
            case e.endDate |> Maybe.andThen parseUtcString of
                Just p ->
                    posixToMillis p

                Nothing ->
                    case parseUtcString e.startDate of
                        Just s ->
                            posixToMillis s

                        Nothing ->
                            0

        pastDesc =
            List.sortBy (\e -> Basics.negate (eventMillis e)) past
    in
    upcoming ++ pastDesc


viewEventRow : Posix -> Event -> Html Msg
viewEventRow now event =
    let
        classes =
            if eventIsPast now event then
                "hover:bg-bg-subtle border-b opacity-50"

            else
                "hover:bg-bg-subtle border-b"
    in
    tr [ class classes ]
        [ td [ class "p-2 border" ]
            [ a
                [ href (toHref (RouteEventDetail event.id))
                , class "hover:underline type-body-small"
                ]
                [ text
                    (String.left 40 event.title
                        ++ (if String.length event.title > 40 then
                                "…"

                            else
                                ""
                           )
                    )
                ]
            ]
        , td [ class "p-2 border text-text-muted" ]
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
                                , class "hover:underline text-brand"
                                ]
                                [ text (String.left 30 loc) ]

                        Nothing ->
                            text (String.left 30 loc)
            ]
        , td [ class "p-2 border text-text-muted whitespace-nowrap" ]
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
                , class "appearance-auto border rounded px-1 py-0.5 type-caption"
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
                , class "text-brand hover:underline type-caption"
                ]
                [ text (t EventListEdit) ]
            ]
        ]


viewPagination : PbList a -> Int -> Html Msg
viewPagination pbList currentPage =
    if pbList.totalPages <= 1 then
        text ""

    else
        div [ class "flex items-center gap-3 mt-4 type-caption" ]
            [ button
                [ onClick (EventsSetPage (currentPage - 1))
                , Html.Attributes.disabled (currentPage <= 1)
                , class "px-3 py-1 border rounded hover:bg-bg-subtle disabled:opacity-50"
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
                , class "px-3 py-1 border rounded hover:bg-bg-subtle disabled:opacity-50"
                ]
                [ text "Seuraava ›" ]
            ]



-- ── FILE DECODER ─────────────────────────────────────────────────────────────


kmlFileDecoder : Json.Decoder File.File
kmlFileDecoder =
    Json.at [ "target", "files" ] (Json.index 0 File.decoder)
