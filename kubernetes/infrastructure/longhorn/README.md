# Longhorn

Stand: 02.10.2026, Longhorn v1.11.3, Installation per Herstellermanifest longhorn.yaml über die Application `infrastructure`.

## Lokale Anpassungen am Herstellermanifest longhorn.yaml

Bei jedem Longhorn-Update (neues longhorn.yaml) müssen diese Änderungen erneut eingetragen werden:

| Stelle | Änderung | Grund |
|---|---|---|
| ConfigMap longhorn-default-setting | storage-minimal-available-percentage "10", concurrent-replica-rebuild-per-node-limit "1" | Stabilität bei Rebuilds (docs/LESSONS_LEARNED.md, 21.07.2026) |
| ConfigMap longhorn-default-setting | concurrent-automatic-engine-upgrade-per-node-limit "1" | Volume-Engines nach Longhorn-Upgrade automatisch im laufenden Betrieb aktualisieren, je Node eine gleichzeitig (02.10.2026) |
| ConfigMap longhorn-default-resource | backup-target cifs://192.168.1.15/LonghornBackup, Secret cifs-secret, Intervall 300 | Backup-Ziel (docs/BACKUP_RESTORE.md) |
| ConfigMap longhorn-storageclass | is-default-class "false" | Einziger Default ist longhorn-fast (storageclass-fast.yaml) |

Weitere Dateien in diesem Ordner: storageclass-fast.yaml, recurring-jobs.yaml (Snapshots, Backups, Bereinigung), cifs-externalsecret.yaml (Zugang Backup-Ziel aus 1Password).

## Upgrade

Nur eine Minor-Version je Stufe (z. B. 1.11 auf 1.12). Übersprungene Minor-Versionen lehnt longhorn-manager selbst ab.

1. Release Notes der Zielversion lesen (Abschnitte Important, Upgrade, Breaking Changes): Kubernetes-Mindestversion, Hotfix-Hinweise, Abkündigungen. Hinweise zur V2 Data Engine betreffen uns nicht, alle Volumes sind V1.
2. Lokale Anpassungen per diff (Vergleich) gegen das Original der installierten Version prüfen. Ergebnis muss genau der Tabelle oben entsprechen:

```bash
ALT=1.11.3
curl -fsSLo /tmp/longhorn-$ALT.yaml https://raw.githubusercontent.com/longhorn/longhorn/v$ALT/deploy/longhorn.yaml
diff /tmp/longhorn-$ALT.yaml kubernetes/infrastructure/longhorn/longhorn.yaml
```

3. Herstellermanifest der Zielversion holen, die Anpassungen eintragen, als longhorn.yaml speichern. Kontrolle:

```bash
NEU=1.12.1
curl -fsSLo /tmp/longhorn-$NEU.yaml https://raw.githubusercontent.com/longhorn/longhorn/v$NEU/deploy/longhorn.yaml
# Anpassungen eintragen, dann:
diff /tmp/longhorn-$NEU.yaml kubernetes/infrastructure/longhorn/longhorn.yaml   # nur die Anpassungen
kubectl kustomize kubernetes/infrastructure >/dev/null && echo OK
grep -c "v$ALT" kubernetes/infrastructure/longhorn/longhorn.yaml                # muss 0 sein
```

4. Frisches Backup aller Volumes. Jobname ohne Punkte (DNS-Label, sonst Warnung):

```bash
kubectl -n longhorn-system create job --from=cronjob/daily-backup-all backup-vor-longhorn-1-12
kubectl -n longhorn-system get backups.longhorn.io --sort-by=.metadata.creationTimestamp
```

Erst weiter, wenn für jedes Volume ein neues Backup `Completed` ist.

5. Version in README.md (Abschnitt Plattform) nachziehen, committen, pushen. ArgoCD rollt longhorn-manager (DaemonSet), CSI-Sidecars (CSI = Container Storage Interface, Schnittstelle zwischen Kubernetes und Storage) und UI aus. Die Volumes bleiben dabei attached.
6. Engines: Longhorn stellt sie wegen concurrent-automatic-engine-upgrade-per-node-limit "1" selbst um (Live-Upgrade, im laufenden Betrieb). Kontrolle, bis alle auf der neuen Version stehen:

```bash
kubectl -n longhorn-system get volumes.longhorn.io -o custom-columns=NAME:.metadata.name,ROBUST:.status.robustness,ENGINE:.status.currentImage
```

7. Alte instance-manager (Longhorn-Pod je Node, in dem die Engine- und Replica-Prozesse laufen) abbauen. Sie bleiben stehen, bis jedes ihrer Volumes einmal detached war:

```bash
kubectl -n longhorn-system get instancemanagers.longhorn.io -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeID,IMAGE:.spec.image
```

`rollout restart` auf demselben Node reicht nicht, Kubernetes übergibt das Volume direkt an den neuen Pod. Workload auf 0 skalieren, warten bis das Volume `detached` ist, wieder hochskalieren. Danach verschwindet auch das alte Engine-Image (`kubectl -n longhorn-system get engineimages.longhorn.io`).

8. Vor der nächsten Stufe einige Tage beobachten: nächtliche Backups, Restarts in longhorn-system, RAM auf rpi4.

## Verlauf

| Datum | Von | Nach | Weg |
|---|---|---|---|
| 02.10.2026 | v1.10.1 | v1.11.3 | Manifest über Git und ArgoCD, Engines live umgestellt. Alter instance-manager v1.10.1 auf rpi5 läuft noch (Jellyfin, Grafana, Prometheus), Abbau vor 1.12 |
