restart-nginx:
	docker-compose restart nginx

up:
	docker-compose up -d

down:
	docker-compose down

test-config:
	docker-compose exec nginx nginx -t
