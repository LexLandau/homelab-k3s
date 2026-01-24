# K3s Homelab Cluster

3-Node High-Availability Kubernetes Cluster für Smart Home & Homelab Services

## 🏗️ Cluster Architektur

### Hardware
- **rpi5** (8GB RAM, NVMe) - `node-role: high-memory` - Monitoring & Memory-intensive Apps
- **rpi4-cm4** (4GB RAM, NVMe) - `node-role: monitoring` - General Workloads
- **rpi4** (4GB RAM, SSD) - `node-role: network-services` - Network Services

Alle Nodes sind Control Plane + Worker (keine Taints)

### Infrastructure
- **K3s** v1.33.6+k3s1
- **MetalLB** v0.15.3 - LoadBalancer (192.168.1.220-239)
- **Longhorn** v1.10.1 - Distributed Storage (2 Replicas)
- **ArgoCD** v2.13.2 - GitOps Continuous Deployment
- **Renovate Bot** - Automatic dependency updates via GitHub PRs

---

## 🚀 Deployed Services

| Service | Type | IP/Port | Description | Node Affinity |
|---------|------|---------|-------------|---------------|
| **Pi-hole v2025** | DNS + Ad-Blocking | 192.168.1.220:80 (Web)<br>192.168.1.225:53 (DNS UDP) | Network-wide ad-blocking | StatefulSet (3 replicas) |
| **Home Assistant v2025** | Smart Home | 192.168.1.223:8123 | Home automation hub | rpi4/rpi5 |
| **Jellyfin 10.10.3** | Media Server | 192.168.1.224:8096 | 3x USB3 HDDs (Movies, Series, Music) | rpi5 (direct USB) |
| **MQTT** | Message Broker | 192.168.1.222:1883 | IoT communication | Any node |
| **Portainer** | Management UI | 192.168.1.227:9443 | Kubernetes Web UI | Any node |
| **Prometheus** | Monitoring | Internal | Metrics collection & storage | rpi5 (high-memory) |
| **Grafana** | Dashboards | 192.168.1.228 | Monitoring dashboards | rpi5 (high-memory) |
| **ArgoCD** | GitOps | Port-Forward 8080 | Continuous deployment | Any node |
| **Uptime Kuma** | Monitoring | 192.168.1.229:80 | Service uptime monitoring | Any node |

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

### Monitoring Health Checks
```bash
# Check Prometheus disk usage
kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -c prometheus -- df -h /prometheus

# Check all targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit http://localhost:9090/targets
```

---

## 💾 Storage Architecture

### Longhorn Configuration (Optimized January 2026)

**Settings for 3-Node Raspberry Pi Cluster:**
| Setting | Value | Reason |
|---------|-------|--------|
| `replica-soft-anti-affinity` | `true` | Allows replicas on same node when necessary |
| `default-replica-count` | `2` | Optimal for 3-node cluster (was 3) |
| `replica-auto-balance` | `best-effort` | Automatic replica distribution |
| `storage-over-provisioning-percentage` | `100` | Allow 2x overprovisioning |
| `storage-minimal-available-percentage` | `25` | Reserve 25% disk space |

**Storage Classes:**
| Class | Replicas | Use Case |
|-------|----------|----------|
| `longhorn` | 3 | Default (legacy) |
| `longhorn-fast` | 2 | NVMe-optimized, recommended |
| `local-path` | 1 | No replication |

**Physical Hardware:**
- **rpi5**: 477GB NVMe (System + Longhorn) + 3x USB3 HDDs (1.8TB + 1.8TB + 3.6TB for Media)
- **rpi4-cm4**: 477GB NVMe (System + Longhorn)
- **rpi4**: 119GB SSD via USB3 (System + Longhorn)

**Current Volume Status (15 Volumes):**
| Service | PVC Size | Replicas | Status |
|---------|----------|----------|--------|
| Prometheus | 20Gi | 2 | ✅ healthy |
| Grafana | 5Gi | 2 | ✅ healthy |
| Alertmanager | 2Gi | 2 | ✅ healthy |
| Pi-hole (x3) | 2Gi + 1Gi each | 2 | ✅ healthy |
| Home Assistant | 5Gi | 2 | ✅ healthy |
| Jellyfin Config | 10Gi | 2 | ✅ healthy |
| Jellyfin Cache | 10Gi | 2 | ✅ healthy |
| MQTT | 2Gi | 2 | ✅ healthy |
| Portainer | 10Gi | 2 | ✅ healthy |
| Terraria | 5Gi | 2 | ✅ healthy |

