{- Application entry point.

   Pages, routes, and the modules that handle them:

       Route               Page type          State/init module    View module
       ──────────────────  ─────────────────  ───────────────────  ──────────────────
       /                   PageCalendar       Page.Calendar        View.Calendar
       /#/events           PageEventList      (inline in Main)     View.EventList
       /#/events/new       PageEvents         Page.Events          View.Events
       /#/events/:id       PageEventDetail    Page.EventDetail     View.EventDetail
       /#/events/:id/edit  PageEventEdit      Page.EventEdit       View.EventForm
       /#/callback         PageAuthCallback   (inline in Main)     (inline in Main)
       (not found)         PageNotFound       —                    (inline in Main)

   Update logic lives in this file's `update` function.  Page-specific helpers
   (updateCalendarPage, updateEventsForm, updateEditForm) delegate to the relevant
   Page module or modify the model directly.

-}


module Main exposing (applyFormDate, applyFormField, main)

import Api
import Auth
import Browser
import Browser.Events
import Browser.Navigation as Nav
import DateUtils exposing (utcStringToHelsinkiDateInput, utcStringToHelsinkiTimeInput)
import File
import Geocoding
import Html exposing (Html, a, div, text)
import Html.Attributes exposing (class, href)
import Http
import Json.Decode as Json
import Page.Calendar
import Page.EventDetail
import Page.EventEdit
import Page.Events
import Ports
import Process
import RemoteData exposing (RemoteData(..))
import Route exposing (Route(..), parseUrl, toHref)
import Task
import Time
import Types
    exposing
        ( AuthState(..)
        , EventFormData
        , EventListPage
        , Flags
        , KmlImportStatus(..)
        , KmlPlacemark
        , Model
        , Msg(..)
        , Page(..)
        , ToastKind(..)
        , emptyEventFormData
        , emptyPbList
        , getToken
        )
import Url exposing (Url)
import View.EventDetail
import View.EventForm
import View.EventList
import View.Events
import View.Layout


{-| Helsinki Railway Square — default map centre when no event coordinates are available.
-}
helsinkiLat : Float
helsinkiLat =
    60.1699


helsinkiLon : Float
helsinkiLon =
    24.9384


{-| Default map zoom level for the "whole Helsinki area" view.
-}
defaultMapZoom : Int
defaultMapZoom =
    10


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- INIT


init : Flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        route =
            parseUrl url

        authState =
            Auth.restoreAuthFromFlags flags.authToken flags.authModel

        now =
            Time.millisToPosix flags.now

        ( page, cmd ) =
            initPage flags.pbBaseUrl key route authState url now
    in
    ( { key = key
      , url = url
      , page = page
      , authState = authState
      , toasts = []
      , nextToastId = 0
      , now = now
      , pbBaseUrl = flags.pbBaseUrl
      , menuOpen = False
      }
    , cmd
    )


