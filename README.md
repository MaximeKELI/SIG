<div align="center">

<!-- ═══════════════════ HERO LUXE ANIMÉ ═══════════════════ -->
<img src="docs/assets/readme-hero.svg" width="100%" alt="SIG Sols Togo"/>

<br/>

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0d2818,100:134e2a,50:c9a962&height=140&section=true&text=SIG%20Sols%20Togo&fontSize=38&fontColor=f5e6c8&animation=twinkling&fontAlignY=38&desc=DUSOL%20%C2%B7%20DISIA%20%C2%B7%20R%C3%A9gion%20Maritime&descSize=14&descAlignY=58&descAlign=55&descColor=a7c4b5"/>

<br/>

<img src="https://img.shields.io/badge/Édition-SIG--SOLS--2026--01-0d2818?style=for-the-badge&labelColor=c9a962&color=f5e6c8"/>
<img src="https://img.shields.io/badge/Statut-Production_ready-2d8a52?style=for-the-badge&labelColor=061a12&color=86efac"/>
<img src="https://img.shields.io/badge/Stack-Full--GIS-1a3d2e?style=for-the-badge&labelColor=8b6914&color=fff8e7"/>

<br/>

<img src="https://img.shields.io/badge/Python-3.11-3776AB?style=flat-square&logo=python&logoColor=white"/>
<img src="https://img.shields.io/badge/Django-GeoDjango-092e20?style=flat-square&logo=django&logoColor=white"/>
<img src="https://img.shields.io/badge/PostGIS-15-4169E1?style=flat-square&logo=postgresql&logoColor=white"/>
<img src="https://img.shields.io/badge/Redis-7-DC382D?style=flat-square&logo=redis&logoColor=white"/>
<img src="https://img.shields.io/badge/Leaflet-1.9-199900?style=flat-square&logo=leaflet&logoColor=white"/>
<img src="https://img.shields.io/badge/Docker-Compose-2496ED?style=flat-square&logo=docker&logoColor=white"/>
<img src="https://img.shields.io/badge/Celery-async-37814A?style=flat-square&logo=celery&logoColor=white"/>
<img src="https://img.shields.io/badge/Licence-MIT-c9a962?style=flat-square"/>

<br/><br/>

### ✦ ✦ ✦ Système d'Information Géographique intelligent des sols ✦ ✦ ✦

<sub><i>Cartographie temps réel · NASA · Sentinel-2 · OpenWeather · IA · Éducation · Communauté</i></sub>

<br/>

**Maître d'ouvrage** — DISIA · Ministère de l'Agriculture (République Togolaise)  
**Maître d'œuvre** — **DUSOL**

<br/>

<!-- Texte défilant luxe 1 -->
<img src="https://readme-typing-svg.demolab.com?font=Cormorant+Garamond&weight=700&size=24&duration=2800&pause=800&color=C9A962&center=true&vCenter=true&width=750&lines=Carte+PostGIS+interactive;Parcelles+%26+NDVI+Sentinel-2;M%C3%A9t%C3%A9o+OpenWeather+live;Quiz+p%C3%A9dagogique+%2B+certificats;IA+fertilit%C3%A9+%26+vuln%C3%A9rabilit%C3%A9" alt="typing"/>

<br/>

<!-- Texte défilant 2 — style néon vert -->
<img src="https://readme-typing-svg.demolab.com?font=Outfit&weight=500&size=16&duration=2200&pause=600&color=4ADE80&center=true&vCenter=true&width=650&lines=Animations+luxury+UI;WebSocket+GPS+agents;Vid%C3%A9os+%26+mod%C3%A9ration;Assistant+Gemini+int%C3%A9gr%C3%A9;Export+GeoJSON+%2F+PDF" alt="typing2"/>

<br/>

<img src="docs/assets/readme-divider.svg" width="85%" alt=""/>

<br/>

