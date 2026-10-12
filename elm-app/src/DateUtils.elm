module DateUtils exposing (formatEventDateDisplay)

{-| Event-specific date display formatting.
-}

import FinnishTime
    exposing
        ( finnishWeekdayAbbr
        , formatShortDate
        , formatTime
        , parseUtcString
        , toHelsinkiParts
        )
import Types exposing (Event)


{-| Format an event's date/time for display. Implements the 6 format variants.
-}
formatEventDateDisplay : Event -> String
formatEventDateDisplay event =
    case parseUtcString event.startDate of
        Nothing ->
            event.startDate

        Just startPosix ->
            let
                start =
                    toHelsinkiParts startPosix

                allDay =
                    event.allDay
            in
            case event.endDate |> Maybe.andThen parseUtcString of
                Nothing ->
                    if allDay then
                        finnishWeekdayAbbr start.weekday ++ " " ++ formatShortDate startPosix

                    else
                        finnishWeekdayAbbr start.weekday
                            ++ " "
                            ++ formatShortDate startPosix
                            ++ " klo "
                            ++ formatTime startPosix

                Just endPosix ->
                    let
                        end =
                            toHelsinkiParts endPosix

                        sameDay =
                            start.year == end.year && start.month == end.month && start.day == end.day

                        sameMonth =
                            start.year == end.year && start.month == end.month
                    in
                    if allDay then
                        if sameDay then
                            finnishWeekdayAbbr start.weekday ++ " " ++ formatShortDate startPosix

                        else if sameMonth then
                            finnishWeekdayAbbr start.weekday
                                ++ "–"
                                ++ finnishWeekdayAbbr end.weekday
                                ++ " "
                                ++ String.fromInt start.day
                                ++ ".–"
                                ++ formatShortDate endPosix

                        else
                            formatShortDate startPosix ++ "–" ++ formatShortDate endPosix

                    else if sameDay then
                        finnishWeekdayAbbr start.weekday
                            ++ " "
                            ++ formatShortDate startPosix
                            ++ " klo "
                            ++ formatTime startPosix
                            ++ "–"
                            ++ formatTime endPosix

                    else
                        formatShortDate startPosix
                            ++ " "
                            ++ formatTime startPosix
                            ++ "–"
                            ++ formatShortDate endPosix
                            ++ " "
                            ++ formatTime endPosix
