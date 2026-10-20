#!/bin/sh
# Runs at container start (mounted into /docker-entrypoint.d/).
# Watches the certificates in the background and reloads nginx when any of them
# changes, e.g. after `certbot renew`, so no Docker socket access is needed.

INTERVAL="${CERT_CHECK_INTERVAL:-3600}"

checksum() {
    find -L /etc/letsencrypt/live -name fullchain.pem -exec cat {} + 2>/dev/null | md5sum
}

(
    last=$(checksum)
    while sleep "$INTERVAL"; do
        current=$(checksum)
        if [ "$current" != "$last" ]; then
            echo "$0: certificates changed, reloading nginx"
            nginx -s reload && last=$current
        fi
    done
) </dev/null &
