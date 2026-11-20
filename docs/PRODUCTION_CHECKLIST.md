# Checklist production — Web + Play Store

## Automatisé (déjà en place dans le code)

| Zone | Statut |
|------|--------|
| Signing release + R8 minify | OK (`key.properties`) |
| HTTPS API obligatoire release | OK |
| Cleartext off (debug LAN OK) | OK |
| Tokens JWT chiffrés | OK (`flutter_secure_storage`) |
| WS JWT hors query string | OK (Sec-WebSocket-Protocol) |
| JWT blacklist logout | OK |
| Consent analytics optionnel + privacy requis | OK |
| Privacy policy | OK (`/privacy.html`) |
| Polices bundlées | OK |
| Adaptive icon + feature graphic | OK (`mobile/store/`) |
| Redis authentifié | OK |
| Seed démo gated | OK (`SEED_DEMO_DATA=0` prod) |
| Django fail-fast prod | OK |
| Proxy SSL + HSTS | OK |
| CDN Leaflet/Chart locaux | OK |
| Compose prod healthchecks / limits | OK |
| Scripts prepare / deploy / AAB | OK (`scripts/`, `mobile/scripts/`) |

## Go-live en 3 commandes

```bash
# 1) Éditer le domaine
cp deploy.config.example deploy.config   # si besoin
# DOMAIN=sig-sols.tg  TLS_MODE=letsencrypt|selfsigned

# 2) Générer .env.production + nginx TLS + certs + play.release.env
./scripts/prepare-production.sh

# 3a) Web
./scripts/deploy-prod.sh

# 3b) AAB Play (Flutter via ./scripts/install-flutter.sh si besoin)
./scripts/install-flutter.sh
cd mobile && ./scripts/build_play_aab.sh
```

## Actions humaines restantes

1. **DNS** — A/AAAA vers le serveur pour `DOMAIN` (+ www).
2. **Let's Encrypt** — pour Play Store public : `TLS_MODE=letsencrypt` puis `./scripts/setup-tls-certs.sh --letsencrypt $DOMAIN $ADMIN_EMAIL` (selfsigned = smoke-test only).
3. **SMTP** — renseigner `EMAIL_*` dans `.env.production` (reset mot de passe).
4. **Clés API** — NASA / Sentinel / OpenWeather / Gemini dans `.env.production`.
5. **Play Console** — créer l’app, Data Safety (voir `docs/PLAY_STORE.md`), uploader `partage/play/*-play.aab`, captures écran.
6. **Coffre-fort** — sauvegarder `mobile/android/upload-keystore.jks` + `key.properties`.

## Build AAB (détail)

```bash
cd mobile
./scripts/build_play_aab.sh
# ou :
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --dart-define=API_BASE_URL=https://VOTRE-DOMAINE/api/v1 \
  --dart-define=PRIVACY_POLICY_URL=https://VOTRE-DOMAINE/privacy.html
```

## Héberger le web (détail)

```bash
./scripts/prepare-production.sh
./scripts/deploy-prod.sh
# équivalent :
# docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```
