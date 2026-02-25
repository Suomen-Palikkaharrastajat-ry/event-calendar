module View.EventForm exposing (view, viewEdit)

import File exposing (File)
import Html exposing (Html, button, div, h2, img, input, label, option, p, select, text, textarea)
import Html.Attributes exposing (accept, alt, checked, class, disabled, for, id, selected, src, step, type_, value)
import Html.Events exposing (on, onCheck, onClick, onInput)
import I18n exposing (MsgKey(..), stateLabel, t)
import Json.Decode as Json
import RemoteData
import Route exposing (Route(..), toHref)
import Types
    exposing
        ( AuthState
        , EventEditPage
        , EventFormData
        , EventState(..)
        , FormStatus(..)
        , Msg(..)
        )
import View.MapWidget


{-| Create-event form (used inside the events management page).
`isEdit` controls whether to show Edit or Create labels.
Field messages use `EventsForm*` prefix.
-}
view : EventFormData -> FormStatus -> Bool -> Html Msg
view formData formStatus isEdit =
    viewFormFields formData formStatus isEdit


{-| Standalone edit-event page, wrapping the shared form fields with Edit-prefix messages. -}
viewEdit : EventEditPage -> Html Msg
viewEdit editPage =
    div [ class "max-w-2xl mx-auto p-4" ]
        [ h2 [ class "text-xl font-bold mb-4" ] [ text "Muokkaa tapahtumaa" ]
        , case editPage.event of
            RemoteData.Loading ->
                div [ class "text-gray-500" ] [ text (t Loading) ]

            RemoteData.Failure _ ->
                div [ class "text-red-600" ] [ text (t ErrorUnknown) ]

            _ ->
                viewEditFields editPage.form editPage.formStatus
        ]


-- ── Create form (EventsForm* messages) ───────────────────────────────────────


viewFormFields : EventFormData -> FormStatus -> Bool -> Html Msg
viewFormFields form formStatus isEdit =
    div [ class "flex flex-col gap-4" ]
        [ fieldText "title" (t FormTitle) form.title True EventsFormFieldChanged
        , fieldText "location" (t FormLocation) form.location False EventsFormFieldChanged
        , viewGeocodeSection form
        , fieldTextarea "description" (t FormDescription) form.description EventsFormFieldChanged
        , fieldText "url" (t FormUrl) form.url False EventsFormFieldChanged
        , viewImageSection form isEdit
        , viewDateSection form
        , viewStateSelect form.state (\v -> EventsFormFieldChanged "state" v)
        , viewFormButtons formStatus False
        ]


viewGeocodeSection : EventFormData -> Html Msg
viewGeocodeSection form =
    div [ class "flex flex-col gap-2" ]
        [ div [ class "flex items-center gap-2" ]
            [ button
                [ onClick EventsFormToggleGeocode
                , class "text-sm px-2 py-1 border rounded hover:bg-gray-100"
                ]
                [ text
                    (if form.geocodingEnabled then
                        "📍 " ++ t FormGeocode

                     else
                        "🌍 " ++ t FormManualCoords
                    )
                ]
            , if form.geocodingEnabled && not (String.isEmpty form.location) then
                button
                    [ onClick EventsFormGeocode
                    , class "text-sm px-2 py-1 bg-blue-100 text-blue-700 rounded hover:bg-blue-200"
                    ]
                    [ text (t FormGeocode) ]

              else
                text ""
            ]
        , if not form.geocodingEnabled then
            div [ class "flex gap-2" ]
                [ div [ class "flex-1" ]
                    [ label [ class "text-sm text-gray-600 block mb-1" ] [ text (t FormLat) ]
                    , input
                        [ type_ "number"
                        , value form.lat
                        , step "0.000001"
                        , onInput (EventsFormFieldChanged "lat")
                        , class "w-full border rounded px-2 py-1 text-sm"
                        ]
                        []
                    ]
                , div [ class "flex-1" ]
                    [ label [ class "text-sm text-gray-600 block mb-1" ] [ text (t FormLon) ]
                    , input
                        [ type_ "number"
                        , value form.lon
                        , step "0.000001"
                        , onInput (EventsFormFieldChanged "lon")
                        , class "w-full border rounded px-2 py-1 text-sm"
                        ]
                        []
                    ]
                ]

          else if not (String.isEmpty form.lat) && not (String.isEmpty form.lon) then
            p [ class "text-xs text-gray-500" ]
                [ text (form.lat ++ ", " ++ form.lon) ]

          else
            text ""
        , View.MapWidget.view { containerId = "create-map" }
        ]


