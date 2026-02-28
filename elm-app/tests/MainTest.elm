module MainTest exposing (suite)

import Expect
import Main exposing (applyFormDate, applyFormField)
import Test exposing (Test, describe, test)
import Types exposing (EventState(..), emptyEventFormData)


suite : Test
suite =
    describe "Main"
        [ describe "applyFormField"
            [ test "title field updates title" <|
                \_ ->
                    applyFormField "title" "Kesäjuhla" emptyEventFormData
                        |> .title
                        |> Expect.equal "Kesäjuhla"
            , test "description field updates description" <|
                \_ ->
                    applyFormField "description" "Kuvaus" emptyEventFormData
                        |> .description
                        |> Expect.equal "Kuvaus"
            , test "location field updates location" <|
                \_ ->
                    applyFormField "location" "Helsinki" emptyEventFormData
                        |> .location
                        |> Expect.equal "Helsinki"
            , test "url field updates url" <|
                \_ ->
                    applyFormField "url" "https://example.fi" emptyEventFormData
                        |> .url
                        |> Expect.equal "https://example.fi"
            , test "imageDescription field updates imageDescription" <|
                \_ ->
                    applyFormField "imageDescription" "Alt-teksti" emptyEventFormData
                        |> .imageDescription
                        |> Expect.equal "Alt-teksti"
            , test "lat field updates lat" <|
                \_ ->
                    applyFormField "lat" "60.1699" emptyEventFormData
                        |> .lat
                        |> Expect.equal "60.1699"
            , test "lon field updates lon" <|
                \_ ->
                    applyFormField "lon" "24.9384" emptyEventFormData
                        |> .lon
                        |> Expect.equal "24.9384"
            , test "state field with 'published' sets state to Published" <|
                \_ ->
                    applyFormField "state" "published" emptyEventFormData
                        |> .state
                        |> Expect.equal Published
            , test "state field with 'pending' sets state to Pending" <|
                \_ ->
                    applyFormField "state" "pending" emptyEventFormData
                        |> .state
                        |> Expect.equal Pending
            , test "state field with 'draft' sets state to Draft" <|
                \_ ->
                    applyFormField "state" "draft" emptyEventFormData
                        |> .state
                        |> Expect.equal Draft
            , test "state field with unrecognised value leaves state unchanged" <|
                \_ ->
                    applyFormField "state" "bogus" emptyEventFormData
                        |> .state
                        |> Expect.equal Draft
            , test "unknown field leaves form unchanged" <|
                \_ ->
                    applyFormField "nonexistent" "value" emptyEventFormData
                        |> Expect.equal emptyEventFormData
            , test "updating one field leaves other fields unchanged" <|
                \_ ->
                    let
                        form =
                            applyFormField "title" "Uusi nimi" emptyEventFormData
                    in
                    ( form.description, form.location, form.url )
                        |> Expect.equal ( "", "", "" )
            ]
        , describe "applyFormDate"
            [ test "startDate field updates startDate" <|
                \_ ->
                    applyFormDate "startDate" "2026-06-01" emptyEventFormData
                        |> .startDate
                        |> Expect.equal "2026-06-01"
            , test "startTime field updates startTime" <|
                \_ ->
                    applyFormDate "startTime" "14:00" emptyEventFormData
                        |> .startTime
                        |> Expect.equal "14:00"
            , test "endDate field updates endDate" <|
                \_ ->
                    applyFormDate "endDate" "2026-06-02" emptyEventFormData
                        |> .endDate
                        |> Expect.equal "2026-06-02"
            , test "endTime field updates endTime" <|
                \_ ->
                    applyFormDate "endTime" "16:30" emptyEventFormData
                        |> .endTime
                        |> Expect.equal "16:30"
            , test "unknown field leaves form unchanged" <|
                \_ ->
                    applyFormDate "nonexistent" "2026-06-01" emptyEventFormData
                        |> Expect.equal emptyEventFormData
            , test "updating startDate leaves other date fields unchanged" <|
                \_ ->
                    let
                        form =
                            applyFormDate "startDate" "2026-06-01" emptyEventFormData
                    in
                    ( form.startTime, form.endDate, form.endTime )
                        |> Expect.equal ( "", "", "" )
            ]
        ]
