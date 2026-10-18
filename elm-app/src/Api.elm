module Api exposing
    ( createEvent
    , decodeEvent
    , decodeStaticEvents
    , decodeStaticFeed
    , eventImageUrl
    , fetchAllEvents
    , fetchEvent
    , fetchEventsForList
    , fetchPublishedEvents
    , fetchStaticEvent
    , fetchStaticEvents
    , httpErrorToString
    , imageUrl
    , mergeEvents
    , staticFeedTask
    , staticImageUrl
    , staticYearTask
    , updateEvent
    , updateEventState
    )

{-| PocketBase REST API client: request builders, JSON decoders/encoders and image URL helpers.

Signed-out visitors never call PocketBase: they read the JSON Feeds the static generator
publishes next to the app (`kalenteri.json` and the yearly `kalenteri-YYYY.json` archives).
Each feed item carries the PocketBase record under `_palikkakalenteri`, so `decodeEvent`
decodes both sources.

-}

import File exposing (File)
import FinnishTime exposing (formDateTimeToUtc)
import Http
import I18n exposing (MsgKey(..), t)
import Json.Decode as Json exposing (Decoder)
import Json.Encode as Encode
import Lang exposing (Lang)
import PocketBaseAuth exposing (AuthState(..))
import Set
import Task exposing (Task)
import Types exposing (Event, EventFormData, EventState, GeoPoint, Msg(..), PbList, StaticFeed, eventStateFromString, eventStateToString)
import Url


imageUrl : String -> String -> String -> String
imageUrl pbBaseUrl eventId filename =
    pbBaseUrl ++ "/api/files/events/" ++ eventId ++ "/" ++ filename


{-| The copy of an event image that the static generator downloaded.
-}
staticImageUrl : String -> String -> String -> String
staticImageUrl staticBaseUrl eventId filename =
    staticBaseUrl ++ "/images/" ++ eventId ++ "_" ++ filename


{-| Where to load an event image from: PocketBase when signed in, else the static copy, which
matches where the event itself was read from.
-}
eventImageUrl : AuthState -> { pbBaseUrl : String, staticBaseUrl : String } -> String -> String -> String
eventImageUrl authState urls =
    case authState of
        Authenticated _ ->
            imageUrl urls.pbBaseUrl

        NotAuthenticated ->
            staticImageUrl urls.staticBaseUrl


authHeader : AuthState -> List Http.Header
authHeader authState =
    case authState of
        NotAuthenticated ->
            []

        Authenticated user ->
            [ Http.header "Authorization" user.token ]



-- DECODERS


nullableString : Decoder (Maybe String)
nullableString =
    Json.string
        |> Json.map
            (\s ->
                if String.isEmpty s then
                    Nothing

                else
                    Just s
            )


decodeGeoPoint : Decoder GeoPoint
decodeGeoPoint =
    Json.map2 GeoPoint
        (Json.field "lat" Json.float)
        (Json.field "lon" Json.float)


decodeEvent : Decoder Event
decodeEvent =
    Json.map8
        (\id title description startDate endDate allDay cancelled url ->
            { id = id
            , title = title
            , description = description
            , startDate = startDate
            , endDate = endDate
            , allDay = allDay
            , url = url
            , location = Nothing
            , state = Types.Draft
            , cancelled = cancelled
            , image = Nothing
            , imageDescription = Nothing
            , point = Nothing
            , tags = []
            , created = ""
            , updated = ""
            }
        )
        (Json.field "id" Json.string)
        (Json.field "title" Json.string)
        (Json.field "description" nullableString)
        (Json.field "start_date" Json.string)
        (Json.maybe (Json.field "end_date" Json.string))
        (Json.field "all_day" Json.bool)
        (Json.field "cancelled" Json.bool)
        (Json.field "url" nullableString)
        |> Json.andThen
            (\partial ->
                Json.map6
                    (\location state image imageDesc point created ->
                        { partial
                            | location = location
                            , state = Maybe.withDefault Types.Draft (eventStateFromString state)
                            , image = image
                            , imageDescription = imageDesc
                            , point = point
                            , created = created
                        }
                    )
                    (Json.field "location" nullableString)
                    (Json.field "state" Json.string)
                    (Json.field "image" nullableString)
                    (Json.field "image_description" nullableString)
                    (Json.maybe (Json.field "point" decodeGeoPoint))
                    (Json.field "created" Json.string)
            )
        |> Json.andThen
            (\partial ->
                Json.map2
                    (\updated tags -> { partial | updated = updated, tags = Maybe.withDefault [] tags })
                    (Json.field "updated" Json.string)
                    (Json.maybe (Json.field "tags" (Json.list Json.string)))
            )


