# Pi-hole HA Setup

3-replica StatefulSet with nebula-sync for configuration synchronization.

## Architecture

```
MetalLB LoadBalancer
  |
  +-- 192.168.1.225 (DNS) --> all 3 pods
  +-- 192.168.1.220 (Web) --> pihole-0 only
  
pihole-0 (Primary) <-- make config changes here
pihole-1 (Replica)  \
pihole-2 (Replica)  /-- synced by nebula-sync
```

## Services

| Service | IP | Purpose |
|---------|-----|---------|
| pihole-dns | .225:53 | DNS, load balanced across all pods |
| pihole-web | .220:80 | Web UI, pihole-0 only |
| pihole-headless | - | Internal StatefulSet DNS |

## Configuration

Always use http://192.168.1.220/admin for configuration changes. This points to pihole-0.

nebula-sync copies changes to other replicas every 5 minutes.

## nebula-sync Secret

Create manually:

```bash
kubectl create secret generic nebula-sync-env -n pihole \
  --from-literal=PRIMARY="http://pihole-0.pihole-headless.pihole.svc.cluster.local|PASSWORD" \
  --from-literal=REPLICAS="http://pihole-1.pihole-headless.pihole.svc.cluster.local|PASSWORD,http://pihole-2.pihole-headless.pihole.svc.cluster.local|PASSWORD"
```

## Performance Settings

In `pihole-FTL.conf`:
- `MAXDBDAYS=1` - retain query log for 1 day only
- `DBINTERVAL=30.0` - database writes every 30 seconds

Without these settings, the database grows large and UI becomes slow.

## Storage

Each pod has separate PVCs:
- config-pihole-{0,1,2}: 2Gi
- dnsmasq-pihole-{0,1,2}: 1Gi

StorageClass: longhorn-fast (2 replicas)

## Debugging

```bash
kubectl logs -n pihole pihole-0 -f
kubectl logs -n pihole -l app=nebula-sync -f
dig @192.168.1.225 google.com
```
