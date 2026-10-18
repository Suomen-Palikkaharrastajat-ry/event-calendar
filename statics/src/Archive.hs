{- | Split published events into upcoming events (the feeds) and yearly archives of past
events (@kalenteri-YYYY.json@), which the SPA reads when nobody is signed in.
-}
module Archive (
    isUpcoming,
    pastEventsByYear,
) where

import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Time (Day, LocalTime (..), UTCTime, ZonedTime (..), toGregorian)
import qualified DateUtils as DU
import qualified PocketBase as PB

{- | True if an event's effective end (end_date if set, else start_date) is today or later.
All-day events compare by Helsinki calendar date (their dates are stored as Helsinki midnight
converted to UTC, so UTC midnight comparison would incorrectly exclude events ending "today").
Timed events compare against UTC midnight, so one that ended between 00:00 and 02:59 Helsinki
time today already counts as past; it is then in the current year's archive, which the SPA
always reads alongside the upcoming feed.
-}
isUpcoming :: Day -> UTCTime -> PB.Event -> Bool
isUpcoming todayHki todayUtc ev =
    let effective = effectiveEnd ev
     in if PB.eventAllDay ev
            then helsinkiDay effective >= todayHki
            else effective >= todayUtc

{- | Group past events by every Helsinki calendar year they touch, keeping input order.
An event from December to January is in both years, so either year's file shows it.
-}
pastEventsByYear :: [PB.Event] -> Map.Map Integer [PB.Event]
pastEventsByYear events =
    Map.fromListWith (flip (++)) [(year, [ev]) | ev <- events, year <- eventYears ev]

eventYears :: PB.Event -> [Integer]
eventYears ev = [yearOf (PB.eventStartDate ev) .. yearOf (effectiveEnd ev)]
  where
    yearOf t = let (y, _, _) = toGregorian (helsinkiDay t) in y

effectiveEnd :: PB.Event -> UTCTime
effectiveEnd ev = fromMaybe (PB.eventStartDate ev) (PB.eventEndDate ev)

helsinkiDay :: UTCTime -> Day
helsinkiDay = localDay . zonedTimeToLocalTime . DU.toHelsinki
