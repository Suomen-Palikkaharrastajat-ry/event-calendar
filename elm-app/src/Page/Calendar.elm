{- Calendar page — owns the CalendarPage state type and init.

   Page/View split: this module handles state and init; all rendering lives in
   View.Calendar.  Reading Page.Calendar without knowing about View.Calendar gives
   an incomplete picture of the calendar feature.
-}


module Page.Calendar exposing (init, update, view)

import Api
import DateUtils
import Html exposing (Html)
import RemoteData
import Time
import Types exposing (AuthState, CalendarPage, CalendarViewMode(..), Msg(..))
import View.Calendar


init : String -> Maybe String -> Time.Posix -> ( CalendarPage, Cmd Msg )
init pbBaseUrl maybeDate now =
    let
        -- Use Helsinki timezone so the calendar opens on the correct month
        -- near midnight instead of the UTC date, which can differ by ±1 day.
        helsinkiOffsetMin =
            DateUtils.helsinkiOffset now

        helsinkiZone =
            Time.customZone helsinkiOffsetMin []

        ( year, month ) =
            case maybeDate of
                Just dateStr ->
                    parseYearMonth dateStr

                Nothing ->
                    ( Time.toYear helsinkiZone now
                    , DateUtils.monthToInt (Time.toMonth helsinkiZone now)
                    )
    in
    ( { events = RemoteData.Loading
      , year = year
      , month = month
      , todayYear = Time.toYear helsinkiZone now
      , todayMonth = DateUtils.monthToInt (Time.toMonth helsinkiZone now)
      , todayDay = Time.toDay helsinkiZone now
      , viewMode = MonthGrid
      }
    , Api.fetchPublishedEvents pbBaseUrl CalendarGotEvents
    )


update : Msg -> CalendarPage -> ( CalendarPage, Cmd Msg )
update msg page =
    case msg of
        CalendarGotEvents (Ok events) ->
            ( { page | events = RemoteData.Success events }, Cmd.none )

        CalendarGotEvents (Err err) ->
            ( { page | events = RemoteData.Failure err }, Cmd.none )

        CalendarSetMonth year month ->
            ( { page | year = year, month = month }, Cmd.none )

        CalendarSetView mode ->
            ( { page | viewMode = mode }, Cmd.none )

        _ ->
            ( page, Cmd.none )


view : AuthState -> CalendarPage -> Html Msg
view =
    View.Calendar.view



-- HELPERS


parseYearMonth : String -> ( Int, Int )
parseYearMonth dateStr =
    case String.split "-" dateStr of
        y :: m :: _ ->
            ( Maybe.withDefault 2025 (String.toInt y)
            , Maybe.withDefault 1 (String.toInt m)
            )

        _ ->
            ( 2025, 1 )
