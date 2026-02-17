# Jellyfin Backup

Einfache Backup-Lösung für Jellyfin PVCs → `/mnt/media/backup/jellyfin-backups/`

## Strategie (2 Layer)

| Layer | Lösung | Zweck |
|-------|--------|-------|
| 1 | Longhorn RecurringJob (daily-snapshot-all) | Schneller Cluster-interner Rollback |
| 2 | Diese Lösung (rsync → Backup-HDD) | Vollständige Datensicherung, auch wenn Longhorn kaputt |

## Struktur auf Backup-HDD

```
/mnt/media/backup/jellyfin-backups/
├── 20260117_030012/
│   ├── config/        ← jellyfin-config-nvme PVC
│   ├── cache/         ← jellyfin-cache-nvme PVC
│   └── backup-info.txt
├── 20260124_030015/
└── ...                ← max. 5 Versionen
```

## Deploy (GitOps via ArgoCD)

```bash
# Einmalig deployen (dann ArgoCD übernimmt)
kubectl apply -f rbac.yaml
kubectl apply -f cronjob.yaml
```

Danach läuft automatisch jeden **Sonntag um 03:00 Uhr** ein Backup (~2 Min Downtime).

## Manuelles Pre-Update Backup

**Vor jedem Jellyfin-Update ausführen (auf rpi5):**

```bash
# Backup erstellen
./backup-before-update.sh

# Jellyfin updaten (z.B. image tag in deployment.yaml ändern + git push)
# ArgoCD deployed...

# Falls Update fehlschlägt → Rollback:
./backup-before-update.sh --restore 20260117_030012
```

Das Script:
1. Stoppt Jellyfin
2. Kopiert beide PVCs auf Backup-HDD
3. Startet Jellyfin wieder (auch bei Fehler via trap)

## CronJob manuell auslösen (für Test)

```bash
kubectl create job --from=cronjob/jellyfin-backup jellyfin-backup-manual -n jellyfin

# Logs beobachten
kubectl logs -n jellyfin -l job-name=jellyfin-backup-manual -f
```

## Backup Status prüfen

```bash
# Vorhandene Backups auf rpi5
ls -lh /mnt/media/backup/jellyfin-backups/

# Gesamtgröße
du -sh /mnt/media/backup/jellyfin-backups/

# CronJob Status
kubectl get cronjobs -n jellyfin
kubectl get jobs -n jellyfin
```

## Troubleshooting

**Jellyfin läuft nicht wieder an nach CronJob:**
```bash
# Scale-up CronJob läuft 30 Min nach Backup (03:30)
# Oder manuell:
kubectl scale deployment jellyfin -n jellyfin --replicas=1
```

**Backup-HDD nicht erreichbar:**
```bash
# Mount prüfen
systemctl status mnt-media-backup.mount
# Neu mounten
sudo systemctl start mnt-media-backup.mount
```
