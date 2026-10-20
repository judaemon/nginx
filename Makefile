.PHONY: reload-nginx restart-nginx up down render test-config clear-logs logs sites

reload-nginx: test-config
	docker compose exec nginx nginx -s reload

restart-nginx:
	docker compose restart nginx

up:
	docker compose up -d

down:
	docker compose down

# Re-render templates/*.template into /etc/nginx/sites (only runs automatically at container start)
render:
	docker compose exec nginx sh -c 'rm -f /etc/nginx/sites/*.conf && /docker-entrypoint.d/20-envsubst-on-templates.sh'

test-config: render
	docker compose exec nginx nginx -t

clear-logs:
	docker compose exec nginx sh -c "rm -f /var/log/nginx/*.log"
	docker compose exec nginx nginx -s reopen

logs:
	docker compose logs -f nginx

# Show the rendered site configs nginx is actually using
sites:
	docker compose exec nginx sh -c 'tail -n +1 /etc/nginx/sites/*.conf'
