{- | HTML generation for the embeddable calendar and per-event landing pages.
Generates static/kalenteri.html and static/events/{id}.html.
QR codes (PNG, base64-embedded) link to per-event landing pages for print use.
-}
module HtmlGen (
    generateCalendarHtml,
    generateEventHtml,
) where

import qualified Codec.QRCode as QR
import qualified Codec.QRCode.JuicyPixels as QRJP
import qualified Config
import qualified Data.ByteString.Base64 as B64
import qualified Data.ByteString.Char8 as BSC
import Data.List (groupBy, sortBy)
import Data.Maybe (fromMaybe)
import Data.Ord (comparing)
import qualified Data.Text as T
import Data.Time (LocalTime (..), ZonedTime (..), getCurrentTime, toGregorian)
import Data.Time.Format (defaultTimeLocale, formatTime)
import qualified DateUtils as DU
import qualified ICalGen
import qualified PocketBase as PB
import Text.Blaze.Html.Renderer.String (renderHtml)
import Text.Blaze.Html5 ((!))
import qualified Text.Blaze.Html5 as H
import qualified Text.Blaze.Html5.Attributes as A

-- ---------------------------------------------------------------------------
-- QR code and ICS helpers
-- ---------------------------------------------------------------------------

{- | Generate a QR code PNG as a base64 data URI, or Nothing if encoding fails.
Uses toPngDataUrlS which returns the complete data: URL string.
-}
qrCodeDataUri :: String -> Maybe String
qrCodeDataUri url = do
    code <-
        QR.encode
            (QR.defaultQRCodeOptions QR.M)
            QR.Iso8859_1OrUtf8WithoutECI
            (T.pack url)
    return $ QRJP.toPngDataUrlS 4 8 code

-- | Encode an ICS string as a base64 data URI for inline download links.
icsDataUri :: String -> String
icsDataUri icsText =
    "data:text/calendar;charset=utf-8;base64,"
        ++ BSC.unpack (B64.encode (BSC.pack icsText))

-- ---------------------------------------------------------------------------
-- CSS
-- ---------------------------------------------------------------------------

-- | '<picture>' element for the site logo (SVG → WebP → PNG fallback, self-hosted).
siteLogo :: H.Html
siteLogo =
    H.div ! A.class_ "site-logo" $
        H.preEscapedToMarkup
            ( "<picture>"
                ++ "<source type=\"image/svg+xml\" srcset=\"logo/horizontal-full.svg\">"
                ++ "<source type=\"image/webp\" srcset=\"logo/horizontal-full.webp\">"
                ++ "<img src=\"logo/horizontal-full.png\""
                ++ " alt=\"Suomen Palikkaharrastajat\" style=\"max-width:200px;height:auto;\">"
                ++ "</picture>"
                :: String
            )

{- | URL-encoded SVG data URI for the calendar icon overlay on QR codes.
Encoding: only <, >, " are percent-encoded; works in CSS url("...").
-}
calendarIconDataUri :: String
calendarIconDataUri =
    "data:image/svg+xml,"
        ++ "%3Csvg xmlns=%22http://www.w3.org/2000/svg%22"
        ++ " width=%2224%22 height=%2224%22 viewBox=%220 0 24 24%22"
        ++ " fill=%22none%22 stroke=%22black%22 stroke-width=%222%22"
        ++ " stroke-linecap=%22round%22 stroke-linejoin=%22round%22%3E"
        ++ "%3Cpath d=%22M8 7V3m8 4V3m-9 8h10M5 21h14"
        ++ "a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
        ++ "%22/%3E%3C/svg%3E"

calendarCss :: String
calendarCss =
    unlines
        [ ":root { --color-brand-primary: #000000; --color-brand-accent: #000000; }"
        , "body { font-family: Arial, sans-serif; margin: 20px; }"
        , ".month { page-break-inside: avoid; break-inside: avoid; }"
        , ".month-header { font-size: 1.5em; font-weight: bold;"
            ++ " color: var(--color-brand-primary);"
            ++ " margin: 3ex 0 1.5ex 0;"
            ++ " border-bottom: 2px solid var(--color-brand-accent);"
            ++ " padding-bottom: 5px; }"
        , ".event { display: flex; margin-top: 0.5ex; margin-bottom: 20px;"
            ++ " border-left: 3px solid var(--color-brand-accent); padding-left: 15px; }"
        , ".event { page-break-inside: avoid; break-inside: avoid; }"
        , ".date-column { flex: 0 0 200px; font-weight: bold;"
            ++ " color: var(--color-brand-primary); }"
        , ".details-column { flex: 1; }"
        , ".details-column h2 { margin-top: -0.5ex; margin-bottom: 0; }"
        , ".details-column p { margin: 1ex 0 1.5ex 0; hyphens: auto; }"
        , ".qrcode { display: none; }"
        , "@media print { .qrcode { display: flex; } .readmore { display: none; } }"
        , ".event:focus { outline: 3px solid #0066cc; outline-offset: 4px; border-radius: 2px; cursor: default; }"
        , "@media print { .event:focus { outline: none; } }"
        , ".cal-icon { position: absolute; top: 50%; left: 50%;"
            ++ " transform: translate(-50%,-50%);"
            ++ " width: 24px; height: 24px; padding: 2px; border-radius: 2px;"
            ++ " background: white url(\""
            ++ calendarIconDataUri
            ++ "\") no-repeat center/contain;"
            ++ " print-color-adjust: exact; -webkit-print-color-adjust: exact; }"
        ]

