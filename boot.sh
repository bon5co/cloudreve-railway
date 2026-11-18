#!/bin/sh
# Railway boot for Cloudreve.
#
# Upstream makes the FIRST account that registers the administrator (inventory/user.go: "For the first user registered, elevate
# it to admin group") and opens public sign-up by default, so a fresh public deploy belongs to whoever reaches the sign-up page
# first. This script registers the administrator from ADMIN_EMAIL / ADMIN_PASSWORD on a loopback-only instance before the real
# server ever binds a public port, then starts the server with sign-up closed. Upstream also listens on a fixed :5212 and ignores
# Railway's PORT; the healthcheck dials the injected PORT, so the listen address is set from it.
set -u
cd /cloudreve
: "${PORT:=8080}"
EMAIL="$(printf '%s' "${ADMIN_EMAIL:-admin@cloudreve.org}" | tr 'A-Z' 'a-z')"
if [ -z "${ADMIN_PASSWORD:-}" ]; then
  echo "[railway] ADMIN_PASSWORD is not set; refusing to start a file server whose first sign-up becomes admin" >&2
  exit 1
fi
if [ "${#ADMIN_PASSWORD}" -lt 6 ]; then
  echo "[railway] ADMIN_PASSWORD must be at least 6 characters (Cloudreve's minimum)" >&2
  exit 1
fi

DATA=/cloudreve/data
MARK="$DATA/.railway-admin-bootstrapped"
mkdir -p "$DATA"

json_post() { # path, body -> response body on stdout
  curl -s -m 20 -X POST -H 'Content-Type: application/json' -d "$2" "http://127.0.0.1:5213$1"
}

if [ ! -f "$MARK" ]; then
  echo "[railway] first boot: registering administrator $EMAIL on loopback"
  env "CR_CONF_System.Listen=127.0.0.1:5213" CR_SETTING_register_enabled=1 CR_SETTING_email_active=0 CR_SETTING_reg_captcha=0 \
    ./cloudreve &
  PID=$!
  n=0
  until [ "$(curl -s -o /dev/null -w '%{http_code}' -m 5 http://127.0.0.1:5213/api/v4/site/ping)" = 200 ]; do
    n=$((n + 1))
    if [ "$n" -gt 120 ] || ! kill -0 "$PID" 2>/dev/null; then
      echo "[railway] bootstrap instance never answered /api/v4/site/ping" >&2
      kill "$PID" 2>/dev/null
      exit 1
    fi
    sleep 1
  done
  BODY=$(printf '{"email":"%s","password":"%s","language":"en-US"}' "$EMAIL" "$ADMIN_PASSWORD")
  json_post /api/v4/user "$BODY" > "$DATA/.railway-register.out"
  # register answers code 0 on success; an existing account (a crashed first boot) is fine if the password logs in
  LOGIN=$(json_post /api/v4/session/token "$BODY")
  if printf '%s' "$LOGIN" | grep -q '"code":0'; then
    : > "$MARK"
    echo "[railway] administrator $EMAIL ready"
  else
    echo "[railway] could not register or log in $EMAIL: $(cat "$DATA/.railway-register.out")" >&2
    kill "$PID" 2>/dev/null
    exit 1
  fi
  rm -f "$DATA/.railway-register.out"
  kill "$PID"
  wait "$PID" 2>/dev/null
fi

# Public instance: listen on Railway's PORT, sign-up closed unless the deployer sets CR_SETTING_register_enabled=1, site URL from
# the public domain (SITE_URL overrides it for a custom domain).
CR_LISTEN=":$PORT"
: "${CR_SETTING_register_enabled:=0}"
export CR_SETTING_register_enabled
if [ -n "${SITE_URL:-}" ]; then
  export CR_SETTING_siteURL="$SITE_URL"
elif [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  export CR_SETTING_siteURL="https://$RAILWAY_PUBLIC_DOMAIN"
fi
exec env "CR_CONF_System.Listen=$CR_LISTEN" sh ./entrypoint.sh
