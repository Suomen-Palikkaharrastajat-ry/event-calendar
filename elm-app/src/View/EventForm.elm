module View.EventForm exposing (view, viewEdit)

{-| Event create and edit form views.
-}

import Api
import Component.Button as Button
import Component.LoadState as LoadState
import DatePicker
import FeatherIcons
import File exposing (File)
import Html exposing (Html, div, h2, img, input, label, p, text, textarea)
import Html.Attributes exposing (accept, alt, checked, class, disabled, for, id, name, src, step, type_, value)
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
import View.FinnishDatePicker as FinnishDatePicker
import View.Icons exposing (featherIcon)
import View.MapWidget


{-| Message constructors that differ between the Create and Edit form contexts.
Parametrizing these avoids duplicating every view section.
-}
type alias FormMsgs =
    { onFieldChanged : String -> String -> Msg
    , onDateChanged : String -> String -> Msg
    , onStartDatePickerChanged : DatePicker.Msg -> Msg
    , onEndDatePickerChanged : DatePicker.Msg -> Msg
    , onFileSelected : File -> Msg
    , onToggleAllDay : Msg
    , onToggleCancelled : Msg
    , onToggleGeocode : Msg
    , onGeocode : Msg
    , allDayCheckboxId : String
    , cancelledCheckboxId : String
    , startDateInputId : String
    , endDateInputId : String
    , mapContainerId : String
    }


createFormMsgs : FormMsgs
createFormMsgs =
    { onFieldChanged = EventsFormFieldChanged
    , onDateChanged = EventsFormDateChanged
    , onStartDatePickerChanged = EventsStartDatePickerChanged
    , onEndDatePickerChanged = EventsEndDatePickerChanged
    , onFileSelected = EventsFormFileSelected
    , onToggleAllDay = EventsFormToggleAllDay
    , onToggleCancelled = EventsFormToggleCancelled
    , onToggleGeocode = EventsFormToggleGeocode
    , onGeocode = EventsFormGeocode
    , allDayCheckboxId = "allday-create"
    , cancelledCheckboxId = "cancelled-create"
    , startDateInputId = "start-date-create"
    , endDateInputId = "end-date-create"
    , mapContainerId = "create-map"
    }


editFormMsgs : FormMsgs
editFormMsgs =
    { onFieldChanged = EditFormFieldChanged
    , onDateChanged = EditFormDateChanged
    , onStartDatePickerChanged = EditStartDatePickerChanged
    , onEndDatePickerChanged = EditEndDatePickerChanged
    , onFileSelected = EditFormFileSelected
    , onToggleAllDay = EditFormToggleAllDay
    , onToggleCancelled = EditFormToggleCancelled
    , onToggleGeocode = EditFormToggleGeocode
    , onGeocode = EditFormGeocode
    , allDayCheckboxId = "allday-edit"
    , cancelledCheckboxId = "cancelled-edit"
    , startDateInputId = "start-date-edit"
    , endDateInputId = "end-date-edit"
    , mapContainerId = "edit-map"
    }


{-| Create-event form (used inside the events management page).
Field messages use `EventsForm*` prefix.
-}
view : EventFormData -> DatePicker.DatePicker -> DatePicker.DatePicker -> FormStatus -> Bool -> Html Msg
view formData startDatePicker endDatePicker formStatus isEdit =
    viewSharedFields createFormMsgs formData startDatePicker endDatePicker formStatus isEdit


{-| Standalone edit-event page, wrapping the shared form fields with Edit-prefix messages.
-}
viewEdit : EventEditPage -> Html Msg
viewEdit editPage =
    div [ class "max-w-2xl mx-auto p-4" ]
        [ h2 [ class "type-h3 mb-4" ] [ text (t FormEditTitle) ]
        , LoadState.view
            { loadingLabel = t Loading
            , errorMessage = Api.httpErrorToString
            , onRetry = Nothing
            , retryLabel = ""
            }
            (fromRemoteData editPage.event)
            (\_ ->
                viewSharedFields editFormMsgs editPage.form editPage.startDatePicker editPage.endDatePicker editPage.formStatus True
            )
        ]


