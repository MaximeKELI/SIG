# Tests SIG-SOLS-TOGO-2026-01

## Backend (Django / GeoDjango)

```bash
make test
# 45+ tests, couverture ≥ 77 %
```

| Module | Fichier | Contenu |
|--------|---------|---------|
| accounts | `test_auth.py` | JWT, inscription, rôles |
| soils | `test_soils.py` | pH, validateurs, API, CSV |
| spatial | `test_spatial.py` | Proximité, buffer, intersection |
| nasa | `test_nasa.py` | Ingestion, STAC, catalogue |
| ml_predict | `test_ml.py` | Entraînement, prédiction API |
| education | `test_education.py` | Quiz, badges |
| intégration | `apps/tests/test_integration.py` | Parcours complets |
| **E2E agent** | `apps/tests/test_agent_field_e2e.py` | Création → pending → validate/reject → carte `is_validated` |

## Frontend (JavaScript)

Modules testables : `frontend/js/core/`

```bash
make test-frontend
# ou
cd frontend && node --test tests/*.test.js
```

| Fichier | Contenu |
|---------|---------|
| `phColor.test.js` | Codage couleur pH TdR |
| `apiClient.test.js` | Client REST, JWT, erreurs |
| `mapUtils.test.js` | Filtres carte, GeoJSON, tuiles NASA |
| `dashboardUtils.test.js` | Format KPIs, R² SMAP |
| `quizUtils.test.js` | Timer 20s, feedback, classement |

## Liaison backend ↔ web ↔ mobile

Vérifie que **tous les endpoints** utilisés par le site et l'app mobile répondent correctement :

```bash
make test-linkage
# ou
./scripts/test-linkage.sh
```

| Étape | Contenu |
|-------|---------|
| 1 | `test_api_linkage.py` — 28+ tests pytest (contrat API complet) |
| 2 | Tests unitaires frontend (Vitest) |
| 3 | Tests unitaires mobile (Flutter) |
| 4 | Tests HTTP live sur `:8081` + intégration Flutter (si Docker actif) |

Si l'étape 4 échoue (timeout), relancez le backend :

```bash
sudo ./scripts/fix-docker-network.sh
```

## Tout lancer

```bash
make test-all
```
