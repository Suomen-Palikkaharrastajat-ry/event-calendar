#!/usr/bin/env bash
set -euo pipefail
curl -f --silent --output /dev/null "$SITE_URL"

# Signed-out visitors read the events from these files instead of PocketBase:
# every item must carry its PocketBase record, and each listed year file must exist.
feed="$(curl -f --silent "${SITE_URL%/}/kalenteri.json")"
jq -e '.items | all(has("_palikkakalenteri"))' <<<"$feed" >/dev/null
years="$(jq -r '._palikkakalenteri.archive | if type == "array" then .[] else error("no archive index") end' <<<"$feed")"
for year in $years; do
  curl -f --silent --output /dev/null "${SITE_URL%/}/kalenteri-$year.json"
done

echo "Smoke test passed: $SITE_URL"
