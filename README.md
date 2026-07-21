# K3s Homelab Cluster

3-Node Kubernetes Cluster (K3s) auf Raspberry Pi Hardware für Home Services und Homelab.

## Hardware

| Node | RAM | Storage | Rolle |
|------|-----|---------|-------|
| rpi5 | 8 GB | NVMe | high-memory (Jellyfin, Monitoring) |
| rpi4-cm4 | 4 GB | NVMe | monitoring (allgemeine Workloads) |
| rpi4 | 4 GB | SSD | network-services (allgemeine Workloads) |

Alle Nodes laufen als Control Plane + Worker (keine Taints).

## Infrastructure Stack

| Komponente | Version |
|------------|---------|
| K3s | v1.35.6+k3s1 |
| Longhorn | v1.10.1 |
| MetalLB | v0.15.3 |
| ArgoCD | v2.13.2 |
| system-upgrade-controller | latest |

## Services

| Service | Version | IP | Port |
|---------|---------|-----|------|
| Home Assistant | 2026.4 | 192.168.1.223 | 8123 |
| Jellyfin | latest (10.11.x) | 192.168.1.224 | 8096 |
| MQTT (Mosquitto) | 2.0 | 192.168.1.222 | 1883 |
| Portainer | CE latest | 192.168.1.227 | 9443 |
| Grafana | kube-prometheus-stack | 192.168.1.228 | 80 |
| Uptime Kuma | 2 | 192.168.1.229 | 80 |
| Terraria | latest | 192.168.1.230 | 7777 |
| MetalLB Pool | - | 192.168.1.220-239 | - |

## Storage

Longhorn v1.10.1 mit 2 Replicas (soft-anti-affinity).

| StorageClass | Replicas | Einsatz |
|--------------|----------|---------|
| longhorn | 2 | Standard |

10 Volumes (Pi-hole-Volumes mit AdGuard-Umzug entfernt).

USB-HDDs auf rpi5 (direkt gemountet, kein Longhorn):

| Mount | Größe | Filesystem |
|-------|-------|------------|
| /mnt/media/backup | 3.6 TB | EXT4 |
| /mnt/media/movies | 1.8 TB | EXT4 |
| /mnt/media/series | 1.8 TB | EXT4 |

## Netzwerk

- rpi5 Dual-NIC: eth0 192.168.1.10 (1GbE, K3s) / eth1 192.168.1.15 (2.5GbE, SMB)
- Flannel über eth0
- MetalLB L2-Mode

## GitOps

Alle Konfigurationen werden über ArgoCD aus diesem Repository deployed.

| App | Sync | Pfad |
|-----|------|------|
| infrastructure | auto, kein prune | kubernetes/infrastructure |
| core-apps | auto, kein prune | kubernetes/core |
| home-apps | auto, kein prune | kubernetes/apps |
| root-app | auto + prune | kubernetes/argocd/applications |

Dependency Updates via Renovate Bot (wöchentlich, kein Automerge).

## K3s Auto-Upgrade

system-upgrade-controller mit Plan `k3s-server` auf gepinnte Version (spec.version, Bump via Git).
Nodes werden automatisch nacheinander (concurrency: 1) gecordoned und upgraded.
```bash
kubectl get plans,jobs -n system-upgrade
```

## Monitoring

Prometheus (20 Gi PVC, 5d Retention) + Grafana + Uptime Kuma.
```bash
# Cluster-Status
kubectl get nodes
kubectl get pods -A | grep -v Running

# Longhorn Volumes
kubectl get volumes -n longhorn-system -o custom-columns=NAME:.metadata.name,ROBUSTNESS:.status.robustness

# Upgrade-Status
kubectl get plans,jobs -n system-upgrade
```

## Backup

- Longhorn RecurringJob: tägliche Snapshots, 7 Versionen (02:00 Uhr)
- Jellyfin: wöchentlicher CronJob (Sonntag 03:00), rsync auf Backup-HDD, 5 Versionen

---

## Lessons Learned (2026-07-21, Update- und Storage-Incident)

- **Soll-Replica-Inventur zuerst:** Vor Volume-Diagnosen und manuellen Replica-Deletes `spec.numberOfReplicas` aller Volumes prüfen. Legacy-SC-Volumes (alte `longhorn`-Class) standen auf Soll 3, Standard ist 2.
- **Engine-ERR-Geister nach Rolling-Restarts:** modeMap-Einträge ohne zugehörige Replica-CR blockieren Rebuilds dauerhaft (10-min-Takt = replica-replenishment-wait-interval). Fix: Workload auf 0 skalieren, Volume detachen lassen, wieder hochskalieren.
- **iSCSI-I/O-Errors (sdX) sind Folgesymptom:** session recovery timed out plus EXT4-Journal-Abbruch auf einem Longhorn-Device zeigt einen gestorbenen instance-manager an, keinen lokalen Plattendefekt.
- **Budget-SSD + etcd + parallele Rebuilds = Node-Ausfall:** Fanxiang S101 (ohne DRAM-Cache) liefert unter Parallellast sekundenlange fsync-Stalls (etcd slow fdatasync bis 18 s, k3s-Startloop, Load über 10). concurrent-replica-rebuild-per-node-limit=1 ist Dauerstandard; rpi4 dauerhaft ohne Longhorn-Replica-Scheduling (Entscheidung 2026-07-21: vorhandene SSD bleibt).
- **Longhorn-Settings gehören in die default-setting ConfigMap (Git):** Live-Patches driften und überleben Neustarts und Upgrades nicht zuverlässig.
- **Reboot-Kommandos als getrennte Blöcke ausführen:** Kommentar-Gates in Copy-Paste-Blöcken verschluckt die Shell; Node-Reboots einzeln, dazwischen Longhorn-Robustness prüfen.
- **findmnt nimmt genau ein Argument;** Multi-Mount-Checks als Schleife.
- **rpi4-Sonderkonfiguration:** k3s-Drop-in IOSchedulingClass=realtime (io-priority.conf) bewusst belassen; ohne BFQ-Scheduler wirkungslos, dokumentiert zur Nachvollziehbarkeit.

Last updated: 2026-07-21 | Status: operational
