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
    return $ QRJP.toPngDataUrlS 4 2 code

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
                ++ "<source type=\"image/svg+xml\" srcset=\"logos/horizontal-full.svg\">"
                ++ "<source type=\"image/webp\" srcset=\"logos/horizontal-full.webp\">"
                ++ "<img src=\"logos/horizontal-full.png\""
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
        [ "@font-face { font-family: 'Outfit'; font-style: normal; font-weight: 100 900;"
            ++ " font-display: swap;"
            ++ " src: url('fonts/Outfit-VariableFont_wght.ttf') format('truetype'); }"
        , ":root { --color-brand-primary: #05131D; --color-brand-accent: #FAC80A; }"
        , "body { font-family: 'Outfit', system-ui, sans-serif; margin: 20px; }"
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
        , ".cal-icon { position: absolute; top: 50%; left: 50%;"
            ++ " transform: translate(-50%,-50%);"
            ++ " width: 24px; height: 24px; padding: 2px; border-radius: 2px;"
            ++ " background: white url(\""
            ++ calendarIconDataUri
            ++ "\") no-repeat center/contain; }"
        , ":root { --color-border-default: #E5E7EB; --color-bg-subtle: #F9FAFB;"
            ++ " --color-bg-hover: #F3F4F6; --color-text-muted: #6B7280; }"
        , ".footer { margin-top: auto; border-top: 1px solid var(--color-border-default);"
            ++ " background: var(--color-bg-subtle); padding: 1rem; }"
        , ".footer-content { max-width: 64rem; margin: 0 auto; display: grid;"
            ++ " grid-template-columns: repeat(3,1fr); gap: 1.5rem; }"
        , ".footer-card { display: block; border-radius: 0.5rem; padding: 1rem;"
            ++ " text-decoration: none; color: inherit; text-align: left;"
            ++ " transition: background-color 0.15s; }"
        , ".footer-card:hover { background: var(--color-bg-hover); }"
        , ".footer-icon-row { margin-bottom: 0.75rem; display: flex; align-items: center; }"
        , ".footer-icon { margin-right: 0.5rem; width: 2rem; height: 2rem;"
            ++ " color: var(--color-brand-primary); flex-shrink: 0; }"
        , ".footer-card h3 { font-size: 1.125rem; font-weight: 600; margin: 0; }"
        , ".footer-card p { font-size: 0.875rem; color: var(--color-text-muted); margin: 0.75rem 0 0 0; }"
        , ".footer-feeds { padding: 1rem; text-align: left; }"
        , ".footer-feed-links { margin-top: 0.75rem; text-align: center; }"
        , ".footer-feed-links a { margin: 0 0.25rem; color: var(--color-brand-primary);"
            ++ " text-decoration: none; }"
        , ".footer-feed-links a:hover { text-decoration: underline; }"
        , ".site-logo { display: block; margin-bottom: 1rem; }"
        , ".site-logo img { max-width: 200px; height: auto; }"
        , "@media (prefers-reduced-motion: reduce) { .logo-animated { display: none; } }"
        ]

eventPageCss :: String
eventPageCss =
    "@font-face { font-family: 'Outfit'; font-style: normal; font-weight: 100 900;"
        ++ " font-display: swap;"
        ++ " src: url('../fonts/Outfit-VariableFont_wght.ttf') format('truetype'); }"
        ++ " :root { --color-brand-primary: #05131D; }"
        ++ " body { font-family: 'Outfit', system-ui, sans-serif; margin: 20px; max-width: 800px;"
        ++ " color: var(--color-brand-primary); }"
        ++ " .site-logo { display: block; margin-bottom: 1rem; }"
        ++ " .site-logo img { max-width: 200px; height: auto; }"
        ++ " @media (prefers-reduced-motion: reduce) { .logo-animated { display: none; } }"

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
    H.div ! A.class_ "event" $ do
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

-- | Inline SVG helper — inserts raw SVG markup without escaping.
svgIcon :: String -> H.Html
svgIcon path =
    H.preEscapedToMarkup $
        "<svg class=\"footer-icon\" fill=\"none\" stroke=\"currentColor\""
            ++ " viewBox=\"0 0 24 24\" xmlns=\"http://www.w3.org/2000/svg\">"
            ++ "<path stroke-linecap=\"round\" stroke-linejoin=\"round\""
            ++ " stroke-width=\"2\" d=\""
            ++ path
            ++ "\"></path></svg>"

-- | Footer with subscribe/feed links matching the upstream calendar site design.
renderFooter :: H.Html
renderFooter =
    H.footer ! A.class_ "footer" $ do
        H.div ! A.class_ "footer-content" $ do
            -- ICalendar
            H.a
                ! A.class_ "footer-card"
                ! A.href "webcal://kalenteri.suomenpalikkayhteiso.fi/kalenteri.ics"
                ! A.target "_blank"
                $ do
                    H.div ! A.class_ "footer-icon-row" $ do
                        svgIcon "M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                        H.h3 "iCalendar"
                    H.p
                        "Kalenterivienti (ICS) tilaa tai integroi koko kalenterin helposti. Klikkaa kalenteri puhelimeesi!"
            -- HTML | PDF
            H.a
                ! A.class_ "footer-card"
                ! A.href (H.toValue (Config.siteBaseUrl ++ "/kalenteri.html"))
                ! A.target "_blank"
                $ do
                    H.div ! A.class_ "footer-icon-row" $ do
                        svgIcon
                            "M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                        H.h3 "HTML | PDF"
                    H.p "Upota tai tulosta valmis tapahtumalistaus. Sisältää kalenterilinkit yksittäisiin tapahtumiin."
            -- Feeds
            H.div ! A.class_ "footer-feeds" $ do
                H.div ! A.class_ "footer-icon-row" $ do
                    svgIcon
                        "M6 5c7.18 0 13 5.82 13 13M6 11a7 7 0 017 7m-6 0a1 1 0 11-2 0 1 1 0 012 0m6 0a1 1 0 11-2 0 1 1 0 012 0m6 0a1 1 0 11-2 0 1 1 0 012 0"
                    H.h3 "Syötteet"
                H.p "Syötteet integroivat uudet tapahtumat verkkosivuille. Nämäkin sisältävät kalenterilinkit."
                H.div ! A.class_ "footer-feed-links" $ do
                    H.a ! A.href (H.toValue (Config.siteBaseUrl ++ "/kalenteri.atom")) ! A.target "_blank" $ "ATOM"
                    H.toHtml (" | " :: String)
                    H.a ! A.href (H.toValue (Config.siteBaseUrl ++ "/kalenteri.rss")) ! A.target "_blank" $ "RSS"
                    H.toHtml (" | " :: String)
                    H.a ! A.href (H.toValue (Config.siteBaseUrl ++ "/kalenteri.json")) ! A.target "_blank" $ "JSON"
                    H.toHtml (" | " :: String)
                    H.a ! A.href (H.toValue (Config.siteBaseUrl ++ "/kalenteri.geo.json")) ! A.target "_blank" $
                        "GeoJSON"

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
            siteLogo
            H.h1 "Palikkakalenteri"
            H.div ! A.class_ "events" $
                mapM_ (uncurry (renderMonth icsList)) grouped
            renderFooter

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
            H.title $ H.toHtml (PB.eventTitle ev)
            H.style $ H.toHtml eventPageCss
        H.body $ do
            siteLogo
            H.h1 $ H.toHtml (PB.eventTitle ev)
            H.p $ H.toHtml dateStr
            case PB.eventLocation ev of
                Nothing -> return ()
                Just l -> H.p $ H.toHtml l
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
