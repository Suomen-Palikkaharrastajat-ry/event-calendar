module View.EventForm exposing (view, viewEdit)

{-| Event create and edit form views.
-}

import Api
import Component.Alert as Alert
import Component.Button as Button
import Component.Form as Form
import Component.LoadState as LoadState
import DatePicker
import FeatherIcons
import File exposing (File)
import FinnishDatePicker
import Html exposing (Html, div, h2, text)
import Html.Attributes exposing (class)
import Html.Events exposing (onSubmit)
import I18n exposing (MsgKey(..), stateLabel, t)
import Lang exposing (Lang)
import RemoteData
import Route exposing (Route(..))
import Types
    exposing
        ( EventEditPage
        , EventFormData
        , EventState(..)
        , FormStatus(..)
        , Msg(..)
        )
import View.MapWidget


{-| Message constructors that differ between the Create and Edit form contexts.
Parametrizing these avoids duplicating every (view lang) section.
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
view : Lang -> EventFormData -> DatePicker.DatePicker -> DatePicker.DatePicker -> FormStatus -> Bool -> Html Msg
view lang formData startDatePicker endDatePicker formStatus isEdit =
    viewSharedFields lang createFormMsgs formData startDatePicker endDatePicker formStatus isEdit


{-| Standalone edit-event page, wrapping the shared form fields with Edit-prefix messages.
-}
viewEdit : Lang -> EventEditPage -> Html Msg
viewEdit lang editPage =
    div [ class "max-w-2xl mx-auto p-4" ]
        [ h2 [ class "type-h3 mb-4" ] [ text (t lang FormEditTitle) ]
        , LoadState.view
            { loadingLabel = t lang Loading
            , errorMessage = Api.httpErrorToString lang
            , onRetry = Nothing
            , retryLabel = ""
            }
            (fromRemoteData editPage.event)
            (\_ ->
                viewSharedFields lang editFormMsgs editPage.form editPage.startDatePicker editPage.endDatePicker editPage.formStatus True
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
`isEdit` controls the submit button target and whether to show existing-image previews.
-}
viewSharedFields : Lang -> FormMsgs -> EventFormData -> DatePicker.DatePicker -> DatePicker.DatePicker -> FormStatus -> Bool -> Html Msg
viewSharedFields lang msgs form startDatePicker endDatePicker formStatus isEdit =
    Html.form
        [ onSubmit
            (if isEdit then
                EditFormSubmit

             else
                EventsFormSubmit
            )
        , class "flex flex-col gap-4"
        ]
        [ Form.textInput
            (let
                field =
                    Form.defaultField "title" (t lang FormTitle)
             in
             { field | required = True }
            )
            { value = form.title
            , onInput = msgs.onFieldChanged "title"
            , inputType = Form.Text
            , placeholder = Nothing
            }
        , Form.textInput
            (Form.defaultField "location" (t lang FormLocation))
            { value = form.location
            , onInput = msgs.onFieldChanged "location"
            , inputType = Form.Text
            , placeholder = Nothing
            }
        , viewGeocodeSection lang msgs form
        , Form.textarea
            (Form.defaultField "description" (t lang FormDescription))
            { value = form.description
            , onInput = msgs.onFieldChanged "description"
            , rows = 4
            }
        , Form.textInput
            (Form.defaultField "url" (t lang FormUrl))
            { value = form.url
            , onInput = msgs.onFieldChanged "url"
            , inputType = Form.Url
            , placeholder = Nothing
            }
        , viewImageSection lang msgs isEdit form
        , viewDateSection lang msgs form startDatePicker endDatePicker
        , viewTagSelect lang form.tag (msgs.onFieldChanged "tag")
        , Form.checkbox
            (Form.defaultField msgs.cancelledCheckboxId (t lang FormCancelled))
            { checked = form.cancelled
            , onCheck = \_ -> msgs.onToggleCancelled
            }
        , viewStateSelect lang form.state (msgs.onFieldChanged "state")
        , viewInlineError formStatus
        , viewFormButtons lang formStatus
        ]



-- ── Shared section views ──────────────────────────────────────────────────────


viewGeocodeSection : Lang -> FormMsgs -> EventFormData -> Html Msg
viewGeocodeSection lang msgs form =
    div [ class "flex flex-col gap-2" ]
        [ div [ class "flex items-center gap-2" ]
            [ Button.new { label = t lang FormGeocode, onClick = msgs.onGeocode }
                |> Button.withVariant Button.Primary
                |> Button.withSize Button.Small
                |> Button.withIcon FeatherIcons.mapPin
                |> Button.withDisabled (String.isEmpty (String.trim form.location))
                |> Button.toHtml
            ]
        , div [ class "flex gap-2" ]
            [ div [ class "flex-1" ]
                [ Form.textInput
                    (Form.defaultField (msgs.mapContainerId ++ "-lat") (t lang FormLat))
                    { value = form.lat
                    , onInput = msgs.onFieldChanged "lat"
                    , inputType = Form.Number { step = "0.000001" }
                    , placeholder = Nothing
                    }
                ]
            , div [ class "flex-1" ]
                [ Form.textInput
                    (Form.defaultField (msgs.mapContainerId ++ "-lon") (t lang FormLon))
                    { value = form.lon
                    , onInput = msgs.onFieldChanged "lon"
                    , inputType = Form.Number { step = "0.000001" }
                    , placeholder = Nothing
                    }
                ]
            ]
        , View.MapWidget.view { containerId = msgs.mapContainerId }
        ]


viewImageSection : Lang -> FormMsgs -> Bool -> EventFormData -> Html Msg
viewImageSection lang msgs showExistingIfPresent form =
    let
        preview =
            case form.imagePreviewUrl of
                Just previewUrl ->
                    Just { src = previewUrl, alt = "Esikatselu" }

                Nothing ->
                    if showExistingIfPresent && form.hasExistingImage then
                        case form.existingImageUrl of
                            Just url ->
                                Just { src = url, alt = t lang FormCurrentImage }

                            Nothing ->
                                Nothing

                    else
                        Nothing
    in
    div [ class "flex flex-col gap-2" ]
        [ Form.fileInput
            (Form.defaultField "image" (t lang FormImage))
            { accept = "image/*"
            , onFile = msgs.onFileSelected
            , preview = preview
            }
        , Form.textInput
            (Form.defaultField "imageDescription" (t lang FormImageAlt))
            { value = form.imageDescription
            , onInput = msgs.onFieldChanged "imageDescription"
            , inputType = Form.Text
            , placeholder = Nothing
            }
        ]


viewDateSection : Lang -> FormMsgs -> EventFormData -> DatePicker.DatePicker -> DatePicker.DatePicker -> Html Msg
viewDateSection lang msgs form startDatePicker endDatePicker =
    div [ class "flex flex-col gap-2" ]
        [ Form.checkbox
            (Form.defaultField msgs.allDayCheckboxId (t lang FormAllDay))
            { checked = form.allDay
            , onCheck = \_ -> msgs.onToggleAllDay
            }
        , Form.fieldRow
            ([ FinnishDatePicker.field (I18n.locale lang)
                (FinnishDatePicker.defaultField msgs.startDateInputId (t lang FormStartDate))
                { picker = startDatePicker
                , selectedIsoDate = form.startDate
                , onMsg = msgs.onStartDatePickerChanged
                }
             ]
                ++ (if not form.allDay then
                        [ Form.textInput
                            (Form.defaultField (msgs.startDateInputId ++ "-time") (t lang FormStartTime))
                            { value = form.startTime
                            , onInput = msgs.onDateChanged "startTime"
                            , inputType = Form.Time
                            , placeholder = Nothing
                            }
                        ]

                    else
                        []
                   )
                ++ [ FinnishDatePicker.field (I18n.locale lang)
                        (FinnishDatePicker.defaultField msgs.endDateInputId (t lang FormEndDate))
                        { picker = endDatePicker
                        , selectedIsoDate = form.endDate
                        , onMsg = msgs.onEndDatePickerChanged
                        }
                   ]
                ++ (if not form.allDay then
                        [ Form.textInput
                            (Form.defaultField (msgs.endDateInputId ++ "-time") (t lang FormEndTime))
                            { value = form.endTime
                            , onInput = msgs.onDateChanged "endTime"
                            , inputType = Form.Time
                            , placeholder = Nothing
                            }
                        ]

                    else
                        []
                   )
            )
        ]


viewTagSelect : Lang -> String -> (String -> Msg) -> Html Msg
viewTagSelect lang currentTag toMsg =
    Form.radioGroup
        { legend = t lang FormTag
        , name = "event-tag"
        , required = False
        , error = Nothing
        }
        { options =
            [ { value = "", label = t lang TagNone }
            , { value = "exhibition", label = t lang TagExhibition }
            , { value = "event", label = t lang TagEvent }
            , { value = "competition", label = t lang TagCompetition }
            ]
        , selected = currentTag
        , onSelect = toMsg
        , layout = Form.Chips
        }


viewStateSelect : Lang -> EventState -> (String -> Msg) -> Html Msg
viewStateSelect lang currentState toMsg =
    Form.radioGroup
        { legend = t lang FormStatus
        , name = "event-state"
        , required = False
        , error = Nothing
        }
        { options =
            [ { value = Types.eventStateToString Draft, label = stateLabel lang Draft }
            , { value = Types.eventStateToString Pending, label = stateLabel lang Pending }
            , { value = Types.eventStateToString Published, label = stateLabel lang Published }
            ]
        , selected = Types.eventStateToString currentState
        , onSelect = toMsg
        , layout = Form.Chips
        }


viewInlineError : FormStatus -> Html msg
viewInlineError formStatus =
    case formStatus of
        FormError err ->
            div [ Html.Attributes.attribute "role" "alert" ]
                [ Alert.view
                    { alertType = Alert.Error
                    , title = Nothing
                    , body = [ text err ]
                    , onDismiss = Nothing
                    , customIcon = Nothing
                    }
                ]

        _ ->
            text ""


viewFormButtons : Lang -> FormStatus -> Html Msg
viewFormButtons lang formStatus =
    div [ class "flex gap-2 pt-2" ]
        [ Button.submit
            { label =
                if formStatus == FormSubmitting then
                    t lang Saving

                else
                    t lang FormSave
            }
            |> Button.withVariant Button.Primary
            |> Button.withSize Button.Medium
            |> Button.withDisabled (formStatus == FormSubmitting)
            |> Button.withLoading (formStatus == FormSubmitting)
            |> Button.toHtml
        , Button.new
            { label = t lang FormCancel
            , onClick = NavigateTo RouteEvents
            }
            |> Button.withVariant Button.Secondary
            |> Button.withSize Button.Medium
            |> Button.toHtml
        ]
