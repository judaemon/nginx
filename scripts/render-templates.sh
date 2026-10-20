#!/bin/sh
# Replaces the image's 20-envsubst-on-templates.sh (mounted over it in docker-compose.yml).
# Renders templates/*.template into $NGINX_ENVSUBST_OUTPUT_DIR like the original, but
# never writes a template that would stop nginx from starting:
# - ${VARS} that are not all set: nginx reads the leftover ${VAR} as an unknown runtime variable
# - ssl_certificate / ssl_certificate_key files that do not exist
#
# At container start such a template is skipped with a warning, so nginx and the other
# sites still come up. With STRICT=1 (`make render`) it is an error instead.

ME=$(basename "$0")
template_dir="${NGINX_ENVSUBST_TEMPLATE_DIR:-/etc/nginx/templates}"
suffix="${NGINX_ENVSUBST_TEMPLATE_SUFFIX:-.template}"
output_dir="${NGINX_ENVSUBST_OUTPUT_DIR:-/etc/nginx/conf.d}"

[ -d "$template_dir" ] || exit 0

# Only substitute variables that are set, so nginx's own $host etc. are left alone
defined_envs=$(printf '${%s} ' $(awk 'END { for (name in ENVIRON) print name }' < /dev/null))

level=WARNING
[ -n "$STRICT" ] && level=ERROR

failed=0
for template in "$template_dir"/*"$suffix"; do
    [ -f "$template" ] || continue
    output_path="$output_dir/$(basename "$template" "$suffix")"

    missing=""
    # Ignore commented-out lines, where a leftover ${VAR} is harmless
    for var in $(grep -v '^[[:space:]]*#' "$template" | grep -oE '\$\{[A-Z_][A-Z0-9_]*\}' | tr -d '${}' | sort -u); do
        eval "[ -n \"\${$var+set}\" ]" || missing="$missing $var"
    done

    if [ -n "$missing" ]; then
        echo "$ME: $level: skipping $template, not set in the container:$missing" >&2
        echo "$ME: add them to .env and run 'make up' (restart does not re-read .env)" >&2
        failed=1
        continue
    fi

    rendered=$(envsubst "$defined_envs" < "$template")

    # Paths with nginx variables (e.g. $ssl_server_name) are resolved per request: not checked
    missing=""
    for cert in $(printf '%s\n' "$rendered" | grep -v '^[[:space:]]*#' \
            | sed -nE 's/^[[:space:]]*ssl_certificate(_key)?[[:space:]]+([^;[:space:]]+).*/\2/p' | sort -u); do
        case "$cert" in *'$'*) continue ;; esac
        [ -e "$cert" ] || missing="$missing $cert"
    done

    if [ -n "$missing" ]; then
        echo "$ME: $level: skipping $template, certificate not found:$missing" >&2
        echo "$ME: create it (make cert-local / make cert DOMAIN=...), then 'make reload-nginx'" >&2
        failed=1
        continue
    fi

    echo "$ME: Running envsubst on $template to $output_path"
    printf '%s\n' "$rendered" > "$output_path"
done

if [ "$failed" = 1 ] && [ -n "$STRICT" ]; then
    exit 1
fi
exit 0