**Why 2 Replicas (not 3)?**
- 3 replicas on 3-node cluster = every node must have a copy
- If one node is down or disk full → scheduling fails
- 2 replicas = fault tolerant + flexible scheduling
- Saves ~33% storage overhead

### Longhorn Maintenance Commands
```bash
# Check all volume health
kubectl get volumes -n longhorn-system -o custom-columns=NAME:.metadata.name,ROBUSTNESS:.status.robustness,REPLICAS:.spec.numberOfReplicas

# Check node disk status
kubectl get nodes.longhorn.io -n longhorn-system -o custom-columns=NAME:.metadata.name,SCHEDULABLE:.status.diskStatus.*.conditions[0].status

# Check current settings
kubectl get settings -n longhorn-system replica-soft-anti-affinity -o jsonpath='{.value}'
kubectl get settings -n longhorn-system default-replica-count -o jsonpath='{.value}'

# Reduce replicas on a volume (if needed)
kubectl patch volume <pvc-name> -n longhorn-system --type='merge' -p '{"spec":{"numberOfReplicas":2}}'
```

---

## 🎯 Best Practices Implemented

### Pi-hole
- ✅ **StatefulSet** instead of Deployment (proper for databases)
- ✅ **NO hostNetwork** (clean networking)
- ✅ **externalTrafficPolicy: Local** (source IP preservation)
- ✅ **PersistentVolumes** via Longhorn (data persistence)
- ✅ **Query-Log-Begrenzung**: `MAXDBDAYS=1` (performance)

### Monitoring
- ✅ **Node Affinity** - Prometheus on rpi5 (8GB RAM)
- ✅ **Resource Limits** - Controlled memory usage
- ✅ **Persistent Storage** - 20Gi for Prometheus (5 day retention)
- ✅ **WAL Compression** - Reduced disk usage

### Longhorn Storage
- ✅ **2 Replicas** - Optimal for 3-node cluster
- ✅ **Soft Anti-Affinity** - Flexible scheduling
- ✅ **Auto-Balance** - Even distribution
- ✅ **NVMe Storage Classes** - Performance optimization

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
- [x] **Uptime Kuma** - Service uptime monitoring
- [ ] **ESPHome** - ESP32/ESP8266 firmware management
- [ ] **Nextcloud** - Private cloud storage

---

## 🎉 Current Status: PRODUCTION-READY!

### Deployed Services:
- ✅ **Pi-hole v2025**: DNS + Ad-Blocking (HA StatefulSet)
- ✅ **Home Assistant v2025**: Smart Home automation
- ✅ **Jellyfin 10.10.3**: Media Server with 3x USB3 HDDs
- ✅ **MQTT**: IoT Message Broker
- ✅ **Portainer**: Kubernetes Management UI
- ✅ **Prometheus + Grafana**: Full monitoring stack

### Architecture Highlights:
- 🏗️ **3-Node HA Kubernetes Cluster** on Ethernet
- 🔄 **GitOps** with ArgoCD - All deployments from Git
- 🤖 **Automated Updates** - Renovate Bot handles dependencies
- 💾 **Distributed Storage** - Longhorn with 2 replicas (optimized)
- 🌐 **LoadBalancer** - MetalLB for service IPs
- 📊 **Full Observability** - Prometheus + Grafana monitoring
- 🛡️ **Fault Tolerant** - Can survive 1 node failure (etcd quorum)

### Storage Status:
- ✅ **15/15 Longhorn volumes healthy**
- ✅ **All volumes using 2 replicas**
- ✅ **~15Gi saved** by optimizing replica count

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

