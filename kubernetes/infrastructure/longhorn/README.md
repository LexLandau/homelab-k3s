# Longhorn: lokale Anpassungen am Herstellermanifest longhorn.yaml

Bei jedem Longhorn-Update (neues longhorn.yaml) muessen diese Aenderungen erneut eingetragen werden:

| Stelle | Aenderung | Grund |
|---|---|---|
| ConfigMap longhorn-default-resource | backup-target cifs://192.168.1.15/LonghornBackup, Secret cifs-secret, Intervall 300 | Backup-Ziel (siehe docs/BACKUP_RESTORE.md) |
| ConfigMap longhorn-storageclass | is-default-class "false" | Einziger Default ist longhorn-fast (storageclass-fast.yaml) |