viewImageSection : EventFormData -> Bool -> Html Msg
viewImageSection form isEdit =
    div [ class "flex flex-col gap-1" ]
        [ label [ class "font-medium text-sm" ] [ text (t FormImage) ]
        , case form.imagePreviewUrl of
            Just previewUrl ->
                div [ class "mb-2" ]
                    [ img [ src previewUrl, alt "Esikatselu", class "max-h-32 rounded" ] [] ]

            Nothing ->
                if isEdit && form.hasExistingImage then
                    case form.existingImageUrl of
                        Just url ->
                            div [ class "mb-2" ]
                                [ img [ src url, alt "Nykyinen kuva", class "max-h-32 rounded" ] []
                                ]

                        Nothing ->
                            text ""

                else
                    text ""
        , input
            [ type_ "file"
            , accept "image/*"
            , on "change" (Json.map EventsFormFileSelected fileDecoder)
            , class "text-sm"
            ]
            []
        , input
            [ type_ "text"
            , value form.imageDescription
            , onInput (EventsFormFieldChanged "imageDescription")
            , Html.Attributes.placeholder (t FormImageAlt)
            , class "border rounded px-2 py-1 text-sm"
            ]
            []
        ]


viewDateSection : EventFormData -> Html Msg
viewDateSection form =
    div [ class "flex flex-col gap-2" ]
        [ div [ class "flex items-center gap-2" ]
            [ input
                [ type_ "checkbox"
                , checked form.allDay
                , onCheck (\_ -> EventsFormToggleAllDay)
                , id "allday-create"
                ]
                []
            , label [ for "allday-create", class "text-sm" ] [ text (t FormAllDay) ]
            ]
        , div [ class "flex gap-2 flex-wrap" ]
            [ div []
                [ label [ class "text-sm text-gray-600 block mb-1" ] [ text (t FormStartDate) ]
                , input
                    [ type_ "date"
                    , value form.startDate
                    , onInput (EventsFormDateChanged "startDate")
                    , class "border rounded px-2 py-1"
                    ]
                    []
                ]
            , if not form.allDay then
                div []
                    [ label [ class "text-sm text-gray-600 block mb-1" ] [ text (t FormStartTime) ]
                    , input
                        [ type_ "time"
                        , value form.startTime
                        , onInput (EventsFormDateChanged "startTime")
                        , class "border rounded px-2 py-1"
                        ]
                        []
                    ]

              else
                text ""
            , div []
                [ label [ class "text-sm text-gray-600 block mb-1" ] [ text (t FormEndDate) ]
                , input
                    [ type_ "date"
                    , value form.endDate
                    , onInput (EventsFormDateChanged "endDate")
                    , class "border rounded px-2 py-1"
                    ]
                    []
                ]
            , if not form.allDay then
                div []
                    [ label [ class "text-sm text-gray-600 block mb-1" ] [ text (t FormEndTime) ]
                    , input
                        [ type_ "time"
                        , value form.endTime
                        , onInput (EventsFormDateChanged "endTime")
                        , class "border rounded px-2 py-1"
                        ]
                        []
                    ]

              else
                text ""
            ]
        ]


viewStateSelect : EventState -> (String -> Msg) -> Html Msg
viewStateSelect currentState toMsg =
    div []
        [ label [ class "font-medium text-sm block mb-1" ] [ text (t FormStatus) ]
        , select
            [ onInput toMsg
            , class "appearance-auto border rounded px-2 py-1"
            ]
            [ option [ value "draft", selected (currentState == Draft) ] [ text (stateLabel Draft) ]
            , option [ value "pending", selected (currentState == Pending) ] [ text (stateLabel Pending) ]
            , option [ value "published", selected (currentState == Published) ] [ text (stateLabel Published) ]
            ]
        ]


viewFormButtons : FormStatus -> Bool -> Html Msg
viewFormButtons formStatus isEdit =
    div [ class "flex gap-2 pt-2" ]
        [ button
            [ onClick
                (if isEdit then
                    EditFormSubmit

                 else
                    EventsFormSubmit
                )
            , disabled (formStatus == FormSubmitting)
            , class "px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:opacity-50"
            ]
            [ text
                (if formStatus == FormSubmitting then
                    t Saving

                 else
                    t FormSave
                )
            ]
        , button
            [ onClick (NavigateTo RouteEvents)
            , class "px-4 py-2 border rounded hover:bg-gray-100"
            ]
            [ text (t FormCancel) ]
        ]


