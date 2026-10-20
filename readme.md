# nginx

Reverse proxy with HTTPS for local and production. Both environments use the same files;
only `.env`, site templates and certificates differ per machine (all git-ignored).

## Setup

```sh
cp .env.example .env   # set the values for this machine
make up
```

Open http://localhost or http://`$DEFAULT_DOMAIN` to see the "nginx is running" page
(`templates/default.conf.template`). For HTTPS, create the certificate (see [HTTPS](#https)), then:

```sh
cp templates/default-ssl.conf.template.example templates/default-ssl.conf.template
make reload-nginx
```

Production: in `.env`, uncomment `COMPOSE_FILE` (adds the certbot renewal container) and set `HSTS`.

## Adding a site

1. Get a certificate for the domain (see [HTTPS](#https)).
2. Copy `templates/site.conf.template.example` to `templates/<name>.conf.template` and uncomment it.
3. Use a variable for the domain (e.g. `${APP_DOMAIN}`) and set it in `.env`.
4. Make sure the app container is on the `nginx-network` network.
5. `make reload-nginx`

Only variables set in the container's environment (uppercase) are substituted, so lowercase
nginx variables like `$host` are left alone. After editing `.env`, run `make up` to recreate the
container; `restart` does not re-read it.

Copy the same templates to each machine (local, production) and only change the values in `.env`.

## HTTPS

Certificates live in `letsencrypt/live/<domain>/{fullchain,privkey}.pem` in every environment,
so site templates are identical locally and in production.

Get the certificate **before** adding the site template: nginx refuses to load a site whose
certificate is missing (`make reload-nginx` tests first, so a running nginx is never affected).

**Local** ([mkcert](https://github.com/FiloSottile/mkcert), trusted by your browser):

```sh
mkcert -install                         # once per machine
make cert-local DOMAIN=app.localhost
```

Use `*.localhost` domains locally: they resolve to 127.0.0.1 without editing `/etc/hosts`.

**Production** (Let's Encrypt; DNS must already point to the server):

```sh
make cert DOMAIN=app.example.com STAGING=1   # dry run against the staging CA
make cert DOMAIN=app.example.com             # real certificate
make cert-status                             # expiry dates
```

The certbot container checks for renewals twice a day and only renews certificates that are due.
nginx reloads by itself when a certificate changes (`scripts/reload-on-cert-change.sh`).

## Behind Cloudflare or a load balancer

Nothing changes by default. When you move behind one:

**Cloudflare**

1. `make cloudflare` — trusts Cloudflare's IPs so logs and apps see the real visitor IP
   (re-run occasionally to refresh the list; `rm snippets/real-ip/cloudflare.conf` to disable).
2. Set SSL/TLS mode to **Full (strict)** in Cloudflare.
3. Certificates: either keep Let's Encrypt, or use a Cloudflare Origin Certificate (15 years, no
   renewals) saved as `letsencrypt/live/<domain>/fullchain.pem` and `privkey.pem`.

**Load balancer**: copy `snippets/real-ip/load-balancer.conf.example` to `load-balancer.conf`
and set the balancer's IP range. If the balancer terminates TLS, point it at port 80 and drop
the HTTP→HTTPS redirect from the site template.

## Commands

| Command                    | What it does                                     |
| -------------------------- | ------------------------------------------------ |
| `make up` / `down`         | Start (or recreate after `.env` changes) / stop  |
| `make reload-nginx`        | Re-render templates, test, and reload            |
| `make test-config`         | Re-render templates and run `nginx -t`           |
| `make restart-nginx`       | Restart the container                            |
| `make sites`               | Print the rendered site configs                  |
| `make logs`                | Follow container logs                            |
| `make clear-logs`          | Delete log files and reopen them                 |
| `make cert-local DOMAIN=`  | Local certificate via mkcert                     |
| `make cert DOMAIN=`        | Production certificate via Let's Encrypt         |
| `make cert-status`         | List production certificates and expiry          |
| `make cloudflare`          | Trust Cloudflare IPs (real visitor IPs)          |

Shell into the container: `docker compose exec nginx sh`
