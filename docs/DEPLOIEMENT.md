# Déploiement production

## Prérequis

- Docker & Docker Compose
- Domaine avec HTTPS (Let's Encrypt recommandé)
- Variables dans `.env` (jamais committer les secrets) :
  - `SECRET_KEY` (long, aléatoire)
  - `DEBUG=0`
  - `ALLOWED_HOSTS=votredomaine.tg`
  - `CSRF_TRUSTED_ORIGINS=https://votredomaine.tg`
  - Clés externes : NASA / Sentinel / OpenWeather / Gemini

## Checklist go-live

1. Copier `.env.example` → `.env` et renseigner les secrets (hors dépôt git)
2. `docker compose up -d --build`
3. `docker compose exec web python manage.py migrate`
4. `docker compose exec web python manage.py collectstatic --noinput`
5. Activer TLS : voir `nginx/nginx-tls.example.conf` + certificats Let's Encrypt
6. Vérifier `GET https://domaine/health/` → 200
7. Planifier sauvegardes : `scripts/backup-daily.sh` (cron, voir `SAUVEGARDE.md`)
8. Mobile : `--dart-define=API_BASE_URL=https://domaine/api/v1`

## HTTPS (nginx)

Option A — reverse proxy TLS externe devant `:8081`.  
Option B — remplacer `nginx/nginx.conf` par `nginx/nginx-tls.example.conf` et monter :

```yaml
volumes:
  - ./certs/fullchain.pem:/etc/nginx/certs/fullchain.pem:ro
  - ./certs/privkey.pem:/etc/nginx/certs/privkey.pem:ro
```

Ports : `443:443` (et redirection 80→443).

## Limitation de débit

| Couche | Variable / zone | Défaut prod conseillé |
|--------|-----------------|------------------------|
| nginx auth | `auth_limit` | 15 req/min/IP (`nginx-tls.example.conf`) |
| nginx API | `api_limit` | 300 req/min/IP |
| DRF | `THROTTLE_AUTH` | `20/min` (`.env`) |
| DRF | `THROTTLE_ANON` / `THROTTLE_USER` | voir `.env.example` |
| Middleware | `MIDDLEWARE_RATE_PER_MIN` | 300 |

## Santé

`GET /health/` — doit retourner 200.  
`GET /health/?detail=1` — aperçu services (PostGIS, Redis, APIs).
