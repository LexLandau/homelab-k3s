# Backup und Wiederherstellung (Longhorn)

Stand: 29.09.2026, Longhorn v1.10.1

## Überblick

| Baustein | Konfiguration | Quelle in Git |
|---|---|---|
| Backups | täglich 01:00, 7 behalten, Volumes nacheinander | kubernetes/infrastructure/longhorn/recurring-jobs.yaml |
| Snapshots | täglich 02:00, 7 behalten | ebenda |
| Snapshot-Bereinigung | sonntags 04:00 | ebenda |
| Backup-Ziel | cifs://192.168.1.15/LonghornBackup | kubernetes/infrastructure/longhorn/longhorn.yaml (ConfigMap longhorn-default-resource) |
| Zugangsdaten | Secret cifs-secret (longhorn-system), per ExternalSecret aus 1Password, Eintrag samba-longhorn-backup | kubernetes/infrastructure/longhorn/cifs-externalsecret.yaml |
| Samba-Freigabe | [LonghornBackup] auf rpi5, nur Benutzer longhorn-backup | host-config/rpi5/smb.conf |
| Speicherort | USB-HDD am rpi5, /mnt/media/backup/longhorn | host-config/rpi5/mnt-media-backup.mount |

Volumes ohne eigene Job-Zuordnung gehören automatisch zur Gruppe default und werden erfasst. Zeitzone der Knoten: Europe/Berlin.

## Regeln

- Keine Aufräumskripte oder Aufbewahrungsregeln direkt auf /mnt/media/backup/longhorn; Longhorn verwaltet die Backups selbst.
- Snapshots liegen auf denselben Datenträgern wie die Volumes und ersetzen kein Backup.
- Backups liegen am selben Standort; eine Kopie außer Haus fehlt noch.

## Passwortwechsel Samba-Benutzer

1. Auf rpi5: `sudo smbpasswd longhorn-backup`
2. Neues Passwort in 1Password (Eintrag samba-longhorn-backup) eintragen.
3. Sofort abgleichen: `kubectl -n longhorn-system annotate externalsecrets.external-secrets.io cifs-secret force-sync="$(date +%s)" --overwrite`
4. Nach spätestens 5 Minuten prüfen: BackupTarget `AVAILABLE true`.

## Status prüfen

```bash
kubectl -n longhorn-system get backuptargets.longhorn.io
kubectl -n longhorn-system get recurringjobs.longhorn.io
kubectl -n longhorn-system get backups.longhorn.io -o custom-columns='VOLUME:.status.volumeName,STATE:.status.state,SNAPSHOT:.status.snapshotCreatedAt'
```

Erwartung: BackupTarget AVAILABLE true, drei RecurringJobs, je Volume Backups mit STATE Completed.

## Notfall: Secret ohne ESO anlegen

Nur wenn der External Secrets Operator nicht verfügbar ist. Passwort aus 1Password (samba-longhorn-backup).

```bash
read -r -s -p "Samba-Passwort fuer longhorn-backup: " CIFSPW; echo
kubectl -n longhorn-system create secret generic cifs-secret --from-literal=CIFS_USERNAME=longhorn-backup --from-literal=CIFS_PASSWORD="$CIFSPW"
unset CIFSPW
```

## Manuelles Backup aller Volumes

```bash
kubectl -n longhorn-system create job --from=cronjob/daily-backup-all backup-manuell-$(date +%Y%m%d%H%M)
```

## Wiederherstellung A: Test als separates Volume (erprobt)

Erzeugt ein neues Volume aus einem Backup, ohne den laufenden Dienst zu berühren.
Variablen oben anpassen (Beispielwerte vom Test am 29.09.2026): Backup-Name aus `kubectl -n longhorn-system get backups.longhorn.io`, Größe wie Original-PVC.

```bash
BACKUP=backup-8b5be75fa7054d87
GROESSE=2Gi
BURL=$(kubectl -n longhorn-system get backups.longhorn.io "$BACKUP" -o jsonpath='{.status.url}')
kubectl apply -f - <<YAML
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-restore-test
provisioner: driver.longhorn.io
reclaimPolicy: Delete
volumeBindingMode: Immediate
parameters:
  numberOfReplicas: "1"
  staleReplicaTimeout: "30"
  fsType: "ext4"
  dataEngine: "v1"
  fromBackup: "$BURL"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restore-test
  namespace: default
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: longhorn-restore-test
  resources:
    requests:
      storage: $GROESSE
---
apiVersion: v1
kind: Pod
metadata:
  name: restore-test-reader
  namespace: default
spec:
  restartPolicy: Never
  containers:
  - name: reader
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: restored
      mountPath: /restore
      readOnly: true
  volumes:
  - name: restored
    persistentVolumeClaim:
      claimName: restore-test
YAML
kubectl -n default wait --for=condition=Ready pod/restore-test-reader --timeout=15m
kubectl -n default exec restore-test-reader -- sh -c 'cd /restore && find . -type f -exec ls -l {} \; | sort -k9'
```

Aufräumen (am selben Tag, sonst wird das Testvolume nachts mitgesichert):

```bash
kubectl -n default delete pod restore-test-reader
kubectl -n default delete pvc restore-test
kubectl delete storageclass longhorn-restore-test
```

## Wiederherstellung B: Ernstfall am Originalplatz (noch nicht erprobt)

Ablauf, vor echtem Einsatz einmal an einem unkritischen Dienst testen:

1. Automatische Synchronisation pausieren, sonst legt ArgoCD (selfHeal) ein gelöschtes PVC sofort leer neu an. Betroffen: root-app und die Application des Dienstes.
2. Workload auf 0 Replikas skalieren.
3. Longhorn-Oberfläche öffnen: `kubectl -n longhorn-system port-forward svc/longhorn-frontend 8081:80`, dann http://localhost:8081.
4. Defektes Volume löschen, Backup mit bisherigem Volume-Namen wiederherstellen, danach PV und PVC mit bisherigem PVC-Namen anlegen.
5. Workload hochskalieren, Inhalt prüfen.
6. root-app in ArgoCD synchronisieren; damit gilt wieder die Sync-Richtlinie aus Git.

## Testprotokoll

| Datum | Volume | Backup | Ergebnis |
|---|---|---|---|
| 29.09.2026 | mqtt/mosquitto-data (pvc-2ab772d1) | backup-8b5be75fa7054d87 | Wiederherstellung erfolgreich, mosquitto.db identisch (Größe, Zeitstempel, Rechte) |
| 29.09.2026 | alle 10 Volumes | Job backup-test-eso | Backup erfolgreich mit Zugangsdaten aus 1Password (ESO), inkrementell rund 2 Minuten |
