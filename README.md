# K3s Homelab Cluster

3-Node High-Availability Kubernetes Cluster für Smart Home & Homelab Services

## 🏗️ Cluster Architektur

### Hardware
- **rpi5** (8GB RAM, NVMe) - node-role: high-memory
- **rpi4-cm4** (4GB RAM, NVMe) - node-role: monitoring
- **rpi4** (4GB RAM, SSD) - node-role: network-services

Alle Nodes sind Control Plane + Worker (keine Taints)

### Infrastructure
- **K3s** v1.30.8+k3s1
- **MetalLB** v0.14.9 - LoadBalancer (192.168.1.220-239)
- **Longhorn** v1.7.2 - Distributed Storage (2 Replicas)
- **ArgoCD** v2.13.2 - GitOps

## 🚀 Deployed Services

| Service | Type | IP/Port | Description |
|---------|------|---------|-------------|
| Pi-hole | DNS + Ad-Blocking | 192.168.1.220:80<br>192.168.1.221:53 | Network-wide ad-blocking |
| MQTT | Message Broker | 192.168.1.222:1883 | IoT communication |
| Home Assistant | Smart Home | 192.168.1.223:8123 | Home automation hub |
| ArgoCD | GitOps | Port-Forward 8080 | Continuous deployment |

## 📦 Deployment

### Via ArgoCD (GitOps)
```bash
# All apps auto-sync from Git
kubectl get applications -n argocd
```

### Manual Deployment
```bash
# Core Services
kubectl apply -f kubernetes/core/

# Home Apps
kubectl apply -f kubernetes/apps/
```

## 🔧 Useful Commands
```bash
# Cluster Status
kubectl get nodes -L node-role
kubectl get pods -A

# Services & IPs
kubectl get svc -A | grep LoadBalancer

# ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Logs
kubectl logs -n <namespace> <pod-name> -f
```

## 🌐 Network Configuration

- **Fritz!Box**: 192.168.1.1 (Router + DNS Upstream)
- **MetalLB Pool**: 192.168.1.220-192.168.1.239
- **Cluster Network**: 10.42.0.0/16
- **Service Network**: 10.43.0.0/16

## 📚 Next Steps

- [ ] ESPHome für ESP32/ESP8266 Firmware
- [ ] Jellyfin Media Server mit Fritz!Box NAS
- [ ] Prometheus + Grafana Monitoring
- [ ] Portainer Container Management
- [ ] ADSB Flight Tracker

## 🔐 Secrets Management

Secrets werden in 1Password gespeichert:
- ArgoCD Admin Credentials
- Pi-hole Admin Password
- GitHub Personal Access Token
- K3s Cluster Token

**Niemals Secrets in Git committen!**

## 📡 Network Migration Notes

**Cluster migrated from WLAN to Ethernet (Dec 1, 2025)**

All Pis now connected via Ethernet in Keller:
- Ethernet cables connected
- WLAN disabled on all Pis
- K3s flannel interface changed to eth0
- All services running stable on wired network

Performance improvements:
- Lower latency
- More stable connections
- Better throughput for storage (Longhorn)

## 🎉 Current Status: PRODUCTION-READY!

### Deployed Services:
- **Pi-hole v2025**: DNS + Ad-Blocking (192.168.1.225)
- **Home Assistant v2025**: Smart Home (192.168.1.223)
- **Jellyfin**: Media Server with 2x USB3 HDDs (192.168.1.224)
- **MQTT**: IoT Message Broker (192.168.1.222)
- **Portainer**: Kubernetes Management (192.168.1.227:9443)

### Automation:
- **ArgoCD**: GitOps deployment from GitHub
- **Renovate**: Automatic dependency updates via PRs
- **MetalLB**: Automatic LoadBalancer IP assignment
- **Longhorn**: Automatic storage replication

### Architecture:
- 3-Node HA Kubernetes Cluster on Ethernet
- etcd Quorum for fault tolerance
- Can survive 1 node failure
- All services follow Kubernetes Best Practices

**Last Updated**: $(date)
