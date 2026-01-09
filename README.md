# K3s Homelab Cluster

3-node HA Kubernetes cluster on Raspberry Pi hardware for self-hosted services.

## Hardware

| Node | RAM | Storage | Role |
|------|-----|---------|------|
| rpi5 | 8GB | NVMe + 3x USB HDD | Heavy workloads, media server |
| rpi4-cm4 | 4GB | NVMe | General workloads |
| rpi4 | 4GB | SSD (USB3) | Network services |

All nodes run as control plane + worker (no taints).

## Stack

- K3s v1.33.6 (Traefik and ServiceLB disabled)
- Longhorn v1.10.1 - distributed storage, 2 replicas per volume
- MetalLB v0.15.3 - L2 load balancer, IP range .220-.239
- ArgoCD v2.13.2 - GitOps deployment
- Renovate Bot - automated dependency updates

## Services

| Service | IP | Port |
|---------|-----|------|
| Pi-hole | .220 (web) / .225 (DNS) | 80 / 53 |
| Home Assistant | .223 | 8123 |
| Jellyfin | .224 | 8096 |
| MQTT | .222 | 1883 |
| Portainer | .227 | 9443 |
| Grafana | .228 | 80 |
| Uptime Kuma | .229 | 80 |

ArgoCD runs internally via port-forward only.

## Directory Structure

```
kubernetes/
  argocd/         - ArgoCD app definitions
  core/           - Pi-hole, MQTT
  apps/           - Jellyfin, Home Assistant, Portainer
  infrastructure/ - MetalLB, Longhorn
  games/          - Terraria server

ansible/          - Initial cluster setup
host-config/      - Node-specific configs (mounts, samba)
docs/             - Technical notes
```

## Deployment

All deployments are managed by ArgoCD. Push to `main` triggers sync within 3 minutes.

Manual deployment for debugging:
```bash
kubectl apply -f kubernetes/core/pihole/
```

## Storage

Longhorn runs with 2 replicas instead of 3. On a 3-node cluster, 3 replicas causes scheduling issues when any node runs low on disk space. 2 replicas still provides redundancy while allowing flexible placement.

See [LONGHORN_OPTIMIZATION.md](./LONGHORN_OPTIMIZATION.md) for details.

USB HDDs on rpi5 for media storage:
- `/mnt/media/backup` - 3.6TB, EXT4
- `/mnt/media/movies` - 1.8TB, EXT4
- `/mnt/media/series` - 1.8TB, NTFS (migration pending)

The first two drives were migrated from NTFS to EXT4. NTFS on Linux requires either the FUSE-based ntfs-3g driver (slow, high CPU usage) or the newer ntfs3 kernel driver (better, but still more overhead than native filesystems). EXT4 provides better performance and lower resource usage.

## Network

- Fritz!Box 6591 as router and DHCP server
- Pi-hole configured as DNS server in DHCP settings
- rpi5 has dual NICs: eth0 (1GbE, cluster traffic) + eth1 (2.5GbE USB adapter, SMB)
- Cisco SG350-10P managed switch

## Monitoring

Prometheus and Grafana via kube-prometheus-stack Helm chart. Runs on rpi5 due to memory requirements.

Configuration: 20Gi storage, 5 day retention, WAL compression enabled.

Access Grafana at http://192.168.1.228 (default credentials: admin/admin).

## Known Issues

- Jellyfin occasionally crashes during playback
- Series HDD still on NTFS
- Jumbo frames not working (UniFi switch compatibility issue)

## Useful Commands

```bash
# Cluster status
kubectl get nodes
kubectl top nodes

# Check Longhorn volumes
kubectl get volumes -n longhorn-system

# ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Logs
kubectl logs -n <namespace> -l app=<label> -f
```

## Secrets

Stored in 1Password, created manually as Kubernetes secrets. Includes Pi-hole admin password, ArgoCD credentials, Grafana admin password.

---

Last updated: January 2026