fromRemoteData : RemoteData.RemoteData e a -> LoadState.State e a
fromRemoteData rd =
    case rd of
        RemoteData.NotAsked ->
            LoadState.NotAsked

        RemoteData.Loading ->
            LoadState.Loading

        RemoteData.Failure e ->
            LoadState.Failure e

        RemoteData.Success a ->
            LoadState.Success a



-- ── Shared field layout ───────────────────────────────────────────────────────


{-| Renders all form fields using the given message set.
`isEdit` controls the submit button label and whether to show existing-image previews.
-}
viewSharedFields : FormMsgs -> EventFormData -> DatePicker.DatePicker -> DatePicker.DatePicker -> FormStatus -> Bool -> Html Msg
viewSharedFields msgs form startDatePicker endDatePicker formStatus isEdit =
    div [ class "flex flex-col gap-4" ]
        [ fieldText "title" (t FormTitle) form.title True msgs.onFieldChanged
        , fieldText "location" (t FormLocation) form.location False msgs.onFieldChanged
        , viewGeocodeSection msgs form
        , fieldTextarea "description" (t FormDescription) form.description msgs.onFieldChanged
        , fieldText "url" (t FormUrl) form.url False msgs.onFieldChanged
        , viewImageSection msgs isEdit form
        , viewDateSection msgs form startDatePicker endDatePicker
        , viewTagSelect form.tag (\v -> msgs.onFieldChanged "tag" v)
        , viewCancelledCheckbox msgs form
        , viewStateSelect form.state (\v -> msgs.onFieldChanged "state" v)
        , viewFormButtons formStatus isEdit
        ]



-- ── Shared section views ──────────────────────────────────────────────────────