-- ── Edit form (EditForm* messages) ───────────────────────────────────────────


viewEditFields : EventFormData -> FormStatus -> Html Msg
viewEditFields form formStatus =
    div [ class "flex flex-col gap-4" ]
        [ fieldTextEdit "title" (t FormTitle) form.title True
        , fieldTextEdit "location" (t FormLocation) form.location False
        , viewGeocodeSectionEdit form
        , fieldTextareaEdit "description" (t FormDescription) form.description
        , fieldTextEdit "url" (t FormUrl) form.url False
        , viewImageSectionEdit form
        , viewDateSectionEdit form
        , viewStateSelectEdit form.state
        , viewFormButtons formStatus True
        ]


viewGeocodeSectionEdit : EventFormData -> Html Msg
viewGeocodeSectionEdit form =
    div [ class "flex flex-col gap-2" ]
        [ div [ class "flex items-center gap-2" ]
            [ button
                [ onClick EditFormToggleGeocode
                , class "text-sm px-2 py-1 border rounded hover:bg-gray-100"
                ]
                [ text
                    (if form.geocodingEnabled then
                        "📍 " ++ t FormGeocode

                     else
                        "🌍 " ++ t FormManualCoords
                    )
                ]
            , if form.geocodingEnabled && not (String.isEmpty form.location) then
                button
                    [ onClick EditFormGeocode
                    , class "text-sm px-2 py-1 bg-blue-100 text-blue-700 rounded hover:bg-blue-200"
                    ]
                    [ text (t FormGeocode) ]

              else
                text ""
            ]
        , if not form.geocodingEnabled then
            div [ class "flex gap-2" ]
                [ div [ class "flex-1" ]
                    [ label [ class "text-sm text-gray-600 block mb-1" ] [ text (t FormLat) ]
                    , input
                        [ type_ "number"
                        , value form.lat
                        , step "0.000001"
                        , onInput (EditFormFieldChanged "lat")
                        , class "w-full border rounded px-2 py-1 text-sm"
                        ]
                        []
                    ]
                , div [ class "flex-1" ]
                    [ label [ class "text-sm text-gray-600 block mb-1" ] [ text (t FormLon) ]
                    , input
                        [ type_ "number"
                        , value form.lon
                        , step "0.000001"
                        , onInput (EditFormFieldChanged "lon")
                        , class "w-full border rounded px-2 py-1 text-sm"
                        ]
                        []
                    ]
                ]

          else if not (String.isEmpty form.lat) && not (String.isEmpty form.lon) then
            p [ class "text-xs text-gray-500" ]
                [ text (form.lat ++ ", " ++ form.lon) ]

          else
            text ""
        , View.MapWidget.view { containerId = "edit-map" }
        ]


viewImageSectionEdit : EventFormData -> Html Msg
viewImageSectionEdit form =
    div [ class "flex flex-col gap-1" ]
        [ label [ class "font-medium text-sm" ] [ text (t FormImage) ]
        , case form.imagePreviewUrl of
            Just previewUrl ->
                div [ class "mb-2" ]
                    [ img [ src previewUrl, alt "Esikatselu", class "max-h-32 rounded" ] [] ]

            Nothing ->
                if form.hasExistingImage then
                    case form.existingImageUrl of
                        Just url ->
                            div [ class "mb-2" ]
                                [ img [ src url, alt "Nykyinen kuva", class "max-h-32 rounded" ] []
                                ]

                        Nothing ->
                            text ""

                else
                    text ""
        , input
            [ type_ "file"
            , accept "image/*"
            , on "change" (Json.map EditFormFileSelected fileDecoder)
            , class "text-sm"
            ]
            []
        , input
            [ type_ "text"
            , value form.imageDescription
            , onInput (EditFormFieldChanged "imageDescription")
            , Html.Attributes.placeholder (t FormImageAlt)
            , class "border rounded px-2 py-1 text-sm"
            ]
            []
        ]


