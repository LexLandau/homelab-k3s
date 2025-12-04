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
- **MetalLB** v0.14.9 - LoadBalancer (192.168.1.220-239)
- **Longhorn** v1.7.2 - Distributed Storage (2 Replicas)
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
- **rpi5 (8GB)**: Prometheus (912MB) + Grafana (691MB) + Jellyfin = 67%
- **rpi4 (4GB)**: Pi-hole + Network services = 66%
- **rpi4-cm4 (4GB)**: General workloads = 57%

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

**Last Updated**: December 2, 2025  
**Cluster Version**: K3s v1.30.8+k3s1  
**Status**: 🟢 PRODUCTION-READY