calendarJs :: String
calendarJs =
    unlines
        [ "(function () {"
        , "  document.addEventListener('keydown', function (e) {"
        , "    var focused = document.activeElement;"
        , "    var evts = Array.from(document.querySelectorAll('.event'));"
        , "    if (!focused || !focused.classList.contains('event')) {"
        , "      if ((e.key === 'ArrowDown' || e.key === 'ArrowUp') && evts.length > 0) {"
        , "        e.preventDefault(); evts[0].focus();"
        , "      }"
        , "      return;"
        , "    }"
        , "    var idx = evts.indexOf(focused);"
        , "    if (e.key === 'ArrowDown') {"
        , "      e.preventDefault();"
        , "      if (idx < evts.length - 1) evts[idx + 1].focus();"
        , "    } else if (e.key === 'ArrowUp') {"
        , "      e.preventDefault();"
        , "      if (idx > 0) evts[idx - 1].focus();"
        , "    } else if (e.key === 'Delete' || e.key === 'Backspace') {"
        , "      e.preventDefault();"
        , "      var next = evts[idx + 1] || evts[idx - 1];"
        , "      var month = focused.closest('.month');"
        , "      focused.remove();"
        , "      if (month && month.querySelectorAll('.event').length === 0) month.remove();"
        , "      if (next && document.body.contains(next)) next.focus();"
        , "    }"
        , "  });"
        , "})();"
        ]

eventPageCss :: String
eventPageCss =
    unlines
        [ "body { font-family: Arial, sans-serif; margin: 20px; max-width: 400px; padding: 0 1em; margin: 0 auto; text-align: center; }"
        , "h1 { color: #333; }"
        , "p { margin: 2ex 0; }"
        , "a { color: #0077cc; }"
        ]

-- ---------------------------------------------------------------------------
-- Calendar HTML rendering
-- ---------------------------------------------------------------------------

-- | Render the QR code block linking to the per-event landing page.
renderQrCode :: String -> H.Html
renderQrCode eventPageUrl =
    case qrCodeDataUri eventPageUrl of
        Nothing -> return ()
        Just uri ->
            H.a
                ! A.href (H.toValue eventPageUrl)
                ! A.class_ "qrcode"
                ! A.title "Lisää kalenteriin"
                ! A.target "_blank"
                ! A.style
                    "color: black; text-decoration: none; float: right;\
                    \ margin-left: 10px; flex-direction: column; align-items: center;"
                $ H.div
                    ! A.style "position: relative; width: 100px; height: 100px;"
                $ do
                    H.img
                        ! A.src (H.toValue uri)
                        ! A.alt "QR-koodi kalenteriin"
                        ! A.style "width: 100px; height: 100px;"
                    H.div ! A.class_ "cal-icon" $ mempty

-- | Render a single event row in the embeddable calendar.
renderCalendarEvent :: [(String, String)] -> PB.Event -> H.Html
renderCalendarEvent icsList ev = do
    let ics = fromMaybe "" (lookup (PB.eventId ev) icsList)
    let eventPageUrl = Config.siteBaseUrl ++ "/events/" ++ PB.eventId ev ++ ".html"
    H.div ! A.class_ "event" ! A.tabindex "0" $ do
        H.div ! A.class_ "date-column" $ H.toHtml (DU.formatEventDate ev)
        H.div ! A.class_ "details-column" $ do
            renderQrCode eventPageUrl
            -- Title with optional location
            H.h2 $ do
                H.toHtml (PB.eventTitle ev)
                case PB.eventLocation ev of
                    Nothing -> return ()
                    Just loc ->
                        H.span ! A.style "font-weight: normal;" $
                            H.toHtml (" | " <> loc)
            -- Description
            case PB.eventDescription ev of
                Nothing -> return ()
                Just d -> H.p $ H.toHtml d
            -- Screen-only links (hidden when printing)
            H.p ! A.class_ "readmore" $ do
                H.a
                    ! A.href (H.toValue (icsDataUri ics))
                    ! A.target "_blank"
                    $ "Lisää kalenteriin"
                case PB.eventUrl ev of
                    Nothing -> return ()
                    Just u -> do
                        H.toHtml (" | " :: String)
                        H.a
                            ! A.href (H.toValue (T.unpack u))
                            ! A.target "_blank"
                            $ "Lue lisää\x2026"

