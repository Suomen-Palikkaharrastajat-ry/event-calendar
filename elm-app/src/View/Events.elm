module View.Events exposing (view)

import File
import Html exposing (Html, div, h2, input, label, span, text)
import Html.Attributes exposing (accept, class, type_)
import Html.Events exposing (on)
import I18n exposing (MsgKey(..), t)
import Json.Decode as Json
import Time exposing (Posix)
import Types exposing (AuthState, EventsPage, KmlImportStatus, Msg(..), isAuthenticated)
import View.EventForm


view : AuthState -> Posix -> EventsPage -> Html Msg
view authState _ evPage =
    div [ class "max-w-5xl mx-auto p-4" ]
        [ h2 [ class "type-h3 mb-4" ] [ text (t EventListNewEvent) ]
        , viewKmlSection authState evPage
        , div [ class "mb-6 p-4 border rounded bg-bg-subtle" ]
            [ View.EventForm.view evPage.form evPage.formStatus False ]
        ]


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


kmlFileDecoder : Json.Decoder File.File
kmlFileDecoder =
    Json.at [ "target", "files" ] (Json.index 0 File.decoder)
