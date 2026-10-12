module EventFormTest exposing (suite)

{-| Unit tests for EventForm accessibility and structure.
-}

import DatePicker
import Expect
import Html.Attributes
import Lang
import RemoteData
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import Types exposing (EventEditPage, EventFormData, EventState(..), FormStatus(..), emptyEventFormData)
import View.EventForm as EventForm


dummyPicker : DatePicker.DatePicker
dummyPicker =
    Tuple.first DatePicker.init


testFormHtml : EventFormData -> FormStatus -> Query.Single Types.Msg
testFormHtml formData formStatus =
    EventForm.view Lang.Fi formData dummyPicker dummyPicker formStatus False
        |> Query.fromHtml


suite : Test
suite =
    describe "View.EventForm"
        [ describe "Form wrapper and buttons"
            [ test "renders a form element" <|
                \_ ->
                    testFormHtml emptyEventFormData FormIdle
                        |> Query.has [ Selector.tag "form" ]
            , test "renders a submit button with type=submit" <|
                \_ ->
                    testFormHtml emptyEventFormData FormIdle
                        |> Query.find [ Selector.tag "button", Selector.attribute (Html.Attributes.type_ "submit") ]
                        |> Query.has [ Selector.text "Tallenna" ]
            , test "renders a cancel button with type=button" <|
                \_ ->
                    testFormHtml emptyEventFormData FormIdle
                        |> Query.find [ Selector.tag "button", Selector.attribute (Html.Attributes.type_ "button"), Selector.containing [ Selector.text "Peruuta" ] ]
                        |> Query.has [ Selector.text "Peruuta" ]
            ]
        , describe "Accessible form controls"
            [ test "title field is marked required" <|
                \_ ->
                    testFormHtml emptyEventFormData FormIdle
                        |> Query.find [ Selector.id "title" ]
                        |> Query.has [ Selector.attribute (Html.Attributes.required True) ]
            , test "title input has associated label" <|
                \_ ->
                    testFormHtml emptyEventFormData FormIdle
                        |> Query.find [ Selector.tag "label", Selector.attribute (Html.Attributes.for "title") ]
                        |> Query.has [ Selector.text "Tapahtuman nimi" ]
            , test "location input has associated label" <|
                \_ ->
                    testFormHtml emptyEventFormData FormIdle
                        |> Query.find [ Selector.tag "label", Selector.attribute (Html.Attributes.for "location") ]
                        |> Query.has [ Selector.text "Sijainti" ]
            , test "description textarea has associated label" <|
                \_ ->
                    testFormHtml emptyEventFormData FormIdle
                        |> Query.find [ Selector.tag "label", Selector.attribute (Html.Attributes.for "description") ]
                        |> Query.has [ Selector.text "Kuvaus" ]
            , test "url input has type=url and associated label" <|
                \_ ->
                    testFormHtml emptyEventFormData FormIdle
                        |> Query.find [ Selector.id "url" ]
                        |> Query.has [ Selector.attribute (Html.Attributes.type_ "url") ]
            , test "lat input has label matching its id" <|
                \_ ->
                    testFormHtml emptyEventFormData FormIdle
                        |> Query.has
                            [ Selector.tag "label", Selector.attribute (Html.Attributes.for "create-map-lat") ]
            , test "lon input has label matching its id" <|
                \_ ->
                    testFormHtml emptyEventFormData FormIdle
                        |> Query.has
                            [ Selector.tag "label", Selector.attribute (Html.Attributes.for "create-map-lon") ]
            , test "image input has label matching its id" <|
                \_ ->
                    testFormHtml emptyEventFormData FormIdle
                        |> Query.find [ Selector.tag "label", Selector.attribute (Html.Attributes.for "image") ]
                        |> Query.has [ Selector.text "Kuva" ]
            , test "image description has label matching its id" <|
                \_ ->
                    testFormHtml emptyEventFormData FormIdle
                        |> Query.find [ Selector.tag "label", Selector.attribute (Html.Attributes.for "imageDescription") ]
                        |> Query.has [ Selector.text "Kuvan vaihtoehtoinen teksti" ]
            , test "all-day checkbox has associated label" <|
                \_ ->
                    testFormHtml emptyEventFormData FormIdle
                        |> Query.has [ Selector.tag "label", Selector.attribute (Html.Attributes.for "allday-create") ]
            , test "time inputs have labels matching their ids when not all-day" <|
                \_ ->
                    let
                        timedForm =
                            { emptyEventFormData | allDay = False }
                    in
                    testFormHtml timedForm FormIdle
                        |> Query.has
                            [ Selector.tag "label", Selector.attribute (Html.Attributes.for "start-date-create-time") ]
            , test "end time input has label matching its id when not all-day" <|
                \_ ->
                    let
                        timedForm =
                            { emptyEventFormData | allDay = False }
                    in
                    testFormHtml timedForm FormIdle
                        |> Query.has
                            [ Selector.tag "label", Selector.attribute (Html.Attributes.for "end-date-create-time") ]
            , test "cancelled checkbox has associated label" <|
                \_ ->
                    testFormHtml emptyEventFormData FormIdle
                        |> Query.has [ Selector.tag "label", Selector.attribute (Html.Attributes.for "cancelled-create") ]
            ]
        , describe "Fieldsets and legends"
            [ test "renders fieldset and legend for tag radio group" <|
                \_ ->
                    testFormHtml emptyEventFormData FormIdle
                        |> Query.has
                            [ Selector.tag "fieldset"
                            , Selector.tag "legend"
                            ]
            , test "renders radio buttons for state selection" <|
                \_ ->
                    testFormHtml emptyEventFormData FormIdle
                        |> Query.findAll [ Selector.attribute (Html.Attributes.name "event-state") ]
                        |> Query.count (Expect.equal 3)
            ]
        , describe "Inline errors"
            [ test "renders alert when formStatus is FormError" <|
                \_ ->
                    testFormHtml emptyEventFormData (FormError "Tallennus epäonnistui")
                        |> Query.find [ Selector.attribute (Html.Attributes.attribute "role" "alert") ]
                        |> Query.has [ Selector.text "Tallennus epäonnistui" ]
            ]
        , describe "viewEdit"
            [ test "renders edit form when event is loaded" <|
                \_ ->
                    let
                        editPage : EventEditPage
                        editPage =
                            { event = RemoteData.Success (emptyEvent ())
                            , form = emptyEventFormData
                            , startDatePicker = dummyPicker
                            , endDatePicker = dummyPicker
                            , formStatus = FormIdle
                            }
                    in
                    EventForm.viewEdit Lang.Fi editPage
                        |> Query.fromHtml
                        |> Query.has [ Selector.tag "form" ]
            ]
        ]


emptyEvent : () -> Types.Event
emptyEvent _ =
    { id = "test-1"
    , title = "Testi"
    , description = Nothing
    , startDate = "2026-06-01T10:00:00Z"
    , endDate = Nothing
    , allDay = True
    , url = Nothing
    , location = Nothing
    , state = Published
    , cancelled = False
    , image = Nothing
    , imageDescription = Nothing
    , point = Nothing
    , tags = []
    , created = ""
    , updated = ""
    }