initPage : String -> Nav.Key -> Route -> Types.AuthState -> Url -> Time.Posix -> ( Page, Cmd Msg )
initPage pbBaseUrl key route authState url now =
    case route of
        RouteCalendar maybeDate ->
            let
                ( calPage, calCmd ) =
                    Page.Calendar.init pbBaseUrl maybeDate now
            in
            ( PageCalendar calPage, calCmd )

        RouteEvents ->
            ( PageEventList { events = RemoteData.Loading }
            , Api.fetchPublishedEvents pbBaseUrl EventListGotEvents
            )

        RouteEventNew ->
            case authState of
                Authenticated _ ->
                    ( PageEvents
                        { form = emptyEventFormData
                        , formStatus = Types.FormIdle
                        , kmlImportStatus = KmlIdle
                        , kmlQueue = []
                        }
                    , Ports.initMap
                        { containerId = "create-map"
                        , lat = helsinkiLat
                        , lon = helsinkiLon
                        , zoom = defaultMapZoom
                        , markerLat = Nothing
                        , markerLon = Nothing
                        , draggable = True
                        }
                    )

                NotAuthenticated ->
                    ( PageLoading
                    , Cmd.batch
                        [ Nav.pushUrl key (toHref (RouteCalendar Nothing))
                        , Task.perform identity (Task.succeed (AddToast ToastInfo "Kirjaudu sisään päästäksesi hallintanäkymään"))
                        ]
                    )

        RouteEventDetail id ->
            let
                ( detPage, detCmd ) =
                    Page.EventDetail.init pbBaseUrl (getToken authState) id
            in
            ( PageEventDetail id detPage, detCmd )

        RouteEventEdit id ->
            case authState of
                Authenticated _ ->
                    let
                        ( editPage, editCmd ) =
                            Page.EventEdit.init pbBaseUrl (getToken authState) id
                    in
                    ( PageEventEdit id editPage, editCmd )

                NotAuthenticated ->
                    ( PageLoading
                    , Cmd.batch
                        [ Nav.pushUrl key (toHref (RouteCalendar Nothing))
                        , Task.perform identity (Task.succeed (AddToast ToastInfo "Kirjaudu sisään päästäksesi hallintanäkymään"))
                        ]
                    )

        RouteAuthCallback ->
            ( PageAuthCallback, Ports.getCallbackParams () )

        RouteNotFound ->
            ( PageNotFound, Cmd.none )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        -- ── Navigation ──────────────────────────────────────────────────────────
        UrlChanged url ->
            let
                route =
                    parseUrl url

                -- Destroy any Leaflet map when navigating away from a page that owns one.
                mapCleanupCmd =
                    case model.page of
                        PageEvents _ ->
                            Ports.destroyMap "create-map"

                        PageEventEdit _ _ ->
                            Ports.destroyMap "edit-map"

                        _ ->
                            Cmd.none
            in
            case ( model.page, route ) of
                ( PageCalendar calPage, RouteCalendar maybeDate ) ->
                    -- Calendar month-nav already updated the model; only re-init when
                    -- the URL refers to a *different* month (e.g. browser back/forward).
                    let
                        currentDateStr =
                            String.fromInt calPage.year
                                ++ "-"
                                ++ String.padLeft 2 '0' (String.fromInt calPage.month)
                    in
                    if maybeDate == Just currentDateStr then
                        ( { model | url = url }, Cmd.none )

                    else
                        let
                            ( page, cmd ) =
                                initPage model.pbBaseUrl model.key route model.authState url model.now
                        in
                        ( { model | url = url, page = page }, cmd )

                _ ->
                    let
                        ( page, cmd ) =
                            initPage model.pbBaseUrl model.key route model.authState url model.now
                    in
                    ( { model | url = url, page = page, menuOpen = False }, Cmd.batch [ mapCleanupCmd, cmd ] )

        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        NavigateTo route ->
            ( model, Nav.pushUrl model.key (toHref route) )

        -- ── Auth ────────────────────────────────────────────────────────────────
        LoginClicked ->
            ( model, Ports.initiateOAuth model.pbBaseUrl )

        LogOut ->
            ( { model | authState = NotAuthenticated, menuOpen = False }
            , Cmd.batch
                [ Ports.clearAuthToken ()
                , Nav.pushUrl model.key (toHref (RouteCalendar Nothing))
                ]
            )

        GotOAuthUrl _ ->
            ( model, Cmd.none )

        ReceivedAuthToken _ ->
            ( model, Cmd.none )

        AuthCallbackReceived codeVerifier _ ->
            let
                code =
                    extractCode model.url
            in
            case code of
                Just c ->
                    ( model, Auth.fetchOAuthToken model.pbBaseUrl c codeVerifier "" )

                Nothing ->
                    ( model, Nav.pushUrl model.key (toHref (RouteCalendar Nothing)) )

        GotAuthResult (Ok user) ->
            let
                modelJson =
                    "{\"id\":\""
                        ++ user.id
                        ++ "\",\"name\":\""
                        ++ user.name
                        ++ "\",\"email\":\""
                        ++ user.email
                        ++ "\"}"

                ( model1, toastCmd ) =
                    addToast { model | authState = Authenticated user } ToastSuccess "Kirjautuminen onnistui"
            in
            ( model1
            , Cmd.batch
                [ Ports.saveAuthToken { token = user.token, model = modelJson }
                , Nav.pushUrl model.key (toHref RouteEvents)
                , toastCmd
                ]
            )

        GotAuthResult (Err _) ->
            let
                ( model1, toastCmd ) =
                    addToast model ToastError "Kirjautuminen epäonnistui"
            in
            ( model1
            , Cmd.batch
                [ Nav.pushUrl model.key (toHref (RouteCalendar Nothing))
                , toastCmd
                ]
            )

        OAuthPopupResult data ->
            if String.isEmpty data.token then
                let
                    ( model1, toastCmd ) =
                        addToast model ToastError "Kirjautuminen epäonnistui"
                in
                ( model1
                , Cmd.batch
                    [ Nav.pushUrl model.key (toHref (RouteCalendar Nothing))
                    , toastCmd
                    ]
                )

            else
                case Json.decodeString Auth.decodeAuthUser data.model of
                    Ok user ->
                        let
                            authedUser =
                                { user | token = data.token }

                            ( model1, toastCmd ) =
                                addToast
                                    { model | authState = Authenticated authedUser }
                                    ToastSuccess
                                    "Kirjautuminen onnistui"
                        in
                        ( model1
                        , Cmd.batch
                            [ Ports.saveAuthToken { token = data.token, model = data.model }
                            , Nav.pushUrl model.key (toHref RouteEvents)
                            , toastCmd
                            ]
                        )

                    Err _ ->
                        let
                            ( model1, toastCmd ) =
                                addToast model ToastError "Kirjautuminen epäonnistui"
                        in
                        ( model1, toastCmd )

        -- ── Event list page ──────────────────────────────────────────────────────
        EventListGotEvents result ->
            case model.page of
                PageEventList _ ->
                    ( { model | page = PageEventList { events = RemoteData.fromResult result } }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        -- ── Calendar page ────────────────────────────────────────────────────────
        CalendarGotEvents _ ->
            updateCalendarPage msg model

        CalendarSetMonth year month ->
            let
                ( model1, calCmd ) =
                    updateCalendarPage msg model

                dateStr =
                    String.fromInt year ++ "-" ++ String.padLeft 2 '0' (String.fromInt month)
            in
            ( model1, Cmd.batch [ calCmd, Nav.replaceUrl model.key (toHref (RouteCalendar (Just dateStr))) ] )

        CalendarSetView _ ->
            updateCalendarPage msg model

        CalendarClickEvent id ->
            ( model, Nav.pushUrl model.key (toHref (RouteEventDetail id)) )

        -- ── Events page ──────────────────────────────────────────────────────────
        EventsFormFieldChanged field val ->
            updateEventsForm model (applyFormField field val)

        EventsFormDateChanged field val ->
            updateEventsForm model (applyFormDate field val)

        EventsFormFileSelected file ->
            let
                ( model1, _ ) =
                    updateEventsForm model (\form -> { form | imageFile = Just file })
            in
            ( model1, Task.perform GotImagePreview (File.toUrl file) )

        EventsFormToggleAllDay ->
            updateEventsForm model
                (\form ->
                    { form
                        | allDay = not form.allDay
                        , startTime =
                            if not form.allDay then
                                ""

                            else
                                form.startTime
                        , endTime =
                            if not form.allDay then
                                ""

                            else
                                form.endTime
                    }
                )

        EventsFormToggleGeocode ->
            updateEventsForm model (\form -> { form | geocodingEnabled = not form.geocodingEnabled })

        EventsFormGeocode ->
            case model.page of
                PageEvents evPage ->
                    ( model, Geocoding.geocode evPage.form.location EventsFormGotGeocode )

                _ ->
                    ( model, Cmd.none )

        EventsFormGotGeocode result ->
            case result of
                Ok (Just pt) ->
                    let
                        ( model1, _ ) =
                            updateEventsForm model
                                (\form -> { form | lat = String.fromFloat pt.lat, lon = String.fromFloat pt.lon })
                    in
                    ( model1, Ports.setMapMarker { lat = pt.lat, lon = pt.lon } )

                _ ->
                    ( model, Cmd.none )

        EventsFormSubmit ->
            case ( model.page, getToken model.authState ) of
                ( PageEvents evPage, Just token ) ->
                    if String.isEmpty (String.trim evPage.form.title) then
                        ( model, Cmd.none )

                    else
                        ( { model | page = PageEvents { evPage | formStatus = Types.FormSubmitting } }
                        , Api.createEvent model.pbBaseUrl token evPage.form EventsFormGotSave
                        )

                _ ->
                    ( model, Cmd.none )

        EventsFormGotSave result ->
            case model.page of
                PageEvents evPage ->
                    case result of
                        Ok _ ->
                            let
                                ( model1, toastCmd ) =
                                    addToast
                                        { model
                                            | page =
                                                PageEvents
                                                    { evPage
                                                        | formStatus = Types.FormSuccess
                                                        , form = emptyEventFormData
                                                    }
                                        }
                                        ToastSuccess
                                        "Tapahtuma tallennettu"
                            in
                            ( model1
                            , Cmd.batch
                                [ toastCmd
                                , Nav.pushUrl model.key (toHref RouteEvents)
                                ]
                            )

                        Err err ->
                            let
                                ( model1, toastCmd ) =
                                    addToast
                                        { model | page = PageEvents { evPage | formStatus = Types.FormError (Api.httpErrorToString err) } }
                                        ToastError
                                        (Api.httpErrorToString err)
                            in
                            ( model1, toastCmd )

                _ ->
                    ( model, Cmd.none )

        EventsKmlFileSelected file ->
            ( model, Task.perform EventsKmlGotContent (File.toString file) )

        EventsKmlGotContent content ->
            case model.page of
                PageEvents evPage ->
                    ( { model | page = PageEvents { evPage | kmlImportStatus = KmlParsing } }
                    , Ports.parseKml content
                    )

                _ ->
                    ( model, Cmd.none )

        EventsKmlParsed json ->
            case model.page of
                PageEvents evPage ->
                    let
                        placemarkDecoder =
                            Json.map5 KmlPlacemark
                                (Json.field "name" Json.string)
                                (Json.field "description" Json.string)
                                (Json.field "lat" (Json.nullable Json.float))
                                (Json.field "lon" (Json.nullable Json.float))
                                (Json.field "dateStr" (Json.nullable Json.string))

                        placemarks =
                            case Json.decodeValue (Json.list placemarkDecoder) json of
                                Ok ps ->
                                    ps

                                Err _ ->
                                    []

                        total =
                            List.length placemarks
                    in
                    if total == 0 then
                        ( { model | page = PageEvents { evPage | kmlImportStatus = KmlDone 0 } }
                        , Cmd.none
                        )

                    else
                        ( { model
                            | page =
                                PageEvents
                                    { evPage
                                        | kmlImportStatus = KmlImporting 0 total
                                        , kmlQueue = placemarks
                                    }
                          }
                        , Task.perform identity (Task.succeed EventsKmlImportNext)
                        )

                _ ->
                    ( model, Cmd.none )

        EventsKmlImportNext ->
            case ( model.page, getToken model.authState ) of
                ( PageEvents evPage, Just token ) ->
                    case evPage.kmlQueue of
                        [] ->
                            let
                                done =
                                    case evPage.kmlImportStatus of
                                        KmlImporting n _ ->
                                            n

                                        _ ->
                                            0
                            in
                            ( { model | page = PageEvents { evPage | kmlImportStatus = KmlDone done } }
                            , Cmd.none
                            )

                        placemark :: rest ->
                            let
                                form =
                                    placemarkToForm placemark
                            in
                            ( { model | page = PageEvents { evPage | kmlQueue = rest } }
                            , Api.createEvent model.pbBaseUrl token form EventsKmlGotImport
                            )

                _ ->
                    ( model, Cmd.none )

        EventsKmlGotImport result ->
            case model.page of
                PageEvents evPage ->
                    case result of
                        Ok _ ->
                            let
                                ( done, total ) =
                                    case evPage.kmlImportStatus of
                                        KmlImporting n t ->
                                            ( n + 1, t )

                                        _ ->
                                            ( 1, 1 )
                            in
                            if List.isEmpty evPage.kmlQueue then
                                let
                                    ( model1, toastCmd ) =
                                        addToast
                                            { model | page = PageEvents { evPage | kmlImportStatus = KmlDone done } }
                                            ToastSuccess
                                            (String.fromInt done ++ " tapahtumaa tuotu")
                                in
                                ( model1, toastCmd )

                            else
                                ( { model | page = PageEvents { evPage | kmlImportStatus = KmlImporting done total } }
                                , Task.perform identity (Task.succeed EventsKmlImportNext)
                                )

                        Err err ->
                            ( { model | page = PageEvents { evPage | kmlImportStatus = KmlError (Api.httpErrorToString err) } }
                            , Cmd.none
                            )

                _ ->
                    ( model, Cmd.none )

        -- ── Event detail page ────────────────────────────────────────────────────
        DetailGotEvent result ->
            case model.page of
                PageEventDetail id detPage ->
                    case result of
                        Ok event ->
                            ( { model | page = PageEventDetail id { detPage | event = Success event } }
                            , Cmd.none
                            )

                        Err (Http.BadStatus 404) ->
                            ( { model | page = PageNotFound }, Cmd.none )

                        Err err ->
                            let
                                ( model1, toastCmd ) =
                                    addToast model ToastError (Api.httpErrorToString err)
                            in
                            ( { model1 | page = PageEventDetail id { detPage | event = Failure err } }
                            , toastCmd
                            )

                _ ->
                    ( model, Cmd.none )

        DetailRequestDelete ->
            case model.page of
                PageEventDetail id detPage ->
                    ( { model | page = PageEventDetail id { detPage | deleteConfirm = True } }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        DetailConfirmDelete ->
            case ( model.page, getToken model.authState ) of
                ( PageEventDetail _ detPage, Just token ) ->
                    case detPage.event of
                        Success event ->
                            ( model, Api.deleteEvent model.pbBaseUrl token event.id DetailGotDelete )

                        _ ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        DetailGotDelete result ->
            case result of
                Ok () ->
                    let
                        ( model1, toastCmd ) =
                            addToast model ToastSuccess "Tapahtuma poistettu"
                    in
                    ( model1
                    , Cmd.batch
                        [ toastCmd
                        , Nav.pushUrl model.key (toHref RouteEvents)
                        ]
                    )

                Err err ->
                    addToast model ToastError (Api.httpErrorToString err)

        DetailKeyPressed key ->
            case model.page of
                PageEventDetail id _ ->
                    case key of
                        "e" ->
                            case model.authState of
                                Authenticated _ ->
                                    ( model, Nav.pushUrl model.key (toHref (RouteEventEdit id)) )

                                NotAuthenticated ->
                                    ( model, Cmd.none )

                        "Escape" ->
                            ( model, Nav.back model.key 1 )

                        _ ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        -- ── Event edit page ──────────────────────────────────────────────────────
        EditGotEvent result ->
            case model.page of
                PageEventEdit id editPage ->
                    case result of
                        Ok event ->
                            let
                                form =
                                    eventToForm model.pbBaseUrl event

                                mapLat =
                                    Maybe.map .lat event.point |> Maybe.withDefault helsinkiLat

                                mapLon =
                                    Maybe.map .lon event.point |> Maybe.withDefault helsinkiLon
                            in
                            ( { model | page = PageEventEdit id { editPage | event = Success event, form = form } }
                            , Ports.initMap
                                { containerId = "edit-map"
                                , lat = mapLat
                                , lon = mapLon
                                , zoom = 12
                                , markerLat = Maybe.map .lat event.point
                                , markerLon = Maybe.map .lon event.point
                                , draggable = True
                                }
                            )

                        Err err ->
                            let
                                ( model1, toastCmd ) =
                                    addToast model ToastError (Api.httpErrorToString err)
                            in
                            ( { model1 | page = PageEventEdit id { editPage | event = Failure err } }
                            , toastCmd
                            )

                _ ->
                    ( model, Cmd.none )

        EditFormFieldChanged field val ->
            updateEditForm model (applyFormField field val)

        EditFormDateChanged field val ->
            updateEditForm model (applyFormDate field val)

        EditFormFileSelected file ->
            let
                ( model1, _ ) =
                    updateEditForm model (\form -> { form | imageFile = Just file })
            in
            ( model1, Task.perform GotImagePreview (File.toUrl file) )

        EditFormToggleAllDay ->
            updateEditForm model
                (\form ->
                    { form
                        | allDay = not form.allDay
                        , startTime =
                            if not form.allDay then
                                ""

                            else
                                form.startTime
                        , endTime =
                            if not form.allDay then
                                ""

                            else
                                form.endTime
                    }
                )

        EditFormToggleGeocode ->
            updateEditForm model (\form -> { form | geocodingEnabled = not form.geocodingEnabled })

        EditFormGeocode ->
            case model.page of
                PageEventEdit _ editPage ->
                    ( model, Geocoding.geocode editPage.form.location EditFormGotGeocode )

                _ ->
                    ( model, Cmd.none )

        EditFormGotGeocode result ->
            case result of
                Ok (Just pt) ->
                    let
                        ( model1, _ ) =
                            updateEditForm model
                                (\form -> { form | lat = String.fromFloat pt.lat, lon = String.fromFloat pt.lon })
                    in
                    ( model1, Ports.setMapMarker { lat = pt.lat, lon = pt.lon } )

                _ ->
                    ( model, Cmd.none )

        EditFormSubmit ->
            case ( model.page, getToken model.authState ) of
                ( PageEventEdit id editPage, Just token ) ->
                    if String.isEmpty (String.trim editPage.form.title) then
                        ( model, Cmd.none )

                    else
                        ( { model | page = PageEventEdit id { editPage | formStatus = Types.FormSubmitting } }
                        , Api.updateEvent model.pbBaseUrl token id editPage.form EditFormGotSave
                        )

                _ ->
                    ( model, Cmd.none )

        EditFormGotSave result ->
            case model.page of
                PageEventEdit id editPage ->
                    case result of
                        Ok event ->
                            let
                                ( model1, toastCmd ) =
                                    addToast
                                        { model | page = PageEventEdit id { editPage | formStatus = Types.FormSuccess, event = Success event } }
                                        ToastSuccess
                                        "Tapahtuma tallennettu"
                            in
                            ( model1
                            , Cmd.batch
                                [ toastCmd
                                , Nav.pushUrl model.key (toHref (RouteEventDetail id))
                                ]
                            )

                        Err err ->
                            let
                                ( model1, toastCmd ) =
                                    addToast
                                        { model | page = PageEventEdit id { editPage | formStatus = Types.FormError (Api.httpErrorToString err) } }
                                        ToastError
                                        (Api.httpErrorToString err)
                            in
                            ( model1, toastCmd )

                _ ->
                    ( model, Cmd.none )

        -- ── Maps ─────────────────────────────────────────────────────────────────
        MapMarkerMoved lat lon ->
            case model.page of
                PageEvents evPage ->
                    let
                        form =
                            evPage.form
                    in
                    ( { model | page = PageEvents { evPage | form = { form | lat = String.fromFloat lat, lon = String.fromFloat lon } } }
                    , Geocoding.reverseGeocode lat lon GotReverseGeocode
                    )

                PageEventEdit id editPage ->
                    let
                        form =
                            editPage.form
                    in
                    ( { model | page = PageEventEdit id { editPage | form = { form | lat = String.fromFloat lat, lon = String.fromFloat lon } } }
                    , Geocoding.reverseGeocode lat lon GotReverseGeocode
                    )

                _ ->
                    ( model, Cmd.none )

        GotReverseGeocode (Ok locationName) ->
            case model.page of
                PageEvents evPage ->
                    let
                        form =
                            evPage.form
                    in
                    ( { model | page = PageEvents { evPage | form = { form | location = locationName } } }
                    , Cmd.none
                    )

                PageEventEdit id editPage ->
                    let
                        form =
                            editPage.form
                    in
                    ( { model | page = PageEventEdit id { editPage | form = { form | location = locationName } } }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        GotReverseGeocode (Err _) ->
            ( model, Cmd.none )

        -- ── Image preview ─────────────────────────────────────────────────────────
        GotImagePreview dataUrl ->
            case model.page of
                PageEvents evPage ->
                    let
                        form =
                            evPage.form
                    in
                    ( { model | page = PageEvents { evPage | form = { form | imagePreviewUrl = Just dataUrl } } }
                    , Cmd.none
                    )

                PageEventEdit id editPage ->
                    let
                        form =
                            editPage.form
                    in
                    ( { model | page = PageEventEdit id { editPage | form = { form | imagePreviewUrl = Just dataUrl } } }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        -- ── Toasts ───────────────────────────────────────────────────────────────
        AddToast kind message ->
            addToast model kind message

        DismissToast id ->
            ( { model | toasts = List.filter (\t -> t.id /= id) model.toasts }
            , Cmd.none
            )

        -- ── Mobile menu ──────────────────────────────────────────────────────────
        ToggleMenu ->
            if model.menuOpen then
                ( { model | menuOpen = False }, Cmd.none )

            else
                ( { model | menuOpen = True }, Ports.focusMobileNav () )

        CloseMenu ->
            ( { model | menuOpen = False }, Cmd.none )

        -- ── Time ─────────────────────────────────────────────────────────────────
        Tick _ ->
            ( model, Cmd.none )



-- PAGE-SPECIFIC UPDATE HELPERS


updateCalendarPage : Msg -> Model -> ( Model, Cmd Msg )
updateCalendarPage msg model =
    case model.page of
        PageCalendar calPage ->
            let
                ( newCalPage, cmd ) =
                    Page.Calendar.update msg calPage
            in
            ( { model | page = PageCalendar newCalPage }, cmd )

        _ ->
            ( model, Cmd.none )


updateEventsForm : Model -> (EventFormData -> EventFormData) -> ( Model, Cmd Msg )
updateEventsForm model f =
    case model.page of
        PageEvents evPage ->
            ( { model | page = PageEvents { evPage | form = f evPage.form } }, Cmd.none )

        _ ->
            ( model, Cmd.none )


updateEditForm : Model -> (EventFormData -> EventFormData) -> ( Model, Cmd Msg )
updateEditForm model f =
    case model.page of
        PageEventEdit id editPage ->
            ( { model | page = PageEventEdit id { editPage | form = f editPage.form } }, Cmd.none )

        _ ->
            ( model, Cmd.none )


{-| Apply a text-field update to an EventFormData record.
Shared by EventsFormFieldChanged and EditFormFieldChanged to avoid duplicating
the string→record-field dispatch four times.
-}
applyFormField : String -> String -> EventFormData -> EventFormData
applyFormField field val form =
    case field of
        "title" ->
            { form | title = val }

        "description" ->
            { form | description = val }

        "location" ->
            { form | location = val }

        "url" ->
            { form | url = val }

        "imageDescription" ->
            { form | imageDescription = val }

        "lat" ->
            { form | lat = val }

        "lon" ->
            { form | lon = val }

        "state" ->
            case Types.eventStateFromString val of
                Just s ->
                    { form | state = s }

                Nothing ->
                    form

        _ ->
            form


{-| Apply a date/time-field update to an EventFormData record.
Shared by EventsFormDateChanged and EditFormDateChanged.
-}
applyFormDate : String -> String -> EventFormData -> EventFormData
applyFormDate field val form =
    case field of
        "startDate" ->
            { form | startDate = val }

        "startTime" ->
            { form | startTime = val }

        "endDate" ->
            { form | endDate = val }

        "endTime" ->
            { form | endTime = val }

        _ ->
            form



-- TOAST HELPERS


addToast : Model -> ToastKind -> String -> ( Model, Cmd Msg )
addToast model kind message =
    let
        id =
            model.nextToastId

        toast =
            { id = id, message = message, kind = kind }

        dismissCmd =
            Process.sleep 4000
                |> Task.andThen (\_ -> Task.succeed (DismissToast id))
                |> Task.perform identity
    in
    ( { model
        | toasts = model.toasts ++ [ toast ]
        , nextToastId = id + 1
      }
    , dismissCmd
    )



-- URL HELPERS


extractCode : Url -> Maybe String
extractCode url =
    let
        fragment =
            Maybe.withDefault "" url.fragment

        queryStr =
            case String.split "?" fragment of
                _ :: q :: _ ->
                    q

                _ ->
                    ""
    in
    queryStr
        |> String.split "&"
        |> List.filterMap
            (\pair ->
                case String.split "=" pair of
                    "code" :: rest ->
                        Just (String.join "=" rest)

                    _ ->
                        Nothing
            )
        |> List.head



-- DATA HELPERS


eventToForm : String -> Types.Event -> EventFormData
eventToForm pbBaseUrl event =
    let
        startDate =
            utcStringToHelsinkiDateInput event.startDate

        startTime =
            if event.allDay then
                ""

            else
                utcStringToHelsinkiTimeInput event.startDate

        ( endDate, endTime ) =
            case event.endDate of
                Just s ->
                    ( utcStringToHelsinkiDateInput s
                    , if event.allDay then
                        ""

                      else
                        utcStringToHelsinkiTimeInput s
                    )

                Nothing ->
                    ( "", "" )
    in
    { title = event.title
    , description = Maybe.withDefault "" event.description
    , location = Maybe.withDefault "" event.location
    , lat =
        Maybe.map (\p -> String.fromFloat p.lat) event.point
            |> Maybe.withDefault ""
    , lon =
        Maybe.map (\p -> String.fromFloat p.lon) event.point
            |> Maybe.withDefault ""
    , geocodingEnabled = True
    , url = Maybe.withDefault "" event.url
    , startDate = startDate
    , startTime = startTime
    , endDate = endDate
    , endTime = endTime
    , allDay = event.allDay
    , state = event.state
    , imageFile = Nothing
    , imageDescription = Maybe.withDefault "" event.imageDescription
    , hasExistingImage = event.image /= Nothing
    , existingImageUrl = Maybe.map (Api.imageUrl pbBaseUrl event.id) event.image
    , imagePreviewUrl = Nothing
    }


splitDateTime : String -> ( String, String )
splitDateTime s =
    -- PocketBase returns datetimes as "YYYY-MM-DD HH:MM:SS.sssZ" (space separator).
    -- Normalize to "T" before splitting so both formats are handled.
    case String.split "T" (String.replace " " "T" s) of
        date :: time :: _ ->
            ( date, String.left 5 time )

        date :: _ ->
            ( date, "" )

        [] ->
            ( "", "" )


placemarkToForm : KmlPlacemark -> EventFormData
placemarkToForm pm =
    { emptyEventFormData
        | title = pm.name
        , description = pm.description
        , startDate = Maybe.withDefault "" pm.dateStr
        , lat = Maybe.map String.fromFloat pm.lat |> Maybe.withDefault ""
        , lon = Maybe.map String.fromFloat pm.lon |> Maybe.withDefault ""
        , geocodingEnabled = pm.lat /= Nothing
        , state = Types.Draft
    }



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = pageTitle model.page
    , body =
        [ div [ class "min-h-screen flex flex-col" ]
            [ View.Layout.viewHeader model.authState model.menuOpen
            , div [ class "flex-1 max-w-5xl mx-auto w-full" ] [ viewPage model ]
            , View.Layout.viewFooter
            , View.Layout.viewBrandFooter
            , View.Layout.viewMobileOverlay model.menuOpen
            , View.Layout.viewMobileDrawer model.menuOpen (activeMenuRoute model.url) model.authState
            ]
        , View.Layout.viewToasts model.toasts
        ]
    }


activeMenuRoute : Url -> Maybe Route
activeMenuRoute url =
    case parseUrl url of
        RouteCalendar _ ->
            Just (RouteCalendar Nothing)

        RouteEvents ->
            Just RouteEvents

        _ ->
            Nothing


viewPage : Model -> Html Msg
viewPage model =
    case model.page of
        PageLoading ->
            div [ class "p-8 text-center text-text-muted" ] [ text "Ladataan..." ]

        PageAuthCallback ->
            div [ class "p-8 text-center text-text-muted" ] [ text "Kirjaudutaan..." ]

        PageNotFound ->
            div [ class "p-8 text-center" ]
                [ div [ class "type-h1 mb-2" ] [ text "404" ]
                , div [ class "text-text-muted mb-4" ] [ text "Sivua ei löydy" ]
                , a [ href (toHref (RouteCalendar Nothing)), class "text-brand underline" ]
                    [ text "Takaisin kalenteriin" ]
                ]

        PageCalendar calPage ->
            Page.Calendar.view model.authState calPage

        PageEventList evListPage ->
            View.EventList.view model.authState model.now evListPage

        PageEvents evPage ->
            Page.Events.view model.authState model.now evPage

        PageEventDetail id detPage ->
            View.EventDetail.view model.pbBaseUrl model.authState id detPage

        PageEventEdit _ editPage ->
            View.EventForm.viewEdit editPage


pageTitle : Page -> String
pageTitle page =
    case page of
        PageLoading ->
            "Ladataan... — Palikkakalenteri"

        PageAuthCallback ->
            "Kirjautuminen — Palikkakalenteri"

        PageNotFound ->
            "Sivua ei löydy — Palikkakalenteri"

        PageCalendar _ ->
            "Palikkakalenteri"

        PageEventList _ ->
            "Tulevat tapahtumat — Palikkakalenteri"

        PageEvents _ ->
            "Tulevat tapahtumat— Palikkakalenteri"

        PageEventDetail _ detPage ->
            case detPage.event of
                Success event ->
                    event.title ++ " — Palikkakalenteri"

                _ ->
                    "Tapahtuma — Palikkakalenteri"

        PageEventEdit _ _ ->
            "Muokkaa tapahtumaa — Palikkakalenteri"



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        keyboardSub =
            if model.menuOpen then
                Browser.Events.onKeyDown
                    (Json.field "key" Json.string
                        |> Json.andThen
                            (\key ->
                                if key == "Escape" then
                                    Json.succeed CloseMenu

                                else
                                    Json.fail "not escape"
                            )
                    )

            else
                case model.page of
                    PageEventDetail _ _ ->
                        Browser.Events.onKeyDown
                            (Json.map DetailKeyPressed (Json.field "key" Json.string))

                    _ ->
                        Sub.none
    in
    Sub.batch
        [ Ports.callbackParams
            (\params -> AuthCallbackReceived params.codeVerifier params.state)
        , Ports.oauthPopupResult OAuthPopupResult
        , Ports.mapMarkerMoved (\pos -> MapMarkerMoved pos.lat pos.lon)
        , Ports.kmlParsed EventsKmlParsed
        , keyboardSub
        ]