decodePbList : Decoder a -> Decoder (PbList a)
decodePbList itemDecoder =
    Json.map5 PbList
        (Json.field "items" (Json.list itemDecoder))
        (Json.field "totalItems" Json.int)
        (Json.succeed 1)
        (Json.field "page" Json.int)
        (Json.field "perPage" Json.int)


{-| The events of a static JSON Feed.
-}
decodeStaticEvents : Decoder (List Event)
decodeStaticEvents =
    Json.field "items" (Json.list (Json.field "_palikkakalenteri" decodeEvent))


{-| `kalenteri.json`: its events and the years listed in `_palikkakalenteri.archive`.
-}
decodeStaticFeed : Decoder StaticFeed
decodeStaticFeed =
    Json.map2 StaticFeed
        decodeStaticEvents
        (Json.maybe (Json.field "_palikkakalenteri" Json.value)
            |> Json.andThen
                (\extension ->
                    case extension of
                        -- A feed from before the archives existed has no index.
                        Nothing ->
                            Json.succeed []

                        Just _ ->
                            Json.at [ "_palikkakalenteri", "archive" ] (Json.list Json.int)
                )
        )



-- FETCH


fetchPublishedEvents : String -> (Result Http.Error (List Event) -> Msg) -> Cmd Msg
fetchPublishedEvents pbBaseUrl toMsg =
    Http.get
        { url =
            pbBaseUrl
                ++ "/api/collections/events/records"
                ++ "?filter="
                ++ Url.percentEncode "(state=\"published\")"
                ++ "&sort=start_date&perPage=500"
        , expect = Http.expectJson toMsg (Json.field "items" (Json.list decodeEvent))
        }


fetchEventsForList : String -> Maybe String -> (Result Http.Error (List Event) -> Msg) -> Cmd Msg
fetchEventsForList pbBaseUrl maybeToken toMsg =
    let
        baseUrl =
            pbBaseUrl
                ++ "/api/collections/events/records"
                ++ "?sort=start_date&perPage=500"

        url =
            case maybeToken of
                Just _ ->
                    baseUrl

                Nothing ->
                    baseUrl
                        ++ "&filter="
                        ++ Url.percentEncode "(state=\"published\")"

        headers =
            case maybeToken of
                Just token ->
                    [ Http.header "Authorization" token ]

                Nothing ->
                    []
    in
    Http.request
        { method = "GET"
        , headers = headers
        , url = url
        , body = Http.emptyBody
        , expect = Http.expectJson toMsg (Json.field "items" (Json.list decodeEvent))
        , timeout = Nothing
        , tracker = Nothing
        }


fetchAllEvents : String -> String -> Int -> (Result Http.Error (PbList Event) -> Msg) -> Cmd Msg
fetchAllEvents pbBaseUrl token page toMsg =
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" token ]
        , url =
            pbBaseUrl
                ++ "/api/collections/events/records"
                ++ "?sort=-updated&perPage=100&page="
                ++ String.fromInt page
        , body = Http.emptyBody
        , expect = Http.expectJson toMsg (decodePbList decodeEvent)
        , timeout = Nothing
        , tracker = Nothing
        }


fetchEvent : String -> Maybe String -> String -> (Result Http.Error Event -> Msg) -> Cmd Msg
fetchEvent pbBaseUrl maybeToken id toMsg =
    Http.request
        { method = "GET"
        , headers =
            case maybeToken of
                Just token ->
                    [ Http.header "Authorization" token ]

                Nothing ->
                    []
        , url = pbBaseUrl ++ "/api/collections/events/records/" ++ id
        , body = Http.emptyBody
        , expect = Http.expectJson toMsg decodeEvent
        , timeout = Nothing
        , tracker = Nothing
        }



-- STATIC FILES


staticTask : String -> Decoder a -> Task Http.Error a
staticTask url decoder =
    Http.task
        { method = "GET"
        , headers = []
        , url = url
        , body = Http.emptyBody
        , resolver = Http.stringResolver (resolveJson decoder)
        , timeout = Nothing
        }


resolveJson : Decoder a -> Http.Response String -> Result Http.Error a
resolveJson decoder response =
    case response of
        Http.BadUrl_ url ->
            Err (Http.BadUrl url)

        Http.Timeout_ ->
            Err Http.Timeout

        Http.NetworkError_ ->
            Err Http.NetworkError

        Http.BadStatus_ metadata _ ->
            Err (Http.BadStatus metadata.statusCode)

        Http.GoodStatus_ _ body ->
            Json.decodeString decoder body
                |> Result.mapError (Json.errorToString >> Http.BadBody)


