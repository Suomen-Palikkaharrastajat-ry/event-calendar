module DescriptionHtml (
    textToHtmlWithBreaks,
    descriptionWithDateHtml,
) where

import Data.List (intercalate)
import qualified Data.Text as T

-- | Convert mixed line endings to LF.
normalizeNewlines :: String -> String
normalizeNewlines [] = []
normalizeNewlines ('\r' : '\n' : rest) = '\n' : normalizeNewlines rest
normalizeNewlines ('\r' : rest) = '\n' : normalizeNewlines rest
normalizeNewlines (c : rest) = c : normalizeNewlines rest

-- | Escape user-provided text so it is safe to inject into HTML.
escapeHtml :: String -> String
escapeHtml = concatMap esc
  where
    esc '<' = "&lt;"
    esc '>' = "&gt;"
    esc '&' = "&amp;"
    esc '"' = "&quot;"
    esc '\'' = "&apos;"
    esc c = [c]

-- | Split on LF while preserving empty segments.
splitOnLf :: String -> [String]
splitOnLf s = case break (== '\n') s of
    (line, []) -> [line]
    (line, _ : rest) -> line : splitOnLf rest

-- | Escape text and preserve line breaks with explicit '<br/>' tags.
textToHtmlWithBreaks :: String -> String
textToHtmlWithBreaks =
    intercalate "<br/>" . splitOnLf . escapeHtml . normalizeNewlines

-- | Build a HTML-safe description block with the formatted date appended.
descriptionWithDateHtml :: Maybe T.Text -> String -> String
descriptionWithDateHtml mDesc date =
    let raw = case mDesc of
            Nothing -> date
            Just d | T.null d -> date
            Just d -> T.unpack d ++ "\n\n" ++ date
     in textToHtmlWithBreaks raw
