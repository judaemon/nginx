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
4. Connect nginx and the app (see [Reaching the app container](#reaching-the-app-container)).
5. `make up` if you changed `.env` or the override, then `make reload-nginx`.

Only variables set in the container's environment (uppercase) are substituted, so lowercase
nginx variables like `$host` are left alone. The container reads `.env` only when it is created,
so after editing `.env` run `make up`; `make reload-nginx` refuses to run until you do.

A template that uses a variable missing from the container is skipped at startup (warning in
`make logs`), so nginx and the other sites keep running. `make reload-nginx` fails on it instead.

### Reaching the app container

nginx finds an app by container name, which only works when both share a Docker network.
Either:

- **Join the app's network from here (local, recommended):** copy
  `docker-compose.override.yml.example` to `docker-compose.override.yml`, add the app's network,
  and `make up`. The app project needs no changes and stays reachable however it is started.
  Every network listed there must exist, or nginx will not start (fresh machine, after
  `docker network prune`): create it with `docker network create <name>`.
- **Add the app to `nginx-network`** in the app's own compose file. Beware of a
  `docker-compose.override.yml` there: Compose skips it when run with `-f`, as many Makefiles do.

In the template, proxy to the app's unique `container_name` (e.g. `notifications-laravel`), not
its service name: with several apps, names like `laravel` or `nginx` can exist on more than one
network. Until the name resolves, that site returns 502 while nginx and other sites keep working.

Copy the same templates to each machine (local, production) and only change the values in `.env`.

## HTTPS

Certificates live in `letsencrypt/live/<domain>/{fullchain,privkey}.pem` in every environment,
so site templates are identical locally and in production.

Get the certificate **before** adding the site template: nginx refuses to load a site whose
certificate is missing. `make reload-nginx` fails on it, so a running nginx is never affected;
at container start (reboot, `make up`) the site is skipped with a warning in `make logs`. This
applies on every machine: copy a template only where its certificate already exists.

**Local** ([mkcert](https://github.com/FiloSottile/mkcert), trusted by your browser):

```sh
mkcert -install                         # once per machine
make cert-local DOMAIN=app.localhost
```

Use `*.localhost` domains locally: they resolve to 127.0.0.1 without editing `/etc/hosts`.

**Browser says "Not secure" / `NET::ERR_CERT_AUTHORITY_INVALID` (Linux, Chrome/Brave/Chromium)**

These browsers use their own trust store (`~/.pki/nssdb`), not the system one. `mkcert -install`
skips it if it does not exist yet (or if `certutil` is missing), while `curl` still works. Fix:

```sh
sudo pacman -S nss                       # provides certutil (Debian/Ubuntu: libnss3-tools)
mkdir -p ~/.pki/nssdb
certutil -d sql:$HOME/.pki/nssdb -N --empty-password
certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n "mkcert development CA" \
    -i "$(mkcert -CAROOT)/rootCA.pem"
```

Then fully quit the browser (`pkill brave` / `pkill chrome`) and reopen it.
Firefox keeps its own store per profile: open Firefox once, then rerun `mkcert -install`.

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

## Troubleshooting

Find the message with `make logs` (startup) or in `logs/error.log` (requests).

| Message                                              | Cause and fix                                                         |
| ---------------------------------------------------- | --------------------------------------------------------------------- |
| `skipping …, not set in the container: VAR`          | `VAR` missing from `.env`, or `.env` changed after start: `make up`   |
| `skipping …, certificate not found: …`               | Create the certificate (see [HTTPS](#https)), then `make reload-nginx` |
| `nginx container is older than .env …`               | `.env` or the compose files changed: `make up`, then retry            |
| `… could not be resolved` (site returns 502)         | App container down, or not on a shared network (see [Reaching the app container](#reaching-the-app-container)) |
| `network … declared as external, but could not be found` | Network from the override is missing: `docker network create <name>` |
| `connect() failed (111: Connection refused)` (502)   | Container found but nothing listens on that port: check the port in `proxy_pass` |

## Commands

| Command                    | What it does                                     |
| -------------------------- | ------------------------------------------------ |
| `make up` / `down`         | Start (or recreate after `.env` changes) / stop  |
| `make reload-nginx`        | Re-render templates, test, and reload            |
| `make test-config`         | Re-render templates and run `nginx -t`           |
| `make restart-nginx`       | Recreate the container (re-reads `.env`)         |
| `make sites`               | Print the rendered site configs                  |
| `make logs`                | Follow container logs                            |
| `make clear-logs`          | Delete log files and reopen them                 |
| `make cert-local DOMAIN=`  | Local certificate via mkcert                     |
| `make cert DOMAIN=`        | Production certificate via Let's Encrypt         |
| `make cert-status`         | List production certificates and expiry          |
| `make cloudflare`          | Trust Cloudflare IPs (real visitor IPs)          |

Shell into the container: `docker compose exec nginx sh`
