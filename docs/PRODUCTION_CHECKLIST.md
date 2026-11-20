# Checklist production — Web + Play Store

## Actions humaines restantes

1. **Domaine HTTPS** — DNS + certificats dans `nginx/certs/` (`fullchain.pem`, `privkey.pem`), adapter `server_name` dans `nginx/nginx-tls.example.conf`.
2. **`.env` prod** — partir de `.env.production.example` (DEBUG=0, secrets, Redis password, SMTP).
3. **Play Console** — créer l’app, Data Safety (localisation, photos, analytics), lier la privacy : `https://VOTRE-DOMAINE/privacy.html`.
4. **Sauvegarder le keystore** — `mobile/android/upload-keystore.jks` + `key.properties` (hors git, coffre-fort). Déjà généré localement.

## Build AAB Play Store

```bash
cd mobile
flutter pub get
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --dart-define=API_BASE_URL=https://VOTRE-DOMAINE/api/v1 \
  --dart-define=PRIVACY_POLICY_URL=https://VOTRE-DOMAINE/privacy.html
```

## Héberger le web

```bash
cp .env.production.example .env   # éditer
mkdir -p nginx/certs
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

## Corrections déjà en place

| Zone | Statut |
|------|--------|
| Signing release + R8 minify | OK (`key.properties`) |
| HTTPS API obligatoire release | OK |
| Cleartext off (debug LAN OK) | OK |
| Tokens JWT chiffrés | OK (`flutter_secure_storage`) |
| WS JWT hors query string | OK (Sec-WebSocket-Protocol) |
| JWT blacklist logout | OK |
| Consent analytics réel | OK (mobile + web) |
| Privacy policy | OK (`/privacy.html`) |
| Polices bundlées | OK (plus de google_fonts CDN) |
| Adaptive icon | OK |
| RECORD_AUDIO | OK |
| Redis authentifié | OK (via `REDIS_PASSWORD`) |
| Seed démo gated | OK (`SEED_DEMO_DATA=0` prod) |
| Django fail-fast prod | OK |
| Proxy SSL + HSTS | OK |
| CDN Leaflet/Chart locaux | OK (`frontend/vendor/`) |
| PWA icons PNG réels | OK |
| Exports admin via Bearer | OK (boutons + JS) |
| Health detail staff-only | OK |
| Compose healthchecks / limits | OK |
