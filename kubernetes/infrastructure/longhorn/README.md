# Longhorn: lokale Anpassungen am Herstellermanifest longhorn.yaml

Bei jedem Longhorn-Update (neues longhorn.yaml) müssen diese Änderungen erneut eingetragen werden:

| Stelle | Änderung | Grund |
|---|---|---|
| ConfigMap longhorn-default-setting | storage-minimal-available-percentage "10", concurrent-replica-rebuild-per-node-limit "1" | Stabilität bei Rebuilds (docs/LESSONS_LEARNED.md, 21.07.2026) |
| ConfigMap longhorn-default-resource | backup-target cifs://192.168.1.15/LonghornBackup, Secret cifs-secret, Intervall 300 | Backup-Ziel (docs/BACKUP_RESTORE.md) |
| ConfigMap longhorn-storageclass | is-default-class "false" | Einziger Default ist longhorn-fast (storageclass-fast.yaml) |

Weitere Dateien in diesem Ordner: storageclass-fast.yaml, recurring-jobs.yaml (Snapshots, Backups, Bereinigung), cifs-externalsecret.yaml (Zugang Backup-Ziel aus 1Password).