-- | Render a month section.
renderMonth :: [(String, String)] -> String -> [PB.Event] -> H.Html
renderMonth icsList monthLabel evs =
    H.div ! A.class_ "month" $ do
        H.div ! A.class_ "month-header" $ H.toHtml monthLabel
        mapM_ (renderCalendarEvent icsList) evs

-- | Generate the embeddable kalenteri.html.
generateCalendarHtml :: [PB.Event] -> IO String
generateCalendarHtml events = do
    now <- getCurrentTime
    let buildDate = formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%S.000Z" now
    -- Pre-generate per-event ICS strings (needed for inline data URIs)
    icsList <- mapM (\ev -> (,) (PB.eventId ev) <$> ICalGen.generateEventIcs ev) events
    let grouped = groupEventsByMonth events
    return $ renderHtml $ H.docTypeHtml ! A.lang "fi" $ do
        H.head $ do
            H.meta ! A.charset "UTF-8"
            H.title "Palikkakalenteri"
            H.meta ! A.name "build-date" ! A.content (H.toValue buildDate)
            H.style $ H.toHtml calendarCss
        H.body $ do
            H.h1 "Palikkakalenteri"
            H.div ! A.class_ "events" $
                mapM_ (uncurry (renderMonth icsList)) grouped
            H.script ! A.type_ "text/javascript" $ H.toHtml calendarJs

-- ---------------------------------------------------------------------------
-- Per-event landing page
-- ---------------------------------------------------------------------------

-- | Generate a per-event landing page (events/{id}.html).
generateEventHtml :: PB.Event -> IO String
generateEventHtml ev = do
    ics <- ICalGen.generateEventIcs ev
    let dateStr = DU.formatEventDate ev
    let eventPageUrl = Config.siteBaseUrl ++ "/events/" ++ PB.eventId ev ++ ".html"
    return $ renderHtml $ H.docTypeHtml ! A.lang "fi" $ do
        H.head $ do
            H.meta ! A.charset "UTF-8"
            H.meta ! A.name "viewport" ! A.content "width=device-width, initial-scale=1.0"
            H.title $ do
                H.toHtml (PB.eventTitle ev)
                H.toHtml (" - Palikkakalenteri" :: String)
            H.style $ H.toHtml eventPageCss
        H.body $ do
            H.h1 (H.toHtml (PB.eventTitle ev))
            case PB.eventLocation ev of
                Nothing -> H.p (H.strong (H.toHtml dateStr))
                Just l -> H.div $ do
                    H.p $ H.strong (H.toHtml dateStr)
                    H.p $ H.strong (H.toHtml l)
            case PB.eventDescription ev of
                Nothing -> return ()
                Just d -> H.p $ H.toHtml d
            H.p
                $ H.a
                    ! A.href (H.toValue (icsDataUri ics))
                    ! A.target "_blank"
                $ "Lisää kalenteriin"
            case PB.eventUrl ev of
                Nothing -> return ()
                Just u ->
                    H.p
                        $ H.a
                            ! A.href (H.toValue (T.unpack u))
                            ! A.target "_blank"
                        $ "Lue lisää\x2026"
            -- QR code linking back to this page
            case qrCodeDataUri eventPageUrl of
                Nothing -> return ()
                Just uri ->
                    H.div ! A.style "margin-top: 1em;"
                        $ H.div
                            ! A.style
                                "position: relative; display: inline-block;\
                                \ width: 100px; height: 100px;"
                        $ do
                            H.img
                                ! A.src (H.toValue uri)
                                ! A.alt "QR-koodi sivulle"
                                ! A.style "width: 100px; height: 100px;"
                            H.div ! A.class_ "cal-icon" $ mempty

-- ---------------------------------------------------------------------------
-- Grouping helper
-- ---------------------------------------------------------------------------

-- | Group events by Finnish month label ("Tammikuu 2025", ...).
groupEventsByMonth :: [PB.Event] -> [(String, [PB.Event])]
groupEventsByMonth events =
    let sorted = sortBy (comparing PB.eventStartDate) events
        labeled =
            map
                ( \ev ->
                    let zt = DU.toHelsinki (PB.eventStartDate ev)
                        local = zonedTimeToLocalTime zt
                        (y, m, _) = toGregorian (localDay local)
                        label = DU.finnishMonthName m ++ " " ++ show y
                     in (label, ev)
                )
                sorted
        grps = groupBy (\(a, _) (b, _) -> a == b) labeled
     in [(label, map snd grp) | grp@((label, _) : _) <- grps]
