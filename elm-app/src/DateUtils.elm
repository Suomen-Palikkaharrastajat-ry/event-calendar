module DateUtils exposing (formatEventDateDisplay)

{-| Event-specific date display formatting.
-}

import FinnishTime
    exposing
        ( formatShortDate
        , formatTime
        , parseUtcString
        , toHelsinkiParts
        )
import I18n exposing (MsgKey(..), t)
import Lang exposing (Lang)
import Types exposing (Event)


{-| Format an event's date/time for display. Implements the 6 format variants.
-}
formatEventDateDisplay : Lang -> Event -> String
formatEventDateDisplay lang event =
    let
        locale =
            I18n.locale lang

        at =
            t lang DateAtTime
    in
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
                        locale.weekdayAbbr start.weekday ++ " " ++ formatShortDate locale startPosix

                    else
                        locale.weekdayAbbr start.weekday
                            ++ " "
                            ++ formatShortDate locale startPosix
                            ++ at
                            ++ formatTime locale startPosix

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
                            locale.weekdayAbbr start.weekday ++ " " ++ formatShortDate locale startPosix

                        else if sameMonth then
                            locale.weekdayAbbr start.weekday
                                ++ "–"
                                ++ locale.weekdayAbbr end.weekday
                                ++ " "
                                ++ String.fromInt start.day
                                ++ locale.shortDateSuffix
                                ++ "–"
                                ++ formatShortDate locale endPosix

                        else
                            formatShortDate locale startPosix ++ "–" ++ formatShortDate locale endPosix

                    else if sameDay then
                        locale.weekdayAbbr start.weekday
                            ++ " "
                            ++ formatShortDate locale startPosix
                            ++ at
                            ++ formatTime locale startPosix
                            ++ "–"
                            ++ formatTime locale endPosix

                    else
                        formatShortDate locale startPosix
                            ++ " "
                            ++ formatTime locale startPosix
                            ++ "–"
                            ++ formatShortDate locale endPosix
                            ++ " "
                            ++ formatTime locale endPosix
