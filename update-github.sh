#!/bin/bash
# Git Update Script für Homelab K3s Repository
# Führe dieses Script in deinem ~/homelab-k3s Verzeichnis aus

set -e

echo "=========================================="
echo "📦 Homelab K3s - Git Update"
echo "=========================================="

# 1. Zone.Identifier Dateien entfernen (Windows-Artefakte)
echo ""
echo "🧹 Entferne Zone.Identifier Dateien..."
find . -name "*.Zone.Identifier" -type f -delete 2>/dev/null || true
find . -name "*:Zone.Identifier" -type f -delete 2>/dev/null || true

# 2. README.md aktualisieren
echo ""
echo "📝 Aktualisiere README.md..."
cat > README.md << 'READMEEOF'
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

| Service | Type | IP/Port | Description |
|---------|------|---------|-------------|
| **Pi-hole v2025** | DNS + Ad-Blocking | 192.168.1.220:80 (Web) / 192.168.1.225:53 (DNS) | Network-wide ad-blocking |
| **Home Assistant v2025** | Smart Home | 192.168.1.223:8123 | Home automation hub |
| **Jellyfin 10.10.3** | Media Server | 192.168.1.224:8096 | 3x USB3 HDDs |
| **MQTT** | Message Broker | 192.168.1.222:1883 | IoT communication |
| **Portainer** | Management UI | 192.168.1.227:9443 | Kubernetes Web UI |
| **Prometheus** | Monitoring | Internal | Metrics collection |
| **Grafana** | Dashboards | 192.168.1.228 | Monitoring dashboards |
| **ArgoCD** | GitOps | Port-Forward 8080 | Continuous deployment |

---

## 💾 Storage Architecture (Optimized January 2026)

### Longhorn Settings
| Setting | Value | Reason |
|---------|-------|--------|
| `replica-soft-anti-affinity` | `true` | Allows replicas on same node when necessary |
| `default-replica-count` | `2` | Optimal for 3-node cluster |
| `replica-auto-balance` | `best-effort` | Automatic replica distribution |

### Storage Classes
| Class | Replicas | Use Case |
|-------|----------|----------|
| `longhorn` | 3 | Default (legacy) |
| `longhorn-fast` | 2 | NVMe-optimized, recommended |

### Volume Status (15 Volumes - All Healthy)
- Prometheus: 20Gi (expanded from 10Gi)
- Grafana: 5Gi
- Alertmanager: 2Gi
- Pi-hole (x3): 2Gi + 1Gi each
- Home Assistant: 5Gi
- Jellyfin: 10Gi config + 10Gi cache
- MQTT: 2Gi
- Portainer: 10Gi
- Terraria: 5Gi

**Why 2 Replicas?**
- 3 replicas on 3-node cluster creates scheduling constraints
- 2 replicas = fault tolerant + flexible scheduling
- Saves ~33% storage overhead (~15Gi saved)

---

## 📊 Monitoring

### Prometheus Configuration
- **Storage**: 20Gi PVC
- **Retention**: 5 days
- **Retention Size**: 18GB
- **WAL Compression**: enabled
- **Scrape Interval**: 30s

### Grafana Access
```
http://192.168.1.228
Default: admin / admin
```

### Health Check Commands
```bash
# Check Prometheus disk
kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -c prometheus -- df -h /prometheus

# Check Longhorn volumes
kubectl get volumes -n longhorn-system -o custom-columns=NAME:.metadata.name,ROBUSTNESS:.status.robustness

# Check all pods
kubectl get pods -A | grep -v Running
```

---

## 🔧 Recent Changes (January 5, 2026)

### Fixed: Grafana "No Data" Issue

**Root Causes:**
1. Prometheus PVC full (10Gi → 100%)
2. Time drift on Raspberry Pi nodes (~1 hour)
3. Corrupted WAL data
4. Longhorn replica scheduling issues

**Solutions:**
1. Expanded Prometheus PVC: 10Gi → 20Gi
2. Enabled NTP on all nodes
3. Cleared corrupted WAL data
4. Optimized Longhorn settings:
   - `replica-soft-anti-affinity`: true
   - `default-replica-count`: 2
   - Reduced all volumes to 2 replicas

**Results:**
- ✅ Grafana displays metrics
- ✅ 15/15 volumes healthy
- ✅ ~15Gi storage saved
- ✅ All nodes time-synced

---

## 🎬 Jellyfin Notes

**Version**: 10.10.3 (last stable for ARM64)

10.11.x has memory leak issues on Raspberry Pi. Wait for 10.11.6+ fix.

**Optimizations applied:**
- `JELLYFIN_parallel_scan_tasks: 1`
- `JELLYFIN_FFmpeg__probesize: 50000000`
- `MALLOC_TRIM_THRESHOLD_: 100000`

