# Sauvegarde & restauration

## Script quotidien

```bash
chmod +x scripts/backup-daily.sh
./scripts/backup-daily.sh
# → backups/sig_sols_YYYYMMDD….dump (+ media_….tar.gz si volume média)
```

Cron (hôte, 02:30 UTC) :

```cron
30 2 * * * cd /opt/sig && BACKUP_DIR=/var/backups/sig ./scripts/backup-daily.sh >> /var/log/sig-backup.log 2>&1
```

Variables optionnelles : `BACKUP_DIR`, `RETENTION_DAYS` (défaut 14), `POSTGRES_USER`, `POSTGRES_DB`.

## Base PostGIS (manuel)

```bash
docker compose exec db pg_dump -U sig_sols sig_sols -Fc -f /tmp/sig_sols.dump
docker cp "$(docker compose ps -q db)":/tmp/sig_sols.dump ./backups/
```

Restauration :

```bash
docker cp ./backups/sig_sols.dump "$(docker compose ps -q db)":/tmp/
docker compose exec db pg_restore -U sig_sols -d sig_sols --clean /tmp/sig_sols.dump
```

## Médias (vidéos, photos)

Volume Docker `media_data` (géré aussi par `backup-daily.sh`) :

```bash
VOL=$(docker compose volume ls -q | grep media_data | head -1)
docker run --rm -v "$VOL":/data -v $(pwd)/backups:/backup alpine \
  tar czf /backup/media.tar.gz -C /data .
```

## Fréquence recommandée

- Base : quotidien (`backup-daily.sh`)
- Médias : inclus dans le script (ou hebdomadaire si volume volumineux)
- Tester une restauration sur staging chaque mois
- Secrets (`.env`) : sauvegarde chiffrée séparée (jamais dans le dump public)
