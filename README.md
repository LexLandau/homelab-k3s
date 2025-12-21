# K3s Homelab Cluster

3-Node High-Availability Kubernetes Cluster für Smart Home & Homelab Services

## 🏗️ Cluster Architektur

### Hardware
- **rpi5** (8GB RAM, NVMe) - `node-role: high-memory` - Monitoring & Memory-intensive Apps
- **rpi4-cm4** (4GB RAM, NVMe) - `node-role: monitoring` - General Workloads
- **rpi4** (4GB RAM, SSD) - `node-role: network-services` - Network Services

Alle Nodes sind Control Plane + Worker (keine Taints)

### Infrastructure
- **K3s** v1.30.8+k3s1
- **MetalLB** v0.15.3 - LoadBalancer (192.168.1.220-239)
- **Longhorn** v1.10.1 - Distributed Storage (2 Replicas)
- **ArgoCD** v2.13.2 - GitOps Continuous Deployment
- **Renovate Bot** - Automatic dependency updates via GitHub PRs

---

## 🚀 Deployed Services

| Service | Type | IP/Port | Description | Node Affinity |
|---------|------|---------|-------------|---------------|
| **Pi-hole v2025** | DNS + Ad-Blocking | 192.168.1.220:80 (Web)<br>192.168.1.225:53 (DNS UDP) | Network-wide ad-blocking | rpi4 (StatefulSet) |
| **Home Assistant v2025** | Smart Home | 192.168.1.223:8123 | Home automation hub | rpi4/rpi5 |
| **Jellyfin** | Media Server | 192.168.1.224:8096 | 2x USB3 HDDs (Movies, Series, Music) | rpi5 (direct USB) |
| **MQTT** | Message Broker | 192.168.1.222:1883 | IoT communication | Any node |
| **Portainer** | Management UI | 192.168.1.227:9443 | Kubernetes Web UI | Any node |
| **Prometheus** | Monitoring | Internal | Metrics collection & storage | rpi5 (high-memory) |
| **Grafana** | Dashboards | 192.168.1.228 | Monitoring dashboards | rpi5 (high-memory) |
| **ArgoCD** | GitOps | Port-Forward 8080 | Continuous deployment | Any node |

---

## 📦 Deployment

### Via ArgoCD (GitOps) - RECOMMENDED
```bash
# All apps auto-sync from GitHub
kubectl get applications -n argocd

# Applications managed:
# - root-app (manages all other apps)
# - core-apps (Pi-hole, MQTT)
# - home-apps (Home Assistant, Jellyfin)
# - infrastructure (MetalLB, Longhorn)
# - monitoring (Prometheus, Grafana)
```

### Manual Deployment (for troubleshooting)
```bash
# Core Services
kubectl apply -f kubernetes/core/

# Home Apps
kubectl apply -f kubernetes/apps/

# Monitoring
kubectl apply -f kubernetes/monitoring/
```

---

## 🤖 Automation

### Renovate Bot
- **Automatic Updates**: Scans repository for Docker image updates
- **Pull Requests**: Creates PRs with release notes and changelogs
- **Review & Merge**: Merge PR → ArgoCD deploys automatically
- **Dashboard**: https://github.com/LexLandau/homelab-k3s/issues/3

### ArgoCD GitOps
- **Auto-Sync**: Enabled for infrastructure and monitoring
- **Manual Sync**: Core and home apps (for safety)
- **Health Checks**: Monitors application health
- **Rollback**: Easy rollback via Git revert

---

## 🔧 Useful Commands
```bash
# Cluster Status
kubectl get nodes -L node-role
kubectl get pods -A
kubectl top nodes

# Services & IPs
kubectl get svc -A | grep LoadBalancer

# ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# https://localhost:8080

# Grafana (Monitoring)
# http://192.168.1.228

# Portainer (Management)
# https://192.168.1.227:9443

# Logs
kubectl logs -n <namespace> <pod-name> -f

# Restart Deployment
kubectl rollout restart deployment <name> -n <namespace>
```

---

## 🌐 Network Configuration

- **Fritz!Box**: 192.168.1.1 (Router + DNS Upstream)
- **Pi-hole DNS**: 192.168.1.225 (UDP) - Configured in Fritz!Box DHCP
- **MetalLB Pool**: 192.168.1.220-192.168.1.239
- **Cluster Network**: 10.42.0.0/16 (Flannel)
- **Service Network**: 10.43.0.0/16
- **Connection**: Ethernet (eth0) - Migrated from WLAN

---

## 📊 Monitoring

### Prometheus + Grafana Stack
```bash
# Grafana Dashboards (pre-imported):
# - 15759: Kubernetes / Compute Resources / Cluster
# - 15760: Kubernetes / Compute Resources / Node  
# - 1860: Node Exporter Full
# - 13032: Longhorn Dashboard (optional)

# Access Grafana:
http://192.168.1.228

# Prometheus Query:
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# http://localhost:9090
```