{-| `kalenteri.json`: upcoming events and the list of archive years.
-}
staticFeedTask : String -> Task Http.Error StaticFeed
staticFeedTask staticBaseUrl =
    staticTask (staticBaseUrl ++ "/kalenteri.json") decodeStaticFeed


{-| `kalenteri-YYYY.json`: the past events of one year.
-}
staticYearTask : String -> Int -> Task Http.Error (List Event)
staticYearTask staticBaseUrl year =
    staticTask (staticBaseUrl ++ "/kalenteri-" ++ String.fromInt year ++ ".json") decodeStaticEvents


{-| Every published event: the upcoming feed and all yearly archives. A year file that fails
to load (e.g. mid-deploy) is left out rather than failing the whole list.
-}
fetchStaticEvents : String -> (Result Http.Error (List Event) -> Msg) -> Cmd Msg
fetchStaticEvents staticBaseUrl toMsg =
    staticFeedTask staticBaseUrl
        |> Task.andThen
            (\feed ->
                feed.archiveYears
                    |> List.map (\year -> staticYearTask staticBaseUrl year |> Task.onError (\_ -> Task.succeed []))
                    |> Task.sequence
                    |> Task.map (List.concat >> mergeEvents feed.events)
            )
        |> Task.attempt toMsg


{-| One event: from the upcoming feed, else from the archives, newest year first, one file at
a time (old events are rarely opened, so most lookups stop at the first file or two).
An event in no file fails with `BadStatus 404`, like a missing PocketBase record.
-}
fetchStaticEvent : String -> String -> (Result Http.Error Event -> Msg) -> Cmd Msg
fetchStaticEvent staticBaseUrl id toMsg =
    let
        search years =
            case years of
                [] ->
                    Task.fail (Http.BadStatus 404)

                year :: rest ->
                    staticYearTask staticBaseUrl year
                        |> Task.andThen (findOr (search rest))

        findOr notFound events =
            case List.filter (\event -> event.id == id) events of
                event :: _ ->
                    Task.succeed event

                [] ->
                    notFound
    in
    staticFeedTask staticBaseUrl
        |> Task.andThen (\feed -> findOr (search feed.archiveYears) feed.events)
        |> Task.attempt toMsg


{-| Combine event lists, keeping one copy of each event (an event spanning New Year is in
two archives), sorted by start date. PocketBase dates sort correctly as strings.
-}
mergeEvents : List Event -> List Event -> List Event
mergeEvents first second =
    (first ++ second)
        |> List.foldl
            (\event ( seen, kept ) ->
                if Set.member event.id seen then
                    ( seen, kept )

                else
                    ( Set.insert event.id seen, event :: kept )
            )
            ( Set.empty, [] )
        |> Tuple.second
        |> List.sortBy .startDate



-- WRITE


createEvent : String -> String -> EventFormData -> (Result Http.Error Event -> Msg) -> Cmd Msg
createEvent pbBaseUrl token formData toMsg =
    Http.request
        { method = "POST"
        , headers = [ Http.header "Authorization" token ]
        , url = pbBaseUrl ++ "/api/collections/events/records"
        , body =
            case formData.imageFile of
                Just _ ->
                    eventFormToMultipart formData

                Nothing ->
                    Http.jsonBody (eventFormToJson formData)
        , expect = Http.expectJson toMsg decodeEvent
        , timeout = Nothing
        , tracker = Nothing
        }


updateEvent : String -> String -> String -> EventFormData -> (Result Http.Error Event -> Msg) -> Cmd Msg
updateEvent pbBaseUrl token eventId formData toMsg =
    Http.request
        { method = "PATCH"
        , headers = [ Http.header "Authorization" token ]
        , url = pbBaseUrl ++ "/api/collections/events/records/" ++ eventId
        , body =
            case formData.imageFile of
                Just _ ->
                    eventFormToMultipart formData

                Nothing ->
                    Http.jsonBody (eventFormToJson formData)
        , expect = Http.expectJson toMsg decodeEvent
        , timeout = Nothing
        , tracker = Nothing
        }


updateEventState : String -> String -> String -> EventState -> (Result Http.Error Event -> Msg) -> Cmd Msg
updateEventState pbBaseUrl token eventId newState toMsg =
    Http.request
        { method = "PATCH"
        , headers = [ Http.header "Authorization" token ]
        , url = pbBaseUrl ++ "/api/collections/events/records/" ++ eventId
        , body =
            Http.jsonBody
                (Encode.object [ ( "state", Encode.string (eventStateToString newState) ) ])
        , expect = Http.expectJson toMsg decodeEvent
        , timeout = Nothing
        , tracker = Nothing
        }



