# Backup und Wiederherstellung (Longhorn)

Stand: 29.09.2026, Longhorn v1.10.1

## Ueberblick

| Baustein | Konfiguration | Quelle in Git |
|---|---|---|
| Snapshots | taeglich 02:00, 7 behalten | kubernetes/infrastructure/longhorn/recurring-jobs.yaml |
| Snapshot-Bereinigung | sonntags 04:00 | ebenda |
| Backups | taeglich 01:00, 7 behalten, Volumes nacheinander | ebenda |
| Backup-Ziel | cifs://192.168.1.15/LonghornBackup | kubernetes/infrastructure/longhorn/longhorn.yaml (ConfigMap longhorn-default-resource) |
| Zugangsdaten | Secret cifs-secret im Namespace longhorn-system | NICHT in Git (Repository ist oeffentlich) |
| Samba-Freigabe | [LonghornBackup] auf rpi5, nur Benutzer longhorn-backup | host-config/rpi5/smb.conf |
| Speicherort | USB-Platte am rpi5, /mnt/media/backup/longhorn | host-config/rpi5/mnt-media-backup.mount |

Alle Volumes ohne eigene Job-Zuordnung gehoeren automatisch zur Gruppe default und werden erfasst.
Zeitzone der Knoten: Europe/Berlin.

## Regeln

- Keine Aufraeumskripte oder Aufbewahrungsregeln direkt auf /mnt/media/backup/longhorn. Longhorn verwaltet den Lebenszyklus der Backups selbst.
- Snapshots liegen auf denselben Datentraegern wie die Volumes und ersetzen kein Backup.
- Die Backups liegen am selben Standort. Eine Kopie ausser Haus existiert noch nicht.

## Status pruefen

```bash
kubectl -n longhorn-system get backuptargets.longhorn.io
kubectl -n longhorn-system get recurringjobs.longhorn.io
kubectl -n longhorn-system get backups.longhorn.io -o custom-columns='VOLUME:.status.volumeName,STATE:.status.state,SNAPSHOT:.status.snapshotCreatedAt'
```

Erwartung: BackupTarget AVAILABLE true, drei RecurringJobs, je Volume Backups mit STATE Completed.

## Secret neu anlegen (z.B. nach Cluster-Neuaufbau)

Passwort steht im Passwortmanager (Eintrag Samba longhorn-backup).

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

Erzeugt ein neues Volume aus einem Backup, ohne den laufenden Dienst zu beruehren.
Variablen oben anpassen: Backup-Name aus `kubectl -n longhorn-system get backups.longhorn.io`, Groesse wie Original-PVC.

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

Aufraeumen (am selben Tag, sonst wird das Testvolume nachts mitgesichert):

```bash
kubectl -n default delete pod restore-test-reader
kubectl -n default delete pvc restore-test
kubectl delete storageclass longhorn-restore-test
```

## Wiederherstellung B: Ernstfall am Originalplatz (noch nicht erprobt)

Ablauf, vor echtem Einsatz einmal an einem unkritischen Dienst testen:

1. Automatische Synchronisation pausieren, sonst legt ArgoCD (selfHeal) ein geloeschtes PVC sofort leer neu an. Betroffen: root-app und die Application des Dienstes.
2. Workload auf 0 Replikas skalieren.
3. Longhorn-Oberflaeche oeffnen: `kubectl -n longhorn-system port-forward svc/longhorn-frontend 8080:80`, dann http://localhost:8080.
4. Defektes Volume loeschen, Backup mit bisherigem Volume-Namen wiederherstellen, danach PV und PVC mit bisherigem PVC-Namen anlegen.
5. Workload hochskalieren, Inhalt pruefen.
6. root-app in ArgoCD synchronisieren; damit gilt wieder die Sync-Richtlinie aus Git.

## Testprotokoll

| Datum | Volume | Backup | Ergebnis |
|---|---|---|---|
| 29.09.2026 | mqtt/mosquitto-data (pvc-2ab772d1) | backup-8b5be75fa7054d87 | Erfolgreich, Datei mosquitto.db identisch (Groesse, Zeitstempel, Rechte) |

## Hinweis ab 29.09.2026: Secret ueber External Secrets

Das Secret cifs-secret wird vom External Secrets Operator aus 1Password bereitgestellt
(Tresor Homelab-K3s-ESO, Eintrag samba-longhorn-backup, Definition in
kubernetes/infrastructure/longhorn/cifs-externalsecret.yaml).
Passwortwechsel: zuerst auf dem rpi5 (sudo smbpasswd longhorn-backup), dann in 1Password.
Der Abschnitt "Secret neu anlegen" gilt nur noch als Notfallweg ohne ESO.