---

## 📡 Network Migration Notes

**Cluster migrated from WLAN to Ethernet (Dec 1, 2025)**

Changes:
- All Pis connected via Ethernet cables (Keller)
- WLAN disabled on all Pis
- K3s flannel interface changed from `wlan0` to `eth0`
- All services running stable on wired network

Performance improvements:
- Lower latency
- More stable connections  
- Better throughput for Longhorn storage
- No WiFi interference

---

## 🎯 Best Practices Implemented

### Pi-hole
- ✅ **StatefulSet** instead of Deployment (proper for databases)
- ✅ **NO hostNetwork** (clean networking)
- ✅ **externalTrafficPolicy: Local** (source IP preservation)
- ✅ **PersistentVolumes** via Longhorn (data persistence)

### Monitoring
- ✅ **Node Affinity** - Prometheus on rpi5 (8GB RAM)
- ✅ **Resource Limits** - Controlled memory usage
- ✅ **Persistent Storage** - Metrics retained across restarts

### GitOps
- ✅ **App-of-Apps Pattern** - Centralized management
- ✅ **Automated Updates** - Renovate Bot
- ✅ **Health Checks** - ArgoCD monitors all apps

---

## 🔐 Secrets Management

Secrets stored in **1Password**:
- ArgoCD Admin Credentials
- Pi-hole Admin Password  
- GitHub Personal Access Token
- K3s Cluster Token
- Grafana Admin Password
- Portainer Admin Password

**⚠️ NEVER commit secrets to Git!**

---

## 📚 Future Enhancements

Potential additions:
- [ ] **Traefik** - Reverse proxy with automatic HTTPS
- [ ] **Cert-Manager** - Automatic SSL certificates
- [ ] **Velero** - Kubernetes backup solution
- [ ] **Uptime Kuma** - Service uptime monitoring
- [ ] **ESPHome** - ESP32/ESP8266 firmware management
- [ ] **Nextcloud** - Private cloud storage
- [ ] **ADSB Tracker** - Flight tracking

---

## 🎉 Current Status: PRODUCTION-READY!

### Deployed Services:
- ✅ **Pi-hole v2025**: DNS + Ad-Blocking (Best Practice setup)
- ✅ **Home Assistant v2025**: Smart Home automation
- ✅ **Jellyfin**: Media Server with 2x USB3 HDDs
- ✅ **MQTT**: IoT Message Broker
- ✅ **Portainer**: Kubernetes Management UI
- ✅ **Prometheus + Grafana**: Full monitoring stack

### Architecture Highlights:
- 🏗️ **3-Node HA Kubernetes Cluster** on Ethernet
- 🔄 **GitOps** with ArgoCD - All deployments from Git
- 🤖 **Automated Updates** - Renovate Bot handles dependencies
- 💾 **Distributed Storage** - Longhorn with 2 replicas
- 🌐 **LoadBalancer** - MetalLB for service IPs
- 📊 **Full Observability** - Prometheus + Grafana monitoring
- 🛡️ **Fault Tolerant** - Can survive 1 node failure (etcd quorum)

### Memory Distribution (Optimized):
- **rpi5 (8GB)**: Prometheus (1373Mi) + Jellyfin (575Mi) + Grafana (312Mi) = **70%** usage
- **rpi4 (4GB)**: Pi-hole (15Mi) + Longhorn + Network services = **72%** usage
- **rpi4-cm4 (4GB)**: Home Assistant (509Mi) + Terraria (316Mi) + General workloads = **57%** usage

All nodes well balanced! ✅

---

## 📝 Maintenance

### Update Workflow:
1. Renovate detects updates → Creates PR
2. Review release notes in PR
3. Merge PR in GitHub
4. ArgoCD auto-syncs (3 minutes)
5. Done! ✨

### Backup Strategy:
- **GitOps**: All configs in Git (version controlled)
- **Longhorn**: 2 replicas across nodes
- **Manual**: Regular etcd snapshots on nodes

### Health Checks:
```bash
# Daily check:
kubectl get nodes
kubectl get pods -A | grep -v Running
kubectl top nodes

# Weekly check:
# - Grafana dashboards for trends
# - Renovate dependency dashboard
# - Longhorn volume health
```

---

**Last Updated: December 19, 2025
**Cluster Version**: K3s v1.30.8+k3s1 | Longhorn v1.10.1 | MetalLB v0.15.3  
**Status**: 🟢 PRODUCTION-READY

---

## 🔧 Recent Optimizations (December 19, 2025)

### Pi-hole Performance Tuning
Resolved DNS performance issues and slow UI saves:

**Problem**: 
- Internetseiten waren sekunden-lang nicht erreichbar
- Pi-hole UI speichern dauerte 10-12 Sekunden
- 365.000 Query-Log-Einträge belasteten jeden Neustart

