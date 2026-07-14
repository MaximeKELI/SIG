.PHONY: up down build migrate seed test test-assistant test-gemini-live lint shell docs

up:
	docker compose up -d --build

down:
	docker compose down

build:
	docker compose build

migrate:
	docker compose exec web python manage.py migrate

seed:
	docker compose exec web python manage.py seed_demo_data

test:
	docker compose run --rm --no-deps --entrypoint "" web pytest -q --tb=short -m "not nasa_live and not gemini_live"

test-gemini-live:
	docker compose run --rm --no-deps --entrypoint "" \
		-e GEMINI_LIVE_TESTS=1 \
		-e GEMINI_API_KEY=$$(grep '^GEMINI_API_KEY=' .env | cut -d= -f2-) \
		web pytest apps/assistant/tests/test_chat.py::test_assistant_chat_live_gemini -v -m gemini_live

test-assistant:
	docker compose run --rm --no-deps --entrypoint "" web pytest apps/assistant/tests/ -v --tb=short

test-nasa-live:
	docker compose run --rm --no-deps --entrypoint "" -e NASA_LIVE_TESTS=1 web pytest -m nasa_live -v

test-frontend:
	cd frontend && npm test

test-e2e:
	cd frontend && npm run test:e2e

test-linkage:
	./scripts/test-linkage.sh

test-all: test test-frontend test-e2e test-linkage

lint:
	docker compose exec web flake8 apps config --max-line-length=120

shell:
	docker compose exec web python manage.py shell

logs:
	docker compose logs -f web

train-ml:
	docker compose exec web python manage.py train_fertility_model

ingest-nasa:
	docker compose exec web python manage.py ingest_nasa

restart:
	docker compose restart web nginx

rebuild-web:
	docker compose build web
	docker compose up -d --force-recreate web nginx

repair-docker:
	./scripts/repair-docker.sh

fix-web:
	@echo "Arrêt des anciens conteneurs web (sudo si besoin)…"
	-docker rm -f dusol_web 2>/dev/null || true
	docker compose build web
	docker compose up -d --force-recreate --remove-orphans web nginx
	@echo "Test API assistant :"
	@sleep 3
	@curl -sf http://localhost:8081/api/v1/assistant/status/ || echo "Échec — lancez: sudo docker rm -f dusol_web && make fix-web"

logs-web:
	docker compose logs -f web
