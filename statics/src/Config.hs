{- | Shared URL constants for the Suomen Palikkayhteisö event calendar.

Import from this module for the canonical site URL and PocketBase API URL,
instead of defining them independently in each generator module.
-}
module Config (
    siteBaseUrl,
    pbDefaultUrl,
) where

{- | Canonical site base URL (no trailing slash).
Used for GUID/UID generation in feeds and iCal, and for building links in HTML.
-}
siteBaseUrl :: String
siteBaseUrl = "https://kalenteri.suomenpalikkayhteiso.fi"

{- | Default PocketBase API base URL (production).
Used as fallback when the POCKETBASE_URL environment variable is not set.
-}
pbDefaultUrl :: String
pbDefaultUrl = "https://data.suomenpalikkayhteiso.fi"
