{- Calendar page — owns the CalendarPage state type and init.

   Page/View split: this module handles state and init; all rendering lives in
   View.Calendar.  Reading Page.Calendar without knowing about View.Calendar gives
   an incomplete picture of the calendar feature.
-}


module Page.Calendar exposing (dateQueryToYearMonth, init, update, view)

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
            dateQueryToYearMonth now maybeDate
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


dateQueryToYearMonth : Time.Posix -> Maybe String -> ( Int, Int )
dateQueryToYearMonth now maybeDate =
    let
        helsinkiOffsetMin =
            DateUtils.helsinkiOffset now

        helsinkiZone =
            Time.customZone helsinkiOffsetMin []

        currentMonth =
            ( Time.toYear helsinkiZone now
            , DateUtils.monthToInt (Time.toMonth helsinkiZone now)
            )
    in
    maybeDate
        |> Maybe.andThen parseYearMonth
        |> Maybe.withDefault currentMonth


parseYearMonth : String -> Maybe ( Int, Int )
parseYearMonth dateStr =
    case String.split "-" dateStr of
        y :: m :: d :: [] ->
            Maybe.map3
                (\year month day ->
                    if
                        String.length y
                            == 4
                            && String.length m
                            == 2
                            && String.length d
                            == 2
                            && month
                            >= 1
                            && month
                            <= 12
                            && day
                            >= 1
                            && day
                            <= DateUtils.daysInMonth year month
                    then
                        Just ( year, month )

                    else
                        Nothing
                )
                (String.toInt y)
                (String.toInt m)
                (String.toInt d)
                |> Maybe.andThen identity

        _ ->
            Nothing
