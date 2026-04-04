module View.EventForm exposing (view, viewEdit)

import FeatherIcons
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
import View.Icons exposing (featherIcon)
import View.MapWidget


{-| Message constructors that differ between the Create and Edit form contexts.
Parametrizing these avoids duplicating every view section.
-}
type alias FormMsgs =
    { onFieldChanged : String -> String -> Msg
    , onDateChanged : String -> String -> Msg
    , onFileSelected : File -> Msg
    , onToggleAllDay : Msg
    , onToggleGeocode : Msg
    , onGeocode : Msg
    , allDayCheckboxId : String
    , mapContainerId : String
    }


createFormMsgs : FormMsgs
createFormMsgs =
    { onFieldChanged = EventsFormFieldChanged
    , onDateChanged = EventsFormDateChanged
    , onFileSelected = EventsFormFileSelected
    , onToggleAllDay = EventsFormToggleAllDay
    , onToggleGeocode = EventsFormToggleGeocode
    , onGeocode = EventsFormGeocode
    , allDayCheckboxId = "allday-create"
    , mapContainerId = "create-map"
    }


editFormMsgs : FormMsgs
editFormMsgs =
    { onFieldChanged = EditFormFieldChanged
    , onDateChanged = EditFormDateChanged
    , onFileSelected = EditFormFileSelected
    , onToggleAllDay = EditFormToggleAllDay
    , onToggleGeocode = EditFormToggleGeocode
    , onGeocode = EditFormGeocode
    , allDayCheckboxId = "allday-edit"
    , mapContainerId = "edit-map"
    }


{-| Create-event form (used inside the events management page).
Field messages use `EventsForm*` prefix.
-}
view : EventFormData -> FormStatus -> Bool -> Html Msg
view formData formStatus isEdit =
    viewSharedFields createFormMsgs formData formStatus isEdit


{-| Standalone edit-event page, wrapping the shared form fields with Edit-prefix messages.
-}
viewEdit : EventEditPage -> Html Msg
viewEdit editPage =
    div [ class "max-w-2xl mx-auto p-4" ]
        [ h2 [ class "type-h3 mb-4" ] [ text "Muokkaa tapahtumaa" ]
        , case editPage.event of
            RemoteData.Loading ->
                div [ class "text-text-muted" ] [ text (t Loading) ]

            RemoteData.Failure _ ->
                div [ class "text-brand-red" ] [ text (t ErrorUnknown) ]

            _ ->
                viewSharedFields editFormMsgs editPage.form editPage.formStatus True
        ]



-- ── Shared field layout ───────────────────────────────────────────────────────


{-| Renders all form fields using the given message set.
`isEdit` controls the submit button label and whether to show existing-image previews.
-}
viewSharedFields : FormMsgs -> EventFormData -> FormStatus -> Bool -> Html Msg
viewSharedFields msgs form formStatus isEdit =
    div [ class "flex flex-col gap-4" ]
        [ fieldText "title" (t FormTitle) form.title True msgs.onFieldChanged
        , fieldText "location" (t FormLocation) form.location False msgs.onFieldChanged
        , viewGeocodeSection msgs form
        , fieldTextarea "description" (t FormDescription) form.description msgs.onFieldChanged
        , fieldText "url" (t FormUrl) form.url False msgs.onFieldChanged
        , viewImageSection msgs isEdit form
        , viewDateSection msgs form
        , viewStateSelect form.state (\v -> msgs.onFieldChanged "state" v)
        , viewFormButtons formStatus isEdit
        ]



-- ── Shared section views ──────────────────────────────────────────────────────


viewGeocodeSection : FormMsgs -> EventFormData -> Html Msg
viewGeocodeSection msgs form =
    div [ class "flex flex-col gap-2" ]
        [ div [ class "flex items-center gap-2" ]
            [ button
                [ onClick msgs.onToggleGeocode
                , class "type-caption px-2 py-1 border rounded hover:bg-bg-subtle"
                ]
                (if form.geocodingEnabled then
                    [ featherIcon FeatherIcons.mapPin 14, text (" " ++ t FormGeocode) ]

                 else
                    [ featherIcon FeatherIcons.map 14, text (" " ++ t FormManualCoords) ]
                )
            , if form.geocodingEnabled && not (String.isEmpty form.location) then
                button
                    [ onClick msgs.onGeocode
                    , class "type-caption px-2 py-1 bg-brand-yellow text-brand rounded hover:opacity-90"
                    ]
                    [ text (t FormGeocode) ]

              else
                text ""
            ]
        , if not form.geocodingEnabled then
            div [ class "flex gap-2" ]
                [ div [ class "flex-1" ]
                    [ label [ class "type-caption text-text-muted block mb-1" ] [ text (t FormLat) ]
                    , input
                        [ type_ "number"
                        , value form.lat
                        , step "0.000001"
                        , onInput (msgs.onFieldChanged "lat")
                        , class "w-full border rounded px-2 py-1 type-caption"
                        ]
                        []
                    ]
                , div [ class "flex-1" ]
                    [ label [ class "type-caption text-text-muted block mb-1" ] [ text (t FormLon) ]
                    , input
                        [ type_ "number"
                        , value form.lon
                        , step "0.000001"
                        , onInput (msgs.onFieldChanged "lon")
                        , class "w-full border rounded px-2 py-1 type-caption"
                        ]
                        []
                    ]
                ]

          else if not (String.isEmpty form.lat) && not (String.isEmpty form.lon) then
            p [ class "type-caption text-text-muted" ]
                [ text (form.lat ++ ", " ++ form.lon) ]

          else
            text ""
        , View.MapWidget.view { containerId = msgs.mapContainerId }
        ]