**Lösung**:
1. **Storage-Optimierung**: Neue `longhorn-fast` StorageClass mit 2 Replicas (statt 3)
   - 33% weniger Netzwerk-Overhead bei Schreibzugriffen
   - Konsistente 60 MB/s Write-Performance
2. **Query-Log-Begrenzung**: `MAXDBDAYS=1` in pihole-FTL.conf
   - Datenbank bleibt unter 100KB (war >100MB)
   - Nur noch ~200 Queries im RAM (war 147.000)
3. **Upstream-DNS optimiert**: Fritz!Box (DNS-over-TLS) mit Google/Cloudflare Fallbacks

**Ergebnis**:
- ✅ UI Save-Zeit: 10-12s → **3s** (70% Verbesserung)
- ✅ DNS Cache Hits: **0ms** (vorher "stale answers")
- ✅ Datenbank: 365k Rows → **~200 Rows** (99.9% Reduktion)
- ✅ Keine Verbindungsprobleme mehr

**Alle Änderungen sind GitOps-managed** und werden automatisch bei Neudeployments angewendet.


### Storage Architecture Details

**Physical Hardware:**
- **rpi5**: 477GB NVMe (System + Longhorn) + 3x USB3 HDDs (1.8TB + 1.8TB + 3.6TB for Media)
- **rpi4-cm4**: 477GB NVMe (System + Longhorn)
- **rpi4**: 119GB SSD via USB3 (System + Longhorn)

**Why V1 Data Engine (not V2/SPDK)?**
- V2 requires 1 CPU core (100% usage) per node = 25% CPU overhead on 4-core Pis
- V1 already achieves 60 MB/s write performance with 2 replicas
- Current workloads are not I/O-intensive enough to justify V2 overhead
- V2 is designed for high-end servers with 16+ CPU cores and NVMe-only setups

For more details on V2 vs V1, see [Longhorn Performance Benchmark](https://github.com/longhorn/longhorn/wiki/Performance-Benchmark).

## Recent Updates (December 19, 2025)

### Phase 1: Core Infrastructure Upgrades
- **Longhorn**: v1.10.0 → v1.10.1 (Bugfixes, Security)
- **MetalLB**: v0.14.9 → v0.15.3 (CVE-2025-22874, FRR 10.4.1)
- All services validated and operational
- Zero downtime during upgrades

**Next Steps:** K3s v1.30.8 → v1.31.8 (planned)

---

## 🎬 Jellyfin Configuration Notes (December 21, 2025)

### Current Version: 10.10.3 (Stable)

**Why not 10.11.x?**
- Jellyfin 10.11.x has a critical memory leak on ARM64/Raspberry Pi during library scans
- GitHub Issues: [#15728](https://github.com/jellyfin/jellyfin/issues/15728), [#13165](https://github.com/jellyfin/jellyfin/issues/13165), [#11588](https://github.com/jellyfin/jellyfin/issues/11588)
- Symptoms: Memory explosion from 500Mi → 4Gi+ in seconds → OOM crash
- **10.10.3 is the last stable version** for Raspberry Pi setups

### Optimizations Applied
```yaml
Image: jellyfin/jellyfin:10.10.3
Memory Limits: 4Gi limit / 2Gi request
Environment Variables:
  - JELLYFIN_parallel_scan_tasks: "1"           # Limit concurrent file scanning
  - JELLYFIN_FFmpeg__probesize: "50000000"      # 50M (reduced from 200M default)
  - JELLYFIN_FFmpeg__analyzeduration: "50000000" # 50M (reduced from 200M default)
  - MALLOC_TRIM_THRESHOLD_: "100000"            # Better glibc heap management
```

### Library Configuration (NFO-Only)
- **Metadata Downloaders**: ALL disabled (TMDb, OMDb, etc.)
- **Metadata Readers**: ONLY "Nfo" enabled
- **Download Images**: Disabled
- **Reason**: Reduces memory usage and API calls during scans

### Performance Results
- ✅ **~327+ Movies scanned successfully** (3x USB3 HDDs)
- ✅ **Memory stable at ~600Mi** (previously crashed at 4Gi)
- ✅ **No OOM kills** during library scans
- ✅ **TV Shows & Music libraries working**

### Storage Layout
```
/media/movies-backup-hdd   → /mnt/media/backup/Filme    (USB HDD 1)
/media/movies-nas          → /mnt/media/movies/Filme    (USB HDD 2)
/media/series-nas          → /mnt/media/movies/Serien   (USB HDD 2)
/media/music              → /mnt/media/series/Musik    (USB HDD 3)
+ backup directories for redundancy
```

### Migration Path to 10.11.x (Future)
Monitor these GitHub issues for memory leak fixes:
- Watch for 10.11.6+ release notes
- Test in staging before upgrading
- Database from 10.10.3 should be compatible

For detailed setup notes, see: [JELLYFIN_SETUP.md](./JELLYFIN_SETUP.md)

