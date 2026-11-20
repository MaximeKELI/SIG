# Publication Play Store — SIG Sols Togo

## Prérequis

1. Domaine HTTPS en ligne (`./scripts/deploy-prod.sh`)
2. Keystore : `mobile/android/upload-keystore.jks` (déjà généré, hors git)
3. AAB : `./mobile/scripts/build_play_aab.sh` → `partage/play/*.aab`
4. Assets : `mobile/store/` (feature graphic + icône)

## Data Safety (réponses types)

| Donnée | Collectée | Partagée | Obligatoire | Finalité |
|--------|-----------|----------|-------------|----------|
| Localisation précise | Oui (GPS carte / parcelle) | Non | Non (runtime) | Fonction app |
| Photos / vidéos | Oui (profil, upload) | Non | Non | Fonction app |
| Identifiants compte | Oui | Non | Oui | Compte |
| Activité dans l’app | Oui si consentement | Non | Non | Analytics |
| Fichiers audio | Oui (permission micro si upload vidéo) | Non | Non | Fonction app |

- Chiffrement en transit : **Oui** (HTTPS)
- Les utilisateurs peuvent demander la suppression : **Oui** (contact `sig-sols@disia.tg`)
- Politique : `https://VOTRE-DOMAINE/privacy.html`

## Déclaration permissions

- `ACCESS_FINE_LOCATION` / `COARSE` — carte et parcelles
- `FOREGROUND_SERVICE_LOCATION` — suivi GPS via Geolocator
- `CAMERA` / `RECORD_AUDIO` / médias — contenus utilisateur
- Pas de pub / pas d’ID pub Google

## Checklist Console

- [ ] Créer l’application (package `tg.dusol.sig_sols_mobile`)
- [ ] Uploader la clé d’upload (1ère fois) / AAB signé
- [ ] Fiche Store FR : titre, description courte/longue
- [ ] Feature graphic + icône 512 + ≥2 captures
- [ ] Classification du contenu / public cible
- [ ] Data Safety + lien privacy HTTPS
- [ ] Piste de test interne → production
