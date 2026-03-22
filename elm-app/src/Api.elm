module Api exposing
    ( createEvent
    , decodeEvent
    , deleteEvent
    , fetchAllEvents
    , fetchEvent
    , fetchPublishedEvents
    , httpErrorToString
    , imageUrl
    , updateEvent
    , updateEventState
    )

import File exposing (File)
import Http
import Json.Decode as Json exposing (Decoder)
import Json.Encode as Encode
import Types exposing (AuthState(..), Event, EventFormData, EventState, GeoPoint, Msg(..), PbList, eventStateFromString, eventStateToString)
import Url


imageUrl : String -> String -> String -> String
imageUrl pbBaseUrl eventId filename =
    pbBaseUrl ++ "/api/files/events/" ++ eventId ++ "/" ++ filename


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
        (\id title description startDate endDate allDay url location ->
            { id = id
            , title = title
            , description = description
            , startDate = startDate
            , endDate = endDate
            , allDay = allDay
            , url = url
            , location = location
            , state = Types.Draft
            , image = Nothing
            , imageDescription = Nothing
            , point = Nothing
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
        (Json.field "url" nullableString)
        (Json.field "location" nullableString)
        |> Json.andThen
            (\partial ->
                Json.map5
                    (\state image imageDesc point created ->
                        { partial
                            | state = Maybe.withDefault Types.Draft (eventStateFromString state)
                            , image = image
                            , imageDescription = imageDesc
                            , point = point
                            , created = created
                        }
                    )
                    (Json.field "state" Json.string)
                    (Json.field "image" nullableString)
                    (Json.field "image_description" nullableString)
                    (Json.maybe (Json.field "point" decodeGeoPoint))
                    (Json.field "created" Json.string)
            )
        |> Json.andThen
            (\partial ->
                Json.map
                    (\updated -> { partial | updated = updated })
                    (Json.field "updated" Json.string)
            )


decodePbList : Decoder a -> Decoder (PbList a)
decodePbList itemDecoder =
    Json.map5 PbList
        (Json.field "items" (Json.list itemDecoder))
        (Json.field "totalItems" Json.int)
        (Json.succeed 1)
        (Json.field "page" Json.int)
        (Json.field "perPage" Json.int)



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



-- WRITE


createEvent : String -> String -> EventFormData -> (Result Http.Error Event -> Msg) -> Cmd Msg
createEvent pbBaseUrl token formData toMsg =
    Http.request
        { method = "POST"
        , headers = [ Http.header "Authorization" token ]
        , url = pbBaseUrl ++ "/api/collections/events/records"
        , body = eventFormToMultipart formData
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
        , body = eventFormToMultipart formData
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


deleteEvent : String -> String -> String -> (Result Http.Error () -> Msg) -> Cmd Msg
deleteEvent pbBaseUrl token eventId toMsg =
    Http.request
        { method = "DELETE"
        , headers = [ Http.header "Authorization" token ]
        , url = pbBaseUrl ++ "/api/collections/events/records/" ++ eventId
        , body = Http.emptyBody
        , expect = Http.expectWhatever toMsg
        , timeout = Nothing
        , tracker = Nothing
        }



-- MULTIPART FORM


eventFormToMultipart : EventFormData -> Http.Body
eventFormToMultipart formData =
    let
        textParts =
            [ Http.stringPart "title" formData.title
            , Http.stringPart "description" formData.description
            , Http.stringPart "location" formData.location
            , Http.stringPart "url" formData.url
            , Http.stringPart "start_date" formData.startDate
            , Http.stringPart "end_date" formData.endDate
            , Http.stringPart "all_day"
                (if formData.allDay then
                    "true"

                 else
                    "false"
                )
            , Http.stringPart "state" (eventStateToString formData.state)
            , Http.stringPart "image_description" formData.imageDescription
            , Http.stringPart "point" (encodePointForPb formData)
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


httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        Http.BadUrl url ->
            "Virheellinen URL: " ++ url

        Http.Timeout ->
            "Pyyntö aikakatkaistiin"

        Http.NetworkError ->
            "Verkkovirhe"

        Http.BadStatus code ->
            "Palvelinvirhe: " ++ String.fromInt code

        Http.BadBody body ->
            "Vastausvirhe: " ++ body
