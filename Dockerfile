# Cloudreve wrapper for Railway. Upstream makes the first registered account the administrator and opens public sign-up, and it
# listens on a fixed :5212 instead of Railway's PORT. The wrapper registers the administrator from ADMIN_EMAIL / ADMIN_PASSWORD
# on a loopback instance before the public server starts, closes sign-up, and listens on PORT.
# upstream: cloudreve/Cloudreve
FROM cloudreve/cloudreve:4.19.1@sha256:5c6c5baf7fa5bc6e1bb9a7509c09dde00e80b618d180244eb1d5f7e36b358ea2

RUN apk add --no-cache curl
COPY boot.sh /cloudreve/railway-boot.sh
RUN chmod +x /cloudreve/railway-boot.sh

ENV PORT=8080 \
    ADMIN_EMAIL=admin@cloudreve.org
EXPOSE 8080
# replaces upstream's ENTRYPOINT (entrypoint.sh); boot.sh runs it itself once the administrator exists
ENTRYPOINT ["sh", "/cloudreve/railway-boot.sh"]
