# SIG Sols Togo — Application mobile Flutter

Application mobile **Flutter** avec **parité fonctionnelle** du site web (`frontend/`), branchée sur le **même backend Django** (`/api/v1/`).

## Modules (parité web)

| Module | Mobile | API |
|--------|--------|-----|
| Carte + overlays | Heatmap, trajectoire, proximité, NASA/Sentinel, météo, dessin parcelle, offline | `/points/`, `/heatmap/`, `/spatial/`, tiles |
| Dashboard | KPIs + APIs externes | `/dashboard/stats/` |
| Quiz | Difficulté, examen, badges, parcours, défi, certificat PDF | `/education/quiz/` |
| Fiches | PDF + favoris | `/education/sheets/` |
| Vidéos / Shorts | Lecteur intégré, likes, commentaires, stories, upload | `/videos/` |
| Communauté | Fil, profil public, follow, DM, favoris | `/auth/feed/`, messages |
| Assistant IA | Chat Gemini | `/assistant/chat/` |
| Profil | Édition, photo, mot de passe, trajectoire | `/auth/profile/` |
| Parcelle | Zones + GPS + analyse live | `/spatial/parcel/live/` |
| Admin | Validation, analytics, modération, exports, ML/NASA | `/platform/admin/` |
| Auth | Login, register, forgot + reset token | `/auth/`, `/platform/password/` |
| i18n | FR · EN · EE · KAB | `LocaleService` |
| Thème | Clair / sombre (émeraude · or) | `AppTheme` |
| Onboarding | Tour 3 écrans première visite | SharedPreferences |

## Lancer

```bash
cd mobile && flutter pub get
flutter run -d linux
# Android émulateur
flutter run -d android
# Téléphone
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8081/api/v1
```

Backend requis : `docker compose up -d` → `http://localhost:8081`

## Tests

```bash
flutter test --exclude-tags integration
flutter analyze lib
```