viewImageSection : FormMsgs -> Bool -> EventFormData -> Html Msg
viewImageSection msgs showExistingIfPresent form =
    div [ class "flex flex-col gap-1" ]
        [ label [ class "type-body-small" ] [ text (t FormImage) ]
        , case form.imagePreviewUrl of
            Just previewUrl ->
                div [ class "mb-2" ]
                    [ img [ src previewUrl, alt "Esikatselu", class "max-h-32 rounded" ] [] ]

            Nothing ->
                if showExistingIfPresent && form.hasExistingImage then
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
            , on "change" (Json.map msgs.onFileSelected fileDecoder)
            , class "type-caption"
            ]
            []
        , input
            [ type_ "text"
            , value form.imageDescription
            , onInput (msgs.onFieldChanged "imageDescription")
            , Html.Attributes.placeholder (t FormImageAlt)
            , class "border rounded px-2 py-1 type-caption"
            ]
            []
        ]


viewDateSection : FormMsgs -> EventFormData -> Html Msg
viewDateSection msgs form =
    div [ class "flex flex-col gap-2" ]
        [ div [ class "flex items-center gap-2" ]
            [ input
                [ type_ "checkbox"
                , checked form.allDay
                , onCheck (\_ -> msgs.onToggleAllDay)
                , id msgs.allDayCheckboxId
                ]
                []
            , label [ for msgs.allDayCheckboxId, class "type-caption" ] [ text (t FormAllDay) ]
            ]
        , div [ class "flex gap-2 flex-wrap" ]
            [ div []
                [ label [ class "type-caption text-text-muted block mb-1" ] [ text (t FormStartDate) ]
                , input
                    [ type_ "date"
                    , value form.startDate
                    , onInput (msgs.onDateChanged "startDate")
                    , class "border rounded px-2 py-1"
                    ]
                    []
                ]
            , if not form.allDay then
                div []
                    [ label [ class "type-caption text-text-muted block mb-1" ] [ text (t FormStartTime) ]
                    , input
                        [ type_ "time"
                        , value form.startTime
                        , onInput (msgs.onDateChanged "startTime")
                        , class "border rounded px-2 py-1"
                        ]
                        []
                    ]

              else
                text ""
            , div []
                [ label [ class "type-caption text-text-muted block mb-1" ] [ text (t FormEndDate) ]
                , input
                    [ type_ "date"
                    , value form.endDate
                    , onInput (msgs.onDateChanged "endDate")
                    , class "border rounded px-2 py-1"
                    ]
                    []
                ]
            , if not form.allDay then
                div []
                    [ label [ class "type-caption text-text-muted block mb-1" ] [ text (t FormEndTime) ]
                    , input
                        [ type_ "time"
                        , value form.endTime
                        , onInput (msgs.onDateChanged "endTime")
                        , class "border rounded px-2 py-1"
                        ]
                        []
                    ]

              else
                text ""
            ]
        ]


{-| State dropdown for the form.
Note: `Deleted` is intentionally absent — deletion is a separate action
(via the event-detail page), not a state the user sets while creating/editing.
-}
viewStateSelect : EventState -> (String -> Msg) -> Html Msg
viewStateSelect currentState toMsg =
    div []
        [ label [ class "type-body-small block mb-1" ] [ text (t FormStatus) ]
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
            , class "px-4 py-2 bg-brand text-white rounded hover:opacity-90 disabled:opacity-50"
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
            , class "px-4 py-2 border rounded hover:bg-bg-subtle"
            ]
            [ text (t FormCancel) ]
        ]



-- ── SHARED FIELD HELPERS ─────────────────────────────────────────────────────


fieldText : String -> String -> String -> Bool -> (String -> String -> Msg) -> Html Msg
fieldText fieldId labelText val required toMsg =
    div []
        [ label [ for fieldId, class "type-body-small block mb-1" ]
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


fieldTextarea : String -> String -> String -> (String -> String -> Msg) -> Html Msg
fieldTextarea fieldId labelText val toMsg =
    div []
        [ label [ for fieldId, class "type-body-small block mb-1" ] [ text labelText ]
        , textarea
            [ id fieldId
            , value val
            , onInput (toMsg fieldId)
            , Html.Attributes.rows 4
            , class "w-full border rounded px-2 py-1"
            ]
            []
        ]



-- ── FILE INPUT DECODER ───────────────────────────────────────────────────────


fileDecoder : Json.Decoder File
fileDecoder =
    Json.at [ "target", "files" ] (Json.index 0 File.decoder)
