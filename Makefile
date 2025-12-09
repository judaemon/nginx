.PHONY: reload-nginx restart-nginx up down test-config clear-logs logs

reload-nginx:
	docker compose exec nginx nginx -s reload

restart-nginx:
	docker compose restart nginx

up:
	docker compose up -d

down:
	docker compose down

test-config:
	docker compose exec nginx nginx -t

clear-logs:
	docker compose exec nginx sh -c "rm -f /var/log/nginx/*.log"
	docker compose exec nginx nginx -s reload