<table>
<tr>
<td align="center" width="33%">
<img src="docs/assets/readme-orbit.svg" width="120" alt=""/>
<br/><b>165+</b><br/><sub>points sol</sub>
</td>
<td align="center" width="33%">
<img src="https://img.shields.io/badge/Zones-cantons_%26_d%C3%A9grad%C3%A9es-2d8a52?style=for-the-badge&labelColor=0d2818&color=86efac"/><br/><br/>
<b>15+</b> fiches · <b>100+</b> quiz
</td>
<td align="center" width="33%">
<img src="https://img.shields.io/badge/API-REST_v1-1a3d2e?style=for-the-badge&labelColor=c9a962&color=0d2818"/><br/><br/>
<b>20+</b> endpoints
</td>
</tr>
</table>

</div>

---

<!-- TOC -->
<details open>
<summary><b>📑 Table des matières</b></summary>

| | |
|---|---|
| [🚀 Démarrage](#-démarrage-express) | [✨ Fonctionnalités](#-fonctionnalités-phares) |
| [🎬 Expérience UI](#-expérience-interface--animations) | [🏗️ Architecture](#️-architecture) |
| [📦 Modules](#-modules-backend) | [🔌 API](#-api--exemples) |
| [🛰️ Config `.env`](#️-configuration-env) | [📚 Documentation](#-documentation) |
| [📋 Livrables TdR](#-livrables-tdr-v30) | |

</details>

<img src="docs/assets/readme-divider.svg" width="100%" alt=""/>

---

<img src="https://capsule-render.vercel.app/api?type=soft&height=55&section=true&text=%F0%9F%9A%80%20D%C3%A9marrage%20express&fontSize=22&fontColor=f5e6c8&color=0:0d2818,100:1a3d2e&animation=scaleIn" width="100%"/>

## 🚀 Démarrage express

```bash
git clone <repo>
cd DUSOL_PROJET
cp .env.example .env
# Clés : OPENWEATHER_API_KEY · SENTINEL_HUB_* · NASA_EARTHDATA_* · GEMINI_API_KEY
docker compose up -d --build
```

| 🌐 Service | 🔗 URL |
|:----------:|:------|
| **Application** | http://localhost:8081 |
| **API REST** | http://localhost:8081/api/v1/ |
| **Admin** | http://localhost:8081/admin/ |
| **Health** | http://localhost:8081/health/ |
| **App mobile Flutter** | `mobile/` → même API `/api/v1/` |

### 📱 Application mobile (Flutter)

```bash
cd mobile && flutter pub get
flutter run -d linux                    # PC Linux
flutter run -d android                  # Émulateur Android
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8081/api/v1  # Téléphone réel
```

Modules : carte, dashboard, parcelle, quiz, fiches, vidéos, shorts, communauté, assistant IA — voir [`mobile/README.md`](mobile/README.md).

<details>
<summary><b>🔐 Comptes démonstration</b> — <code>make seed</code></summary>

| 👤 Utilisateur | 🔑 Mot de passe | 🎭 Rôle |
|:-------------|:----------------|:--------|
| `admin` | `admin123` | Administrateur |
| `agent1` | `agent123` | Agent terrain |
| `public1` | `public123` | Citoyen / public |

</details>

```bash
make seed                    # Jeu de données complet
make train-ml                # Modèle fertilité
make test                    # Pytest
./scripts/fix-docker-web.sh  # Réparer nginx ↔ OpenWeather 404
./scripts/reload-sentinel.sh # Recharger clés Sentinel Hub
```

<img src="docs/assets/readme-divider.svg" width="100%" alt=""/>

---

<img src="https://capsule-render.vercel.app/api?type=venom&height=55&section=true&text=%E2%9C%A8%20Fonctionnalit%C3%A9s%20phares&fontSize=22&fontColor=e8ffe8&color=0:134e2a,100:0d2818&animation=fadeIn" width="100%"/>

## ✨ Fonctionnalités phares

<table>
<tr>
<td width="50%" valign="top" align="center">

### 🗺️ Carte & spatial

<img src="https://img.shields.io/badge/Leaflet-heatmap-199900?style=for-the-badge"/>

- Points sol colorés (pH, type, validation)
- **Parcelles** cantons & zones dégradées
- Heatmap, proximité, buffer, intersection
- **Analyse parcelle** : NASA + Sentinel + météo
- Dessin polygone · export JSON / GeoJSON
- Badge météo & NDVI sur la carte

</td>
<td width="50%" valign="top" align="center">

### 🛰️ Données satellite & météo

<img src="https://img.shields.io/badge/Sentinel--2-NDVI-0f766e?style=for-the-badge"/>
<img src="https://img.shields.io/badge/OpenWeather-live-1d4ed8?style=for-the-badge"/>

- **NASA Earthdata** MODIS · SMAP · STAC
- **Sentinel Hub** tuiles NDVI & true color
- **OpenWeather** actuel + prévisions parcelle
- Ingestion Celery · cache Redis
- Sonde NDVI au clic · couches opacité

</td>
</tr>
<tr>
<td valign="top" align="center">

### 🎓 Éducation & communauté

<img src="https://img.shields.io/badge/Quiz-100%2B-QCM-c9a962?style=for-the-badge"/>

- Quiz multi-niveaux · mode examen
- Badges · classement · certificats **PDF**
- **15 fiches** pédagogiques (style article)
- Vidéos · shorts · stories · DM
- Hashtags · profils · modération

</td>
<td valign="top" align="center">

### 🤖 Intelligence artificielle

<img src="https://img.shields.io/badge/ML-RandomForest-8b5cf6?style=for-the-badge"/>
<img src="https://img.shields.io/badge/Gemini-assistant-4285F4?style=for-the-badge"/>

- Prédiction **fertilité** (RF / XGBoost)
- Score vulnérabilité & santé sol
- Recommandations agronomiques
- **Assistant chat** contextuel (Gemini)
- Modération vidéos assistée

</td>
</tr>
</table>

<img src="docs/assets/readme-divider.svg" width="100%" alt=""/>

---

<img src="https://capsule-render.vercel.app/api?type=cylinder&height=55&section=true&text=%F0%9F%8E%AC%20Exp%C3%A9rience%20interface&fontSize=20&fontColor=f5e6c8&color=0:1a1a2e,100:0d2818&animation=blinking" width="100%"/>

## 🎬 Expérience interface & animations

> Interface **luxe anime-inspired** — émeraude profond & or champagne, micro-interactions fluides.

| Fichier CSS/JS | Effet visuel |
|----------------|--------------|
| [`style.css`](frontend/css/style.css) | Typo **Cormorant** + **Outfit**, thème clair/sombre |
| [`animations.css`](frontend/css/animations.css) | `fadeUp` · `shimmer` · `navGlow` · `floatSoft` · stagger |
| [`enhancements.css`](frontend/css/enhancements.css) | Carte · parcelles · cartes Sentinel/météo |
| [`sentinelMap.js`](frontend/js/sentinelMap.js) | Couches tuiles · sonde NDVI |
| [`weatherMap.js`](frontend/js/weatherMap.js) | Popup météo · badge live · ☁ contrôle |

<details>
<summary><b>🎞️ Liste des animations clés (frontend)</b></summary>

| Animation | Où ? |
|-----------|------|
| Entrée des vues (`fadeUp` + stagger) | Navigation Carte / Dashboard / Quiz |
| Skeleton chargement parcelle | Panneau live |
| Pulsation bouton nav actif | `navGlow` |
| Toast slide-in | Notifications |
| Heatmap & clusters | Carte Leaflet |
| Badge météo / Sentinel | Coin carte |
| Cartes externes parcelle | Rapport + dashboard |
| Onboarding tour | Première visite |

</details>

<img src="https://readme-typing-svg.demolab.com?font=Segoe+UI&weight=600&size=14&duration=3000&pause=500&color=E8D5A3&center=true&width=600&lines=Th%C3%A8me+sombre+%26+clair;Transitions+0.35s+cubic-bezier;Parcelles+anim%C3%A9es+au+clic" alt="ui"/>

<img src="docs/assets/readme-divider.svg" width="100%" alt=""/>

---

<img src="https://capsule-render.vercel.app/api?type=wave&height=55&section=true&text=%F0%9F%8F%97%EF%B8%8F%20Architecture&fontSize=20&fontColor=86efac&color=0:061a12,100:2d8a52" width="100%"/>

## 🏗️ Architecture

```mermaid
flowchart TB
    subgraph Client["🌐 Navigateur PWA"]
        L[Leaflet + Draw]
        A[animations.css]
        P[parcel · sentinel · weather]
    end
    subgraph Edge["⚡ NGINX :8081"]
        N[Reverse proxy + cache static]
    end
    subgraph App["🐍 Django / Daphne"]
        D[DRF API v1]
        W[Channels WebSocket]
        C[Celery workers]
    end
    subgraph Data["💾 Données"]
        PG[(PostGIS 15)]
        R[(Redis 7)]
    end
    subgraph External["🛰️ APIs externes"]
        NASA[NASA Earthdata]
        SH[Sentinel Hub]
        OW[OpenWeather]
        GM[Gemini]
    end
    Client --> N --> App
    App --> PG
    App --> R
    App --> NASA
    App --> SH
    App --> OW
    App --> GM
```

```
┌──────────────────────────────────────────────────────────────────┐
│  🎨 Frontend · Leaflet · PWA · modules ES (carte, dashboard…)     │
└─────────────────────────────┬────────────────────────────────────┘
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  🔶 NGINX  ──►  Django 4  +  DRF  +  Daphne  +  Channels          │
│                 Celery Beat  +  Celery Worker                      │
└───────┬──────────────────────────────┬───────────────────────────┘
        ▼                              ▼
   🐘 PostGIS                      ⚡ Redis
```

<img src="docs/assets/readme-divider.svg" width="100%" alt=""/>

---

<img src="https://capsule-render.vercel.app/api?type=slicing&height=50&section=true&text=%F0%9F%93%A6%20Modules&fontSize=20&fontColor=c9a962&color=0:2d1f0f,100:4a3812" width="100%"/>

## 📦 Modules backend

| 📁 App | 🎯 Rôle |
|:-------|:--------|
| `accounts` | JWT · rôles · profils · GPS live · social · DM |
| `soils` | Points sol · zones admin · dashboard KPI |
| `spatial` | Parcelles · proximité · buffer · vulnérabilité · NDVI |
| `nasa` | Catalogue STAC · ingestion MODIS/SMAP |
| `sentinel` | OAuth · tuiles · analyse NDVI bbox |
| `weather` | OpenWeather actuel & prévisions |
| `ml_predict` | Fertilité ML · métriques · Celery train |
| `education` | Quiz · fiches PDF · parcours · défis |
| `videos` | Upload · likes · modération admin |
| `assistant` | Chat Gemini · contexte parcelle/NASA |
| `sig_platform` | Alertes · exports ministère · analytics |

<img src="docs/assets/readme-divider.svg" width="100%" alt=""/>

---

<img src="https://capsule-render.vercel.app/api?type=transparent&height=50&section=true&text=%F0%9F%94%8C%20API&fontSize=20&fontColor=4ade80&fontAlignY=75" width="100%"/>

## 🔌 API — exemples

📖 [`docs/API.md`](docs/API.md) · 📮 [`Postman`](docs/postman/SIG-SOLS.postman_collection.json) · 🌍 [`API externes`](docs/API_EXTERNES.md)

```bash
# ─── Auth ───
curl -s -X POST http://localhost:8081/api/v1/auth/token/ \
  -H "Content-Type: application/json" \
  -d '{"username":"agent1","password":"agent123"}'

# ─── OpenWeather ───
curl -s http://localhost:8081/api/v1/weather/status/
curl -s "http://localhost:8081/api/v1/weather/current/?lat=6.4&lon=1.35"

# ─── Sentinel Hub ───
curl -s http://localhost:8081/api/v1/sentinel/status/
curl -s http://localhost:8081/api/v1/sentinel/layers/

# ─── Parcelle (Sentinel + météo) ───
curl -s -X POST http://localhost:8081/api/v1/spatial/parcel/live/ \
  -H "Content-Type: application/json" \
  -d '{"zone_code":"CANTON-M01","use_sentinel":true,"use_weather":true,"use_ml":false}'

# ─── IA fertilité ───
curl -s -X POST http://localhost:8081/api/v1/ml/predict/ \
  -H "Content-Type: application/json" \
  -d '{"ph":6.2,"humidity_pct":35,"soil_type":"limoneux"}'
```

<details>
<summary><b>📡 Endpoints météo & Sentinel (liste)</b></summary>

| Méthode | Route |
|---------|-------|
| GET | `/api/v1/weather/status/` |
| GET | `/api/v1/weather/current/?lat=&lon=` |
| GET | `/api/v1/weather/forecast/?lat=&lon=` |
| GET | `/api/v1/sentinel/status/` |
| GET | `/api/v1/sentinel/layers/` |
| POST | `/api/v1/sentinel/analyze/` |
| GET | `/api/v1/sentinel/tiles/{layer}/{z}/{x}/{y}.png` |
| POST | `/api/v1/spatial/parcel/live/` |
| POST | `/api/v1/spatial/parcel/analyze/` |

</details>

<img src="docs/assets/readme-divider.svg" width="100%" alt=""/>

---

<img src="https://capsule-render.vercel.app/api?type=soft&height=50&section=true&text=%F0%9F%9B%B0%EF%B8%8F%20Configuration&fontSize=20&fontColor=f5e6c8&color=0:0d2818,100:134e2a" width="100%"/>

## 🛰️ Configuration `.env`

```bash
# ── OpenWeather ── https://openweathermap.org/api
OPENWEATHER_API_KEY=
OPENWEATHER_CACHE_SECONDS=600

# ── Sentinel Hub ── https://apps.sentinel-hub.com/
SENTINEL_HUB_CLIENT_ID=
SENTINEL_HUB_CLIENT_SECRET=

# ── NASA Earthdata ──
NASA_EARTHDATA_TOKEN=

# ── Assistant IA ──
GEMINI_API_KEY=
GEMINI_MODEL=gemini-2.5-flash-lite
```

➡️ Modèle complet : [`.env.example`](.env.example)

<img src="docs/assets/readme-divider.svg" width="100%" alt=""/>

---

## 📚 Documentation

| 📄 Document | 📌 Contenu |
|:-----------|:---------|
| [Guide utilisateur](docs/GUIDE_UTILISATEUR.md) | Prise en main complète |
| [Utilisateur (court)](docs/UTILISATEUR.md) | Aide rapide |
| [API externes](docs/API_EXTERNES.md) | NASA · Sentinel · OpenWeather · OSM |
| [NASA setup](docs/NASA_SETUP.md) | Ingestion Earthdata |
| [L1 Spécifications](docs/L1_SPECIFICATIONS.md) | Cahier des charges |
| [L2 Modèle données](docs/L2_MODELE_DONNEES.md) | Schéma PostGIS |

<img src="docs/assets/readme-divider.svg" width="100%" alt=""/>

---

## 📋 Livrables TdR v3.0

| Code | Livrable | 📎 |
|:----:|:---------|:---|
| **L1** | Spécifications | `docs/L1_SPECIFICATIONS.md` |
| **L2** | Modèle de données | `docs/L2_MODELE_DONNEES.md` |
| **L3** | API REST | OpenAPI + Postman |
| **L4** | Jeu de test | `seed_demo_data` |
| **L5** | Module IA | `apps/ml_predict/` |
| **L6** | Code source | Ce dépôt |
| **L7** | Guide utilisateur | `docs/GUIDE_UTILISATEUR.md` |
| **L8** | Déploiement | Docker + nginx |

---

<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0d2818,100:2d8a52,50:c9a962&height=100&section=true&text=SIG%20Sols%20Togo&fontSize=32&fontColor=f5e6c8&animation=twinkling"/>

<br/>

<img src="https://readme-typing-svg.demolab.com?font=Cormorant+Garamond&weight=700&size=18&duration=4000&pause=1000&color=4ADE80&center=true&width=500&lines=Intelligence+des+sols;Pour+l%27agriculture+togolaise;DUSOL+%C2%B7+DISIA+2026" alt="footer"/>

<br/>

<img src="https://img.shields.io/badge/Made_with-♥_DUSOL-c9a962?style=for-the-badge&labelColor=0d2818&color=2d8a52"/>
<img src="https://img.shields.io/badge/Togo-🇹🇬-1a3d2e?style=for-the-badge&labelColor=8b6914&color=f5e6c8"/>

<br/>

<sub><b>MIT License</b> · Données terrain © DISIA · Données NASA domaine public · Crédits requis</sub>

<br/>

**⭐ Si ce projet vous aide, laissez une étoile sur le dépôt ⭐**

</div>












































































































































