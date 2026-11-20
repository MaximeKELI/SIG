# Déploiement production

## Voie rapide

```bash
cp deploy.config.example deploy.config   # éditer DOMAIN
./scripts/prepare-production.sh          # .env.production + TLS + play.release.env
./scripts/deploy-prod.sh                 # compose prod (ports 80/443)
./scripts/install-flutter.sh             # une fois
cd mobile && ./scripts/build_play_aab.sh # AAB → partage/play/
```

Détails Play Store : [`PLAY_STORE.md`](PLAY_STORE.md) · Checklist : [`PRODUCTION_CHECKLIST.md`](PRODUCTION_CHECKLIST.md)

## Prérequis

- Docker & Docker Compose
- Domaine avec HTTPS (Let's Encrypt recommandé pour Play Store)
- `deploy.config` (DOMAIN) puis fichiers générés (jamais committer les secrets) :
  - `SECRET_KEY` (long, aléatoire)
  - `DEBUG=0`
  - `ALLOWED_HOSTS=votredomaine.tg`
  - `CSRF_TRUSTED_ORIGINS=https://votredomaine.tg`
  - Clés externes : NASA / Sentinel / OpenWeather / Gemini

## Checklist go-live

1. `./scripts/prepare-production.sh` (ou copier `.env.production.example` → `.env`)
2. Certificats dans `nginx/certs/` (`setup-tls-certs.sh --letsencrypt` en prod publique)
3. `./scripts/deploy-prod.sh`
4. Vérifier `GET https://domaine/health/` → 200 et `/privacy.html`
5. Planifier sauvegardes : `scripts/backup-daily.sh` (cron, voir `SAUVEGARDE.md`)
6. Mobile : `mobile/scripts/build_play_aab.sh`

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
