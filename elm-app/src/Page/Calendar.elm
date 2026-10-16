module Page.Calendar exposing (dateQueryToYearMonth, init, update, view, yearMonthToDateQuery)

{-| Calendar page — owns the CalendarPage state type and init.

Page/View split: this module handles state and init; all rendering lives in
View.Calendar. Reading Page.Calendar without knowing about View.Calendar gives
an incomplete picture of the calendar feature.

-}

import Api
import Browser.Dom
import CalendarAgenda
import FinnishTime
import Html exposing (Html)
import Lang exposing (Lang)
import PocketBaseAuth exposing (AuthState)
import RemoteData
import Task
import Time
import Types exposing (CalendarPage, CalendarViewMode(..), Msg(..))
import View.Calendar


init : String -> Maybe String -> Time.Posix -> ( CalendarPage, Cmd Msg )
init pbBaseUrl maybeDate now =
    let
        -- Use Helsinki timezone so the calendar opens on the correct month
        -- near midnight instead of the UTC date, which can differ by ±1 day.
        helsinkiOffsetMin =
            FinnishTime.helsinkiOffset now

        helsinkiZone =
            Time.customZone helsinkiOffsetMin []

        ( year, month ) =
            dateQueryToYearMonth now maybeDate
    in
    ( { events = RemoteData.Loading
      , year = year
      , month = month
      , todayYear = Time.toYear helsinkiZone now
      , todayMonth = FinnishTime.monthToInt (Time.toMonth helsinkiZone now)
      , todayDay = Time.toDay helsinkiZone now
      , viewMode = MonthGrid
      , touchStart = Nothing
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
            ( { page | year = year, month = month, touchStart = Nothing }, Cmd.none )

        CalendarSetView mode ->
            ( { page | viewMode = mode }, Cmd.none )

        CalendarJumpToWeek week ->
            -- Focusing the week heading scrolls it into view and tells screen
            -- reader users where they landed. A missing heading is not an error.
            ( page
            , Browser.Dom.focus (CalendarAgenda.weekHeadingId week)
                |> Task.attempt (\_ -> CalendarNoOp)
            )

        CalendarTouchStart x y ->
            ( { page | touchStart = Just ( x, y ) }, Cmd.none )

        CalendarTouchCancel ->
            ( { page | touchStart = Nothing }, Cmd.none )

        CalendarTouchEnd endX endY ->
            case page.touchStart of
                Nothing ->
                    ( page, Cmd.none )

                Just ( startX, startY ) ->
                    let
                        dx =
                            endX - startX

                        dy =
                            endY - startY

                        isSwipe =
                            abs dx >= 40 && abs dx > abs dy * 1.5
                    in
                    if isSwipe then
                        if dx < 0 then
                            let
                                ( nextY, nextM ) =
                                    FinnishTime.nextMonth page.year page.month
                            in
                            ( { page | year = nextY, month = nextM, touchStart = Nothing }, Cmd.none )

                        else
                            let
                                ( prevY, prevM ) =
                                    FinnishTime.prevMonth page.year page.month
                            in
                            ( { page | year = prevY, month = prevM, touchStart = Nothing }, Cmd.none )

                    else
                        ( { page | touchStart = Nothing }, Cmd.none )

        _ ->
            ( page, Cmd.none )


view : Lang -> String -> AuthState -> CalendarPage -> Html Msg
view lang =
    View.Calendar.view lang



-- HELPERS


dateQueryToYearMonth : Time.Posix -> Maybe String -> ( Int, Int )
dateQueryToYearMonth now maybeDate =
    let
        helsinkiOffsetMin =
            FinnishTime.helsinkiOffset now

        helsinkiZone =
            Time.customZone helsinkiOffsetMin []

        currentMonth =
            ( Time.toYear helsinkiZone now
            , FinnishTime.monthToInt (Time.toMonth helsinkiZone now)
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
                            <= FinnishTime.daysInMonth year month
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


yearMonthToDateQuery : Int -> Int -> String
yearMonthToDateQuery year month =
    String.fromInt year
        ++ "-"
        ++ String.padLeft 2 '0' (String.fromInt month)
        ++ "-01"
