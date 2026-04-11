module View.FinnishDatePicker exposing
    ( update
    , view
    )

import Date
import DatePicker exposing (DateEvent(..), InputError(..), defaultSettings)
import DateUtils
import Html exposing (Html)
import Time exposing (Weekday(..))


settings : Maybe String -> DatePicker.Settings
settings maybeInputId =
    { defaultSettings
        | placeholder = "pp.kk.vvvv"
        , inputId = maybeInputId
        , inputClassList =
            [ ( "border", True )
            , ( "rounded", True )
            , ( "px-2", True )
            , ( "py-1", True )
            , ( "type-body-small", True )
            , ( "focus-visible:ring-2", True )
            , ( "focus-visible:ring-brand", True )
            ]
        , parser = parseFinnishDate
        , dateFormatter = formatFinnishDate
        , dayFormatter = DateUtils.finnishWeekdayAbbr
        , monthFormatter =
            \month ->
                DateUtils.finnishMonthName (DateUtils.monthToInt month)
        , firstDayOfWeek = Mon
    }


view :
    { picker : DatePicker.DatePicker
    , selectedIsoDate : String
    , inputId : String
    }
    -> Html DatePicker.Msg
view config =
    DatePicker.view
        (isoDateToDate config.selectedIsoDate)
        (settings (Just config.inputId))
        config.picker


update : DatePicker.Msg -> DatePicker.DatePicker -> ( DatePicker.DatePicker, Maybe String )
update datePickerMsg picker =
    let
        ( updatedPicker, dateEvent ) =
            DatePicker.update (settings Nothing) datePickerMsg picker
    in
    ( updatedPicker, dateEventToIso dateEvent )


dateEventToIso : DatePicker.DateEvent -> Maybe String
dateEventToIso dateEvent =
    case dateEvent of
        Picked date ->
            Just (Date.toIsoString date)

        FailedInput EmptyString ->
            Just ""

        _ ->
            Nothing


isoDateToDate : String -> Maybe Date.Date
isoDateToDate isoDate =
    case Date.fromIsoString isoDate of
        Ok date ->
            Just date

        Err _ ->
            Nothing


parseFinnishDate : String -> Result String Date.Date
parseFinnishDate finnishDate =
    case DateUtils.finnishDateInputToIsoDate finnishDate of
        Just isoDate ->
            Date.fromIsoString isoDate

        Nothing ->
            Err "Virheellinen päivämäärä"


formatFinnishDate : Date.Date -> String
formatFinnishDate date =
    DateUtils.isoDateToFinnishDateInput (Date.toIsoString date)
