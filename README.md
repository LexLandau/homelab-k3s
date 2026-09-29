# K3s Homelab Cluster

3-Knoten-Kubernetes-Cluster (k3s) auf Raspberry Pi. Betrieb vollständig per GitOps: Dieses Repository ist die Quelle der Wahrheit (Single Source of Truth), Argo CD gleicht den Cluster automatisch ab.

Stand: 29.09.2026

## Hardware

| Knoten | IP | RAM | Speicher | Besonderheit |
|---|---|---|---|---|
| rpi5 | 192.168.1.10 | 8 GB | NVMe | Zusätzlich eth1 192.168.1.15 (2,5 GbE, SMB), USB-HDDs |
| rpi4-cm4 | 192.168.1.11 | 4 GB | NVMe | |
| rpi4 | 192.168.1.12 | 4 GB | SSD | Keine Longhorn-Replikas (Entscheidung 21.07.2026, siehe docs/LESSONS_LEARNED.md) |

Alle Knoten sind Control Plane, etcd und Worker zugleich (Embedded etcd, HA). Debian 13, arm64.

## Plattform

| Komponente | Version | Quelle in Git |
|---|---|---|
| k3s | v1.35.6+k3s1 | kubernetes/apps/system-upgrade/plan.yaml |
| Argo CD | v3.5.3 (selbstverwaltet) | kubernetes/argocd/install |
| Longhorn | v1.10.1 | kubernetes/infrastructure/longhorn |
| MetalLB | v0.15.3 (L2) | kubernetes/infrastructure/metallb |
| system-upgrade-controller | v0.18.0 | kubernetes/infrastructure/system-upgrade-controller |
| External Secrets Operator | Chart 2.11.0 | kubernetes/argocd/applications/external-secrets.yaml |
| kube-prometheus-stack | Chart 91.8.1 (Prometheus 3.15, Grafana 13.2) | kubernetes/argocd/applications/monitoring-helm.yaml |

k3s-Komponenten deaktiviert: servicelb, traefik, local-storage (host-config/k3s).

## Dienste

| Dienst | Adresse |
|---|---|
| Jellyfin | http://192.168.1.224:8096 |
| Grafana | http://192.168.1.228 |
| Uptime Kuma | http://192.168.1.229 (soll durch Alertmanager ersetzt werden) |
| Argo CD | `kubectl -n argocd port-forward svc/argocd-server 8080:443` |
| Longhorn | `kubectl -n longhorn-system port-forward svc/longhorn-frontend 8081:80` |

MetalLB-Pool: 192.168.1.220 bis 192.168.1.239.

## GitOps-Struktur

| Application | Pfad | Sync |
|---|---|---|
| root-app | kubernetes/argocd/applications | auto, prune |
| argocd | kubernetes/argocd/install | auto, kein prune, ServerSideApply |
| infrastructure | kubernetes/infrastructure | auto, kein prune |
| core-apps | kubernetes/core | auto, kein prune |
| home-apps | kubernetes/apps | auto, kein prune |
| external-secrets | Helm-Chart | auto, kein prune, ServerSideApply |
| kube-prometheus-stack | Helm-Chart | auto, prune, ServerSideApply |

Entfernen einer Anwendung: Manifeste löschen, committen, dann einmalig mit Prune synchronisieren (Apps mit „kein prune“ löschen sonst nichts).
Entfernte Dienste (Home Assistant, Mosquitto, Terraria, Portainer) sind über den Tag `archiv/vor-entfernung-2026-09-29` wiederherstellbar.

## Secrets

Keine Secrets in Git (Repository ist öffentlich). Secrets kommen über den External Secrets Operator aus 1Password:

| Secret | Namespace | 1Password-Eintrag (Tresor Homelab-K3s-ESO) |
|---|---|---|
| cifs-secret | longhorn-system | samba-longhorn-backup |
| grafana-admin | monitoring | grafana-admin |

Einziges manuell angelegtes Secret: `external-secrets/onepassword-sa-token` (Token des Service Accounts eso-k3s, nur Lesezugriff).

## Speicher und Backup

| StorageClass | Replikas | Hinweis |
|---|---|---|
| longhorn-fast | 2 | Default |
| longhorn | 3 | Altbestand, nicht Default |
| longhorn-2replica, longhorn-static | | Altbestand |

| Sicherung | Zeitplan | Ziel |
|---|---|---|
| Longhorn-Backup aller Volumes | täglich 01:00, 7 behalten | cifs://192.168.1.15/LonghornBackup (USB-HDD rpi5) |
| Longhorn-Snapshots | täglich 02:00, 7 behalten | lokal |
| Snapshot-Bereinigung | sonntags 04:00 | |
| Jellyfin (rsync) | sonntags 03:00 | /mnt/media/backup/jellyfin-backups |

Wiederherstellung getestet am 29.09.2026. Details: docs/BACKUP_RESTORE.md.

## Betrieb

```bash
kubectl get nodes
kubectl -n argocd get applications.argoproj.io
kubectl get pods -A | grep -v -E "Running|Completed"
kubectl -n longhorn-system get volumes.longhorn.io
kubectl -n longhorn-system get backuptargets.longhorn.io
kubectl top nodes
```

SSH auf die Knoten: `ssh rpi5` usw. (Schlüssel `~/.ssh/homelab_ed25519`, vorher `ssh-add`).

## Dokumentation

| Datei | Inhalt |
|---|---|
| docs/PROTOKOLL-2026-09-29.md | Wartung und Modernisierung vom 29.09.2026 |
| docs/BACKUP_RESTORE.md | Backup, Wiederherstellung, Testprotokoll |
| docs/MONITORING.md | Zugang, Chart-Update, Kontrolle |
| docs/LESSONS_LEARNED.md | Erkenntnisse aus Störungen und Umbauten |
| docs/VLAN_NETWORK.md | Netzsegmentierung (VLAN) |
| kubernetes/argocd/README.md | Bootstrap und Upgrade Argo CD |
| kubernetes/infrastructure/longhorn/README.md | Lokale Anpassungen am Longhorn-Manifest |
| host-config/ | Konfiguration direkt auf den Knoten (k3s, Samba, Mounts) |
| docs/archiv/ | Veraltete Dokumente (Stand Januar 2026) |

## Offene Punkte

| Thema | Hinweis |
|---|---|
| Alertmanager-Benachrichtigung (Mail) und externes Lebenszeichen | Danach Uptime Kuma entfernen |
| Ansible an Ist-Stand angleichen | group_vars/hosts veraltet (Versionen, Startparameter, 1Password Connect) |
| coredns-custom prüfen | Enthält Einträge des entfernten Pi-hole |
| Backup-Kopie außer Haus | Backups liegen bisher nur am selben Standort |
| RAM auf rpi4 knapp | Größter Verbraucher: Argo CD Application Controller |
| Git-Historie: private E-Mail-Adresse in Commit-Metadaten | Bereinigen (git filter-repo) oder Repository privat stellen |
| Samba: Jellyfin-Sicherungen für Gäste lesbar | Freigabe Backup einschränken |
| Port 6443 nur aus Management-Netz | Mit VLAN-Härtung |
| SSH-Passwortanmeldung abschalten | Erst nach längerer Nutzung des Schlüssels |