viewGeocodeSection : FormMsgs -> EventFormData -> Html Msg
viewGeocodeSection msgs form =
    div [ class "flex flex-col gap-2" ]
        [ div [ class "flex items-center gap-2" ]
            [ Button.new { label = t FormGeocode, onClick = msgs.onGeocode }
                |> Button.withVariant Button.Primary
                |> Button.withSize Button.Small
                |> Button.withIcon FeatherIcons.mapPin
                |> Button.withDisabled (String.isEmpty (String.trim form.location))
                |> Button.toHtml
            ]
        , div [ class "flex gap-2" ]
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
            , class "type-caption file:mr-3 file:px-3 file:py-2 file:rounded file:border file:border-border-default file:bg-bg-subtle file:text-text-primary file:font-medium hover:file:bg-brand-yellow hover:file:text-brand focus-visible:ring-2 focus-visible:ring-brand"
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


viewDateSection : FormMsgs -> EventFormData -> DatePicker.DatePicker -> DatePicker.DatePicker -> Html Msg
viewDateSection msgs form startDatePicker endDatePicker =
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
                [ label
                    [ class "type-caption text-text-muted block mb-1"
                    , for msgs.startDateInputId
                    ]
                    [ text (t FormStartDate) ]
                , FinnishDatePicker.view
                    { picker = startDatePicker
                    , selectedIsoDate = form.startDate
                    , inputId = msgs.startDateInputId
                    }
                    |> Html.map msgs.onStartDatePickerChanged
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
                [ label
                    [ class "type-caption text-text-muted block mb-1"
                    , for msgs.endDateInputId
                    ]
                    [ text (t FormEndDate) ]
                , FinnishDatePicker.view
                    { picker = endDatePicker
                    , selectedIsoDate = form.endDate
                    , inputId = msgs.endDateInputId
                    }
                    |> Html.map msgs.onEndDatePickerChanged
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


viewTagSelect : String -> (String -> Msg) -> Html Msg
viewTagSelect currentTag toMsg =
    div [ class "flex flex-col gap-2" ]
        [ label [ class "type-body-small" ] [ text (t FormTag) ]
        , div [ class "flex flex-wrap gap-3" ]
            [ viewTagRadio "event-tag-none" "event-tag" "" (t TagNone) currentTag toMsg
            , viewTagRadio "event-tag-exhibition" "event-tag" "exhibition" (t TagExhibition) currentTag toMsg
            , viewTagRadio "event-tag-event" "event-tag" "event" (t TagEvent) currentTag toMsg
            , viewTagRadio "event-tag-competition" "event-tag" "competition" (t TagCompetition) currentTag toMsg
            ]
        ]


viewTagRadio : String -> String -> String -> String -> String -> (String -> Msg) -> Html Msg
viewTagRadio inputId groupName radioValue labelText currentValue toMsg =
    label
        [ for inputId
        , class "inline-flex items-center gap-2 border border-border-default rounded px-3 py-2 type-caption"
        ]
        [ input
            [ type_ "radio"
            , id inputId
            , name groupName
            , value radioValue
            , checked (currentValue == radioValue)
            , onClick (toMsg radioValue)
            ]
            []
        , text labelText
        ]


viewCancelledCheckbox : FormMsgs -> EventFormData -> Html Msg
viewCancelledCheckbox msgs form =
    div [ class "flex items-center gap-2 mb-2" ]
        [ input
            [ type_ "checkbox"
            , checked form.cancelled
            , onCheck (\_ -> msgs.onToggleCancelled)
            , id msgs.cancelledCheckboxId
            ]
            []
        , label [ for msgs.cancelledCheckboxId, class "type-body-small" ] [ text (t FormCancelled) ]
        ]


{-| State radios for the form.
Note: `Deleted` is intentionally absent — deletion is a separate action
(via the event-detail page), not a state the user sets while creating/editing.
-}
viewStateSelect : EventState -> (String -> Msg) -> Html Msg
viewStateSelect currentState toMsg =
    div [ class "flex flex-col gap-2" ]
        [ label [ class "type-body-small" ] [ text (t FormStatus) ]
        , div [ class "flex flex-wrap gap-3" ]
            [ viewStateRadio "event-state-draft" "event-state" Draft currentState toMsg
            , viewStateRadio "event-state-pending" "event-state" Pending currentState toMsg
            , viewStateRadio "event-state-published" "event-state" Published currentState toMsg
            ]
        ]


viewStateRadio : String -> String -> EventState -> EventState -> (String -> Msg) -> Html Msg
viewStateRadio inputId groupName radioState currentState toMsg =
    label
        [ for inputId
        , class "inline-flex items-center gap-2 border border-border-default rounded px-3 py-2 type-caption"
        ]
        [ input
            [ type_ "radio"
            , id inputId
            , name groupName
            , checked (currentState == radioState)
            , onClick (toMsg (Types.eventStateToString radioState))
            ]
            []
        , text (stateLabel radioState)
        ]


viewFormButtons : FormStatus -> Bool -> Html Msg
viewFormButtons formStatus isEdit =
    div [ class "flex gap-2 pt-2" ]
        [ Button.new
            { label =
                if formStatus == FormSubmitting then
                    t Saving

                else
                    t FormSave
            , onClick =
                if isEdit then
                    EditFormSubmit

                else
                    EventsFormSubmit
            }
            |> Button.withVariant Button.Primary
            |> Button.withSize Button.Medium
            |> Button.withDisabled (formStatus == FormSubmitting)
            |> Button.withLoading (formStatus == FormSubmitting)
            |> Button.toHtml
        , Button.new
            { label = t FormCancel
            , onClick = NavigateTo RouteEvents
            }
            |> Button.withVariant Button.Secondary
            |> Button.withSize Button.Medium
            |> Button.toHtml
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
