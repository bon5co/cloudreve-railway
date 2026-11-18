# cloudreve-railway

Wrapper image for [Cloudreve](https://github.com/cloudreve/cloudreve) (v4.19.1) on [Railway](https://railway.com).

Upstream makes the first account that registers the administrator and opens public sign-up by default, and it listens on a fixed
port 5212 instead of Railway's injected `PORT`. On a public domain the first visitor would own the instance. The wrapper
registers the administrator from `ADMIN_EMAIL` and `ADMIN_PASSWORD` on a loopback-only instance before the public server binds a
port, then starts Cloudreve on `PORT` with public sign-up closed.

- Variables: `ADMIN_PASSWORD` (required, at least 6 characters; the container refuses to start without it), `ADMIN_EMAIL` (default `admin@cloudreve.org`)
- Optional variables: `SITE_URL` (custom domain; defaults to the Railway public domain), `CR_SETTING_register_enabled=1` to reopen sign-up
- Volume: `/cloudreve/data` (database, config and uploaded files)
- Health: `GET /api/v4/site/ping`

Published as `ghcr.io/bon5co/cloudreve-railway`. Template: see the Railway marketplace listing.
