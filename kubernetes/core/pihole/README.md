# Pi-hole High Availability Configuration

## Architecture
```
                    ┌─────────────────────────────────┐
                    │    MetalLB LoadBalancer         │
                    │      192.168.1.225 (DNS)        │
                    │      192.168.1.220 (Web Admin)  │
                    └────────────┬────────────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              ▼                                     ▼
    ┌──────────────────┐                 ┌──────────────────┐
    │   pihole-0       │                 │   pihole-1       │
    │   (Primary)      │ ◄─────────────► │   (Replica)      │
    │   Node: auto     │   nebula-sync   │   Node: auto     │
    └──────────────────┘   (5 min)       └──────────────────┘
```

## Components

### StatefulSet (2 Replicas)
- **pihole-0**: Primary instance - make config changes here
- **pihole-1**: Replica instance - auto-synced from primary
- **podAntiAffinity**: Ensures pods run on different nodes

### Services
| Service | IP | Purpose |
|---------|-----|---------|
| pihole-dns | 192.168.1.225:53 | DNS (both pods, HA) |
| pihole-web | 192.168.1.220:80 | Web Admin (pihole-0 only) |
| pihole-headless | None | Internal StatefulSet DNS |

### Nebula-Sync
- Syncs blocklists, whitelists, DNS records every 5 minutes
- Primary → Replica direction only
- Runs `gravity` after sync to apply changes

## Usage

### Access Web Admin
```
http://192.168.1.220/admin
```
Always use this IP for configuration - it points to pihole-0 (Primary).

### DNS Configuration (Fritz!Box)
Set DNS server in DHCP settings to: `192.168.1.225`

### Verify HA Status
```bash
# Check both pods running on different nodes
kubectl get pods -n pihole -o wide

# Test DNS failover
kubectl delete pod pihole-0 -n pihole
# DNS should continue working via pihole-1
```

### Check Sync Status
```bash
kubectl logs -n pihole -l app=nebula-sync -f
```

## Failover Behavior

1. **Node failure**: Pod restarts on same node, DNS served by other pod
2. **Pod crash**: Kubernetes restarts pod, ~30s failover
3. **Config changes**: Make on 192.168.1.220, synced to replica in ≤5 min

## Storage

Each pod has independent Longhorn volumes:
- `config-pihole-0`, `config-pihole-1` (2Gi each)
- `dnsmasq-pihole-0`, `dnsmasq-pihole-1` (1Gi each)

This prevents SQLite locking issues.

## Version
- Pi-hole: 2025.11.1
- Nebula-Sync: latest
- Storage: longhorn-fast (2 replicas)
