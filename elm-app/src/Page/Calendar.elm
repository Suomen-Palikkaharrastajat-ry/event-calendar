module Page.Calendar exposing (init, update, view)

import Api
import Html exposing (Html)
import RemoteData
import Time
import Types exposing (AuthState, CalendarPage, CalendarViewMode(..), Msg(..))
import View.Calendar


init : Maybe String -> Time.Posix -> ( CalendarPage, Cmd Msg )
init maybeDate now =
    let
        -- Parse ?date=YYYY-MM-DD or default to current month
        ( year, month ) =
            case maybeDate of
                Just dateStr ->
                    parseYearMonth dateStr

                Nothing ->
                    -- Use current UTC date as a rough approximation
                    -- TODO: use Helsinki TZ
                    ( Time.toYear Time.utc now
                    , monthToInt (Time.toMonth Time.utc now)
                    )
    in
    ( { events = RemoteData.Loading
      , year = year
      , month = month
      , todayYear = Time.toYear Time.utc now
      , todayMonth = monthToInt (Time.toMonth Time.utc now)
      , todayDay = Time.toDay Time.utc now
      , viewMode = MonthGrid
      }
    , Api.fetchPublishedEvents CalendarGotEvents
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


monthToInt : Time.Month -> Int
monthToInt m =
    case m of
        Time.Jan -> 1
        Time.Feb -> 2
        Time.Mar -> 3
        Time.Apr -> 4
        Time.May -> 5
        Time.Jun -> 6
        Time.Jul -> 7
        Time.Aug -> 8
        Time.Sep -> 9
        Time.Oct -> 10
        Time.Nov -> 11
        Time.Dec -> 12