-- MULTIPART FORM


eventFormToJson : EventFormData -> Encode.Value
eventFormToJson formData =
    let
        startDatePart =
            Maybe.withDefault formData.startDate (formDateTimeToUtc formData.startDate formData.startTime formData.allDay)

        endDatePart =
            if String.isEmpty formData.endDate then
                ""

            else
                let
                    ( endT, isAllDayForEnd ) =
                        if formData.allDay then
                            ( "23:59", False )

                        else
                            ( formData.endTime, formData.allDay )
                in
                Maybe.withDefault formData.endDate (formDateTimeToUtc formData.endDate endT isAllDayForEnd)

        pointJson =
            if formData.geocodingEnabled then
                case ( String.toFloat formData.lat, String.toFloat formData.lon ) of
                    ( Just lat, Just lon ) ->
                        Encode.object [ ( "lat", Encode.float lat ), ( "lon", Encode.float lon ) ]

                    _ ->
                        Encode.null

            else
                Encode.null
    in
    Encode.object
        [ ( "title", Encode.string formData.title )
        , ( "description", Encode.string formData.description )
        , ( "location", Encode.string formData.location )
        , ( "url", Encode.string formData.url )
        , ( "start_date", Encode.string startDatePart )
        , ( "end_date", Encode.string endDatePart )
        , ( "all_day", Encode.bool formData.allDay )
        , ( "cancelled", Encode.bool formData.cancelled )
        , ( "state", Encode.string (eventStateToString formData.state) )
        , ( "image_description", Encode.string formData.imageDescription )
        , ( "point", pointJson )
        , ( "tags"
          , if String.isEmpty formData.tag then
                Encode.list Encode.string []

            else
                Encode.list Encode.string [ formData.tag ]
          )
        ]


eventFormToMultipart : EventFormData -> Http.Body
eventFormToMultipart formData =
    let
        startDatePart =
            case formDateTimeToUtc formData.startDate formData.startTime formData.allDay of
                Just s ->
                    s

                Nothing ->
                    formData.startDate

        endDatePart =
            if String.isEmpty formData.endDate then
                ""

            else
                let
                    ( endT, isAllDayForEnd ) =
                        if formData.allDay then
                            ( "23:59", False )

                        else
                            ( formData.endTime, formData.allDay )
                in
                case formDateTimeToUtc formData.endDate endT isAllDayForEnd of
                    Just s ->
                        s

                    Nothing ->
                        formData.endDate

        textParts =
            [ Http.stringPart "title" formData.title
            , Http.stringPart "description" formData.description
            , Http.stringPart "location" formData.location
            , Http.stringPart "url" formData.url
            , Http.stringPart "start_date" startDatePart
            , Http.stringPart "end_date" endDatePart
            , Http.stringPart "all_day"
                (if formData.allDay then
                    "true"

                 else
                    "false"
                )
            , Http.stringPart "cancelled"
                (if formData.cancelled then
                    "true"

                 else
                    "false"
                )
            , Http.stringPart "state" (eventStateToString formData.state)
            , Http.stringPart "image_description" formData.imageDescription
            , Http.stringPart "point" (encodePointForPb formData)
            , Http.stringPart "tags"
                (if String.isEmpty formData.tag then
                    "[]"

                 else
                    "[\"" ++ formData.tag ++ "\"]"
                )
            ]

        fileParts =
            case formData.imageFile of
                Nothing ->
                    []

                Just file ->
                    [ Http.filePart "image" file ]
    in
    Http.multipartBody (textParts ++ fileParts)


encodePointForPb : EventFormData -> String
encodePointForPb formData =
    if formData.geocodingEnabled then
        case ( String.toFloat formData.lat, String.toFloat formData.lon ) of
            ( Just lat, Just lon ) ->
                "{\"lat\":" ++ String.fromFloat lat ++ ",\"lon\":" ++ String.fromFloat lon ++ "}"

            _ ->
                ""

    else
        ""



-- ERROR


httpErrorToString : Lang -> Http.Error -> String
httpErrorToString lang err =
    case err of
        Http.BadUrl url ->
            t lang ErrBadUrl ++ url

        Http.Timeout ->
            t lang ErrTimeout

        Http.NetworkError ->
            t lang ErrNetwork

        Http.BadStatus code ->
            t lang ErrBadStatus ++ String.fromInt code

        Http.BadBody body ->
            t lang ErrBadBody ++ body