# Storage check:
kubectl get volumes -n longhorn-system -o custom-columns=NAME:.metadata.name,ROBUSTNESS:.status.robustness
```

---

## 🔧 Recent Optimizations

### January 5, 2026: Monitoring & Storage Fix

**Problem:** Grafana showing "No Data"

**Root Causes Identified:**
1. Prometheus PVC full (10Gi at 100%)
2. Time drift (~1 hour) on Raspberry Pi nodes
3. Corrupted WAL data preventing Prometheus startup
4. Longhorn volumes in degraded state (replica scheduling issues)

**Solutions Applied:**

1. **Prometheus Storage Expansion:**
   - PVC: 10Gi → 20Gi
   - Retention: 7d → 5d
   - RetentionSize: 18GB
   - WAL Compression: enabled

2. **Time Synchronization:**
   ```bash
   # All nodes
   sudo timedatectl set-ntp true
   sudo systemctl restart systemd-timesyncd
   ```

3. **Longhorn Optimization:**
   - `replica-soft-anti-affinity`: false → true
   - `default-replica-count`: 3 → 2
   - Reduced all existing volumes to 2 replicas
   - Cleaned up stopped/failed replicas

**Results:**
- ✅ Grafana displays all metrics
- ✅ 15/15 Longhorn volumes healthy
- ✅ ~15Gi storage saved
- ✅ NTP synchronized on all nodes

### December 19, 2025: Pi-hole Performance Tuning

**Problem:** 
- DNS queries slow (seconds delay)
- Pi-hole UI save: 10-12 seconds

**Solution:**
1. `longhorn-fast` StorageClass (2 replicas)
2. `MAXDBDAYS=1` in pihole-FTL.conf
3. Fritz!Box DNS-over-TLS upstream

**Results:**
- UI Save: 10-12s → 3s
- DNS Cache Hits: 0ms
- Database: 365k → ~200 rows

---

## 🎬 Jellyfin Configuration

### Version: 10.10.3 (Stable for ARM64)

**Why not 10.11.x?**
- Critical memory leak on ARM64 during library scans
- GitHub Issues: #15728, #13165, #11588
- 10.10.3 is the last stable version for Raspberry Pi

### Optimizations
```yaml
Environment:
  JELLYFIN_parallel_scan_tasks: "1"
  JELLYFIN_FFmpeg__probesize: "50000000"
  JELLYFIN_FFmpeg__analyzeduration: "50000000"
  MALLOC_TRIM_THRESHOLD_: "100000"
```

### Storage Layout
```
/media/movies-nas     → /mnt/media/movies/Filme
/media/series-nas     → /mnt/media/movies/Serien
/media/music          → /mnt/media/series/Musik
/media/backup         → /mnt/media/backup
```

See [JELLYFIN_SETUP.md](./JELLYFIN_SETUP.md) for details.

---

**Last Updated**: January 6, 2026
**Cluster Version**: K3s v1.33.6+k3s1 | Longhorn v1.10.1 | MetalLB v0.15.3  
**Status**: 🟢 PRODUCTION-READY

## 🥧 Pi-hole HA (Updated Jan 19, 2026)

**3-Replica High Availability:**
- pihole-0, pihole-1, pihole-2 (auf allen Nodes verteilt)
- DNS: 192.168.1.225 (LoadBalancer, HA)
- Web Admin: 192.168.1.220 (pihole-0 nur)

**Client-IP Logging aktiviert:**
- `externalTrafficPolicy: Local` auf pihole-dns Service
- Echte Client-IPs erscheinen im Query Log

**Nebula-Sync:**
- Sync alle 5 Minuten von Primary → Replicas
- Synced: Adlists, Domain-Listen, Clients
- Konfiguration nur über pihole-0 ändern!


## 🥧 Pi-hole Configuration (Updated Jan 24, 2026)

**Single Instance on rpi5:**
- **Deployment**: 1 replica on rpi5 (Kubernetes Deployment, Recreate strategy)
- **DNS**: 192.168.1.225 (UDP+TCP, externalTrafficPolicy: Local)
- **Web Admin**: http://192.168.1.220
- **Storage**: Longhorn (longhorn-fast, 2 replicas)
  - Config: 5Gi PVC
  - Dnsmasq: 2Gi PVC
- **Upstream DNS**: Fritz!Box (192.168.1.1) → Cloudflare (1.1.1.1) → Google (8.8.8.8)

**Fritz!Box Integration:**
- Fritz!Box DHCP: Verteilt DNS-Server 192.168.1.225 an alle Clients
- Fritz!Box DNS-Relay: Leitet alle DNS-Anfragen an Pi-hole weiter
- **Conditional Forwarding**: Pi-hole macht rDNS Lookup bei Fritz!Box für Client-Namen

**Client-Name Resolution:**
- Pi-hole sieht: `192.168.1.1` (Fritz!Box) als Source-IP
- Conditional Forwarding fragt Fritz!Box: "Welcher Hostname?"
- Query Log zeigt: **"alexs-laptop (192.168.1.1)"**

**Performance Optimizations:**
- `MAXDBDAYS=1` (Query Log: nur 1 Tag)
- `DBINTERVAL=30.0` (DB Write: alle 30 Sekunden)
- NVMe Storage (rpi5) für schnelle FTL-Datenbank

