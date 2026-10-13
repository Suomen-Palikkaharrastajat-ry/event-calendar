module CalendarAgenda exposing (AgendaWeek, DayMark, agendaWeeks, dayMark, weekHeadingId, weekLabel, weekNumberOf)

{-| Pure layout logic for the mobile calendar: the compact month strip marks
each day with a bar instead of event titles, and the agenda below lists the
month's events grouped by ISO week.
-}

import Date exposing (Date)
import FinnishTime exposing (utcStringToHelsinkiDateInput)
import I18n exposing (MsgKey(..), t)
import Lang exposing (Lang)
import Types exposing (Event)


{-| How one day is marked in the compact month strip.

`joinsPrev` / `joinsNext` are true when an event on this day also covers the
adjacent day, so the bar is drawn as one continuous run across the cells.

-}
type alias DayMark =
    { count : Int
    , joinsPrev : Bool
    , joinsNext : Bool
    }


{-| One ISO week (Monday–Sunday) that has events in the viewed month.
-}
type alias AgendaWeek =
    { weekNumber : Int
    , monday : ( Int, Int, Int )
    , sunday : ( Int, Int, Int )
    , events : List Event
    }


{-| Mark for one day of the month strip.
-}
dayMark : Int -> Int -> Int -> List Event -> DayMark
dayMark year month day events =
    let
        date =
            toDate year month day

        covering =
            List.filter (\span -> Date.isBetween span.start span.end date)
                (List.filterMap toSpan events)
    in
    { count = List.length covering
    , joinsPrev = List.any (\span -> Date.compare span.start date == LT) covering
    , joinsNext = List.any (\span -> Date.compare span.end date == GT) covering
    }


{-| The month's events grouped by ISO week, skipping weeks without events.

Each event is listed once: in the week it starts, or in the month's first week
when it continues from the previous month.

-}
agendaWeeks : Int -> Int -> List Event -> List AgendaWeek
agendaWeeks year month events =
    let
        first =
            toDate year month 1

        last =
            Date.add Date.Days -1 (Date.add Date.Months 1 first)

        inMonth =
            List.filterMap toSpan events
                |> List.filter
                    (\span ->
                        (Date.compare span.start last /= GT)
                            && (Date.compare span.end first /= LT)
                    )
                |> List.sortBy (\span -> ( Date.toRataDie span.start, span.event.startDate ))

        mondayOf span =
            Date.floor Date.Monday (Date.max span.start first)

        mondays =
            List.map (mondayOf >> Date.toRataDie) inMonth
                |> List.foldr
                    (\rd acc ->
                        if List.member rd acc then
                            acc

                        else
                            rd :: acc
                    )
                    []
                |> List.sort
    in
    List.map
        (\rd ->
            let
                monday =
                    Date.fromRataDie rd
            in
            { weekNumber = Date.weekNumber monday
            , monday = toTriple monday
            , sunday = toTriple (Date.add Date.Days 6 monday)
            , events =
                List.filter (\span -> Date.toRataDie (mondayOf span) == rd) inMonth
                    |> List.map .event
            }
        )
        mondays


{-| Heading text for a week, e.g. "Viikko 42 · 12.–18.10." or
"Week 42 · 12–18/10".
-}
weekLabel : Lang -> AgendaWeek -> String
weekLabel lang week =
    let
        locale =
            I18n.locale lang

        ( _, fromMonth, fromDay ) =
            week.monday

        ( _, toMonth, toDay ) =
            week.sunday

        dayAndMonth day month =
            String.fromInt day ++ locale.dateSeparator ++ String.fromInt month ++ locale.shortDateSuffix

        from =
            if fromMonth == toMonth then
                String.fromInt fromDay ++ locale.shortDateSuffix

            else
                dayAndMonth fromDay fromMonth
    in
    t lang CalWeek
        ++ String.fromInt week.weekNumber
        ++ " · "
        ++ from
        ++ "–"
        ++ dayAndMonth toDay toMonth


{-| ISO week number of a calendar date.
-}
weekNumberOf : Int -> Int -> Int -> Int
weekNumberOf year month day =
    Date.weekNumber (toDate year month day)


{-| DOM id of a week's heading in the agenda; the month strip jumps to it.
-}
weekHeadingId : Int -> String
weekHeadingId week =
    "agenda-week-" ++ String.fromInt week



-- INTERNAL


type alias Span =
    { start : Date
    , end : Date
    , event : Event
    }


{-| The Helsinki-local days an event covers. Events are placed by Helsinki
date, not UTC date, like the month grid does.
-}
toSpan : Event -> Maybe Span
toSpan event =
    helsinkiDate event.startDate
        |> Maybe.map
            (\start ->
                { start = start
                , end =
                    event.endDate
                        |> Maybe.andThen helsinkiDate
                        |> Maybe.map (Date.max start)
                        |> Maybe.withDefault start
                , event = event
                }
            )


helsinkiDate : String -> Maybe Date
helsinkiDate utc =
    Date.fromIsoString (utcStringToHelsinkiDateInput utc) |> Result.toMaybe


toDate : Int -> Int -> Int -> Date
toDate year month day =
    Date.fromCalendarDate year (Date.numberToMonth month) day


toTriple : Date -> ( Int, Int, Int )
toTriple date =
    ( Date.year date, Date.monthNumber date, Date.day date )
