# nginx

Reverse proxy for local and production. Both environments use the same files;
only `.env` differs per machine.

## Setup

```sh
cp .env.example .env   # set the domains for this machine
make up
```

## Adding a site

1. Copy `templates/site.conf.template.example` to `templates/<name>.conf.template`.
2. Use a variable for the domain (e.g. `${APP_DOMAIN}`) and set it in `.env`.
3. Make sure the app container is on the `nginx-network` network.
4. `make reload-nginx`

Site templates and `.env` are git-ignored, so this repo stays generic. Copy the same templates
to each machine (local, production) and only change the values in `.env`.

Only variables set in the container's environment (uppercase) are substituted, so lowercase
nginx variables like `$host` are left alone. After editing `.env`, run `make up` to recreate the
container; `restart` does not re-read it.

## Commands

| Command              | What it does                                   |
| -------------------- | ---------------------------------------------- |
| `make up` / `down`   | Start (or recreate after `.env` changes) / stop |
| `make reload-nginx`  | Re-render templates, test, and reload          |
| `make test-config`   | Re-render templates and run `nginx -t`         |
| `make restart-nginx` | Restart the container                          |
| `make sites`         | Print the rendered site configs                |
| `make logs`          | Follow container logs                          |
| `make clear-logs`    | Delete log files and reopen them               |

Shell into the container: `docker compose exec nginx sh`