---

## 📝 Maintenance Commands

```bash
# Daily check
kubectl get nodes
kubectl get pods -A | grep -v Running
kubectl top nodes

# Storage check
kubectl get volumes -n longhorn-system -o custom-columns=NAME:.metadata.name,ROBUSTNESS:.status.robustness

# Reduce volume replicas (if needed)
kubectl patch volume <pvc-name> -n longhorn-system --type='merge' -p '{"spec":{"numberOfReplicas":2}}'

# Check Longhorn settings
kubectl get settings -n longhorn-system replica-soft-anti-affinity -o jsonpath='{.value}'
```

---

**Last Updated**: January 5, 2026  
**Status**: 🟢 PRODUCTION-READY
READMEEOF

# 3. monitoring-helm.yaml ist bereits aktualisiert (wurde bereits gepusht)

# 4. LONGHORN_OPTIMIZATION.md erstellen
echo ""
echo "📝 Erstelle LONGHORN_OPTIMIZATION.md..."
cat > docs/LONGHORN_OPTIMIZATION.md << 'LONGHORNEOF'
# Longhorn Storage Optimization

## Configuration for 3-Node Raspberry Pi Cluster

Optimized on January 5, 2026 to resolve replica scheduling issues.

## Settings Applied

```bash
# Allow replicas on same node when necessary
kubectl patch settings replica-soft-anti-affinity -n longhorn-system --type='merge' -p '{"value": "true"}'

# Reduce default replicas from 3 to 2
kubectl patch settings default-replica-count -n longhorn-system --type='merge' -p '{"value": "{\"v1\":\"2\",\"v2\":\"2\"}"}'

# Enable auto-balancing
kubectl patch settings replica-auto-balance -n longhorn-system --type='merge' -p '{"value": "best-effort"}'
```

## Why 2 Replicas Instead of 3?

On a 3-node cluster with 3 replicas:
- Every node MUST have a copy
- If any node has disk issues → volume becomes degraded
- No scheduling flexibility

With 2 replicas:
- Data is still fault-tolerant (survives 1 node failure)
- Longhorn can choose optimal placement
- ~33% storage savings

## Reducing Replicas on Existing Volumes

```bash
# List all volumes
kubectl get volumes -n longhorn-system -o custom-columns=NAME:.metadata.name,REPLICAS:.spec.numberOfReplicas

# Reduce to 2 replicas
kubectl patch volume <pvc-uuid> -n longhorn-system --type='merge' -p '{"spec":{"numberOfReplicas":2}}'
```

## Cleaning Up Stopped Replicas

```bash
# Find stopped replicas
kubectl get replicas -n longhorn-system | grep stopped

# Delete stopped replica
kubectl delete replica <replica-name> -n longhorn-system
```

## Troubleshooting

### Volume Degraded
```bash
# Check replica status
kubectl get replicas -n longhorn-system -l longhornvolume=<volume-name>

# Check node disk status
kubectl get nodes.longhorn.io -n longhorn-system -o yaml
```

### Replica Won't Schedule
1. Check `replica-soft-anti-affinity` is `true`
2. Check node has enough disk space
3. Delete any stopped replicas for the volume
LONGHORNEOF

# 5. docs Verzeichnis erstellen falls nicht vorhanden
mkdir -p docs

# 6. Git Status prüfen
echo ""
echo "📊 Git Status..."
git status

# 7. Änderungen stagen
echo ""
echo "➕ Stage Änderungen..."
git add -A

# 8. Commit erstellen
echo ""
echo "💾 Erstelle Commit..."
git commit -m "fix: Monitoring & Longhorn storage optimization (Jan 5, 2026)

## Changes:
- Prometheus PVC: 10Gi → 20Gi (was full)
- Prometheus retention: 7d → 5d, 18GB max
- WAL compression enabled
- Longhorn replica-soft-anti-affinity: true
- Longhorn default-replica-count: 3 → 2
- All 15 volumes now healthy with 2 replicas
- ~15Gi storage saved

## Root Causes Fixed:
1. Prometheus disk full causing No Data in Grafana
2. Time drift on Pi nodes (NTP enabled)
3. Corrupted WAL data (cleaned)
4. Longhorn scheduling issues (settings optimized)

## Documentation:
- Updated README.md with storage architecture
- Added docs/LONGHORN_OPTIMIZATION.md
- Removed Windows Zone.Identifier files"

# 9. Push zu GitHub
echo ""
echo "🚀 Push zu GitHub..."
git push origin main

echo ""
echo "=========================================="
echo "✅ Alle Änderungen wurden zu GitHub gepusht!"
echo "=========================================="
echo ""
echo "ArgoCD wird in ~3 Minuten synchronisieren."
echo "Prüfe mit: kubectl get applications -n argocd"
