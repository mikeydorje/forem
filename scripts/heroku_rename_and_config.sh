#!/usr/bin/env bash
set -euo pipefail

# Automates: optional app rename, config var set, Forem settings update, restart dynos.
# Requires env vars:
#   HEROKU_API_KEY  (Heroku account API key)
#   APP_CURRENT     (current app name)
#   APP_NEW         (desired new app name; can equal APP_CURRENT if no rename)
#   SITE_NAME       (display/community name)
#
# Example usage:
#   export HEROKU_API_KEY=xxxxxxxx
#   export APP_CURRENT=my-old-app
#   export APP_NEW=my-prodtest-app
#   export SITE_NAME="My Product Test"
#   bash scripts/heroku_rename_and_config.sh
#
# Notes:
# - Uses Heroku Platform API directly; no heroku CLI required.
# - Performs rename only if APP_NEW != APP_CURRENT.
# - Sets APP_DOMAIN and APP_PROTOCOL.
# - Launches a one-off dyno to persist Forem DB-backed settings (community name, app_domain, feed_style, admin timestamp).
# - Restarts web + worker dynos by cycling formation (scale to current value).
# - Idempotent: re-running with same values is safe.

HEROKU_API_URL="https://api.heroku.com"
API_KEY="${HEROKU_API_KEY:?HEROKU_API_KEY required}"
APP_CURRENT="${APP_CURRENT:?APP_CURRENT required}"
APP_NEW="${APP_NEW:?APP_NEW required}"
SITE_NAME="${SITE_NAME:?SITE_NAME required}"

accept_header="Accept: application/vnd.heroku+json; version=3"
auth_header="Authorization: Bearer ${API_KEY}" 
content_header="Content-Type: application/json"

log() { printf "\n[heroku-config] %s\n" "$*"; }

# 1. Optional rename
if [[ "${APP_NEW}" != "${APP_CURRENT}" ]]; then
  log "Renaming app ${APP_CURRENT} -> ${APP_NEW}";
  curl -sS -X PATCH "${HEROKU_API_URL}/apps/${APP_CURRENT}" \
    -H "${accept_header}" -H "${auth_header}" -H "${content_header}" \
    -d "{\"name\":\"${APP_NEW}\"}" | jq -r '.name' || {
      echo "Rename failed"; exit 1; }
  APP_CURRENT="${APP_NEW}" # update working name after rename
else
  log "Skipping rename; APP_NEW == APP_CURRENT (${APP_CURRENT})";
fi

APP_DOMAIN="${APP_NEW}.herokuapp.com"

# 2. Set config vars
log "Setting APP_DOMAIN=${APP_DOMAIN} APP_PROTOCOL=https://"
curl -sS -X PATCH "${HEROKU_API_URL}/apps/${APP_CURRENT}/config-vars" \
  -H "${accept_header}" -H "${auth_header}" -H "${content_header}" \
  -d "{\"APP_DOMAIN\":\"${APP_DOMAIN}\",\"APP_PROTOCOL\":\"https://\"}" | jq -r '.APP_DOMAIN' || {
    echo "Config var update failed"; exit 1; }

# 3. One-off dyno to persist Forem settings
runner_cmd=$(cat <<'EOF'
rails runner "Settings::Community.set_community_name(ENV.fetch('SITE_NAME'));\nSettings::General.set_app_domain(ENV.fetch('APP_DOMAIN'));\nSettings::UserExperience.set_feed_style('rich');\nSettings::General.set_admin_action_taken_at(Time.current);\nputs({name: Settings::Community.community_name, domain: Settings::General.app_domain, feed: Settings::UserExperience.feed_style}.inspect)"
EOF
)

log "Launching one-off dyno to persist Forem settings"
# Pass SITE_NAME and APP_DOMAIN as env for runner
curl -sS -X POST "${HEROKU_API_URL}/apps/${APP_CURRENT}/dynos" \
  -H "${accept_header}" -H "${auth_header}" -H "${content_header}" \
  -d "{\"command\":\"bash -lc 'export SITE_NAME=\"${SITE_NAME//"/\\"}\" APP_DOMAIN=\"${APP_DOMAIN}\"; ${runner_cmd//"/\\"}'\", \"time_to_live\": 600}" | jq -r '.name' || {
    echo "Dyno launch failed"; exit 1; }
log "(Wait for dyno to finish: check activity in Heroku dashboard if desired)"

# 4. Restart dynos by cycling process types
log "Cycling web & worker dynos if they exist"
formation=$(curl -sS -X GET "${HEROKU_API_URL}/apps/${APP_CURRENT}/formation" -H "${accept_header}" -H "${auth_header}")
web_qty=$(echo "$formation" | jq -r '.[] | select(.type=="web") | .quantity') || true
worker_qty=$(echo "$formation" | jq -r '.[] | select(.type=="worker") | .quantity') || true
if [[ -n "$web_qty" && "$web_qty" != "null" ]]; then
  curl -sS -X PATCH "${HEROKU_API_URL}/apps/${APP_CURRENT}/formation/web" \
    -H "${accept_header}" -H "${auth_header}" -H "${content_header}" \
    -d "{\"quantity\":${web_qty},\"size\":\"standard-1x\"}" >/dev/null || true
  log "Web dynos cycled (${web_qty})"
fi
if [[ -n "$worker_qty" && "$worker_qty" != "null" ]]; then
  curl -sS -X PATCH "${HEROKU_API_URL}/apps/${APP_CURRENT}/formation/worker" \
    -H "${accept_header}" -H "${auth_header}" -H "${content_header}" \
    -d "{\"quantity\":${worker_qty},\"size\":\"standard-1x\"}" >/dev/null || true
  log "Worker dynos cycled (${worker_qty})"
fi

log "Done. Verify: https://${APP_DOMAIN}/ (title includes '${SITE_NAME}')"
log "If signed-in covers absent: open DevTools console and run: localStorage.removeItem('current_user'); location.reload();"