viewDateSectionEdit : EventFormData -> Html Msg
viewDateSectionEdit form =
    div [ class "flex flex-col gap-2" ]
        [ div [ class "flex items-center gap-2" ]
            [ input
                [ type_ "checkbox"
                , checked form.allDay
                , onCheck (\_ -> EditFormToggleAllDay)
                , id "allday-edit"
                ]
                []
            , label [ for "allday-edit", class "text-sm" ] [ text (t FormAllDay) ]
            ]
        , div [ class "flex gap-2 flex-wrap" ]
            [ div []
                [ label [ class "text-sm text-gray-600 block mb-1" ] [ text (t FormStartDate) ]
                , input
                    [ type_ "date"
                    , value form.startDate
                    , onInput (EditFormDateChanged "startDate")
                    , class "border rounded px-2 py-1"
                    ]
                    []
                ]
            , if not form.allDay then
                div []
                    [ label [ class "text-sm text-gray-600 block mb-1" ] [ text (t FormStartTime) ]
                    , input
                        [ type_ "time"
                        , value form.startTime
                        , onInput (EditFormDateChanged "startTime")
                        , class "border rounded px-2 py-1"
                        ]
                        []
                    ]

              else
                text ""
            , div []
                [ label [ class "text-sm text-gray-600 block mb-1" ] [ text (t FormEndDate) ]
                , input
                    [ type_ "date"
                    , value form.endDate
                    , onInput (EditFormDateChanged "endDate")
                    , class "border rounded px-2 py-1"
                    ]
                    []
                ]
            , if not form.allDay then
                div []
                    [ label [ class "text-sm text-gray-600 block mb-1" ] [ text (t FormEndTime) ]
                    , input
                        [ type_ "time"
                        , value form.endTime
                        , onInput (EditFormDateChanged "endTime")
                        , class "border rounded px-2 py-1"
                        ]
                        []
                    ]

              else
                text ""
            ]
        ]


viewStateSelectEdit : EventState -> Html Msg
viewStateSelectEdit currentState =
    div []
        [ label [ class "font-medium text-sm block mb-1" ] [ text (t FormStatus) ]
        , select
            [ onInput (\v -> EditFormFieldChanged "state" v)
            , class "appearance-auto border rounded px-2 py-1"
            ]
            [ option [ value "draft", selected (currentState == Draft) ] [ text (stateLabel Draft) ]
            , option [ value "pending", selected (currentState == Pending) ] [ text (stateLabel Pending) ]
            , option [ value "published", selected (currentState == Published) ] [ text (stateLabel Published) ]
            ]
        ]


-- ── SHARED FIELD HELPERS ─────────────────────────────────────────────────────


fieldText : String -> String -> String -> Bool -> (String -> String -> Msg) -> Html Msg
fieldText fieldId labelText val required toMsg =
    div []
        [ label [ for fieldId, class "font-medium text-sm block mb-1" ]
            [ text
                (if required then
                    labelText ++ " *"

                 else
                    labelText
                )
            ]
        , input
            [ type_ "text"
            , id fieldId
            , value val
            , onInput (toMsg fieldId)
            , class "w-full border rounded px-2 py-1"
            ]
            []
        ]


fieldTextEdit : String -> String -> String -> Bool -> Html Msg
fieldTextEdit fieldId labelText val required =
    div []
        [ label [ for fieldId, class "font-medium text-sm block mb-1" ]
            [ text
                (if required then
                    labelText ++ " *"

                 else
                    labelText
                )
            ]
        , input
            [ type_ "text"
            , id fieldId
            , value val
            , onInput (EditFormFieldChanged fieldId)
            , class "w-full border rounded px-2 py-1"
            ]
            []
        ]


fieldTextarea : String -> String -> String -> (String -> String -> Msg) -> Html Msg
fieldTextarea fieldId labelText val toMsg =
    div []
        [ label [ for fieldId, class "font-medium text-sm block mb-1" ] [ text labelText ]
        , textarea
            [ id fieldId
            , value val
            , onInput (toMsg fieldId)
            , Html.Attributes.rows 4
            , class "w-full border rounded px-2 py-1"
            ]
            []
        ]


fieldTextareaEdit : String -> String -> String -> Html Msg
fieldTextareaEdit fieldId labelText val =
    div []
        [ label [ for fieldId, class "font-medium text-sm block mb-1" ] [ text labelText ]
        , textarea
            [ id fieldId
            , value val
            , onInput (EditFormFieldChanged fieldId)
            , Html.Attributes.rows 4
            , class "w-full border rounded px-2 py-1"
            ]
            []
        ]


-- ── FILE INPUT DECODER ───────────────────────────────────────────────────────


fileDecoder : Json.Decoder File
fileDecoder =
    Json.at [ "target", "files" ] (Json.index 0 File.decoder)
