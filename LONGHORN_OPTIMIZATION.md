# Longhorn Storage Optimization

Notes from January 2026 after fixing degraded volumes and Prometheus storage issues.

## Problem

Several volumes were degraded. Prometheus PVC was full (10Gi, 100% used). Replicas could not be scheduled.

## Root Cause

With 3 replicas on a 3-node cluster, every node must hold a copy of every volume. If any node has insufficient disk space, Longhorn cannot schedule new replicas and volumes remain degraded.

## Solution

### Settings Changed

```bash
# Allow replicas on same node when necessary (was false)
kubectl patch settings replica-soft-anti-affinity -n longhorn-system --type='merge' -p '{"value": "true"}'

# Reduce default replicas from 3 to 2
kubectl patch settings default-replica-count -n longhorn-system --type='merge' -p '{"value": "{\"v1\":\"2\",\"v2\":\"2\"}"}'
```

### Migrate Existing Volumes to 2 Replicas

Single volume:
```bash
kubectl patch volume <pvc-uuid> -n longhorn-system --type='merge' -p '{"spec":{"numberOfReplicas":2}}'
```

All volumes with 3 replicas:
```bash
for vol in $(kubectl get volumes -n longhorn-system -o jsonpath='{.items[?(@.spec.numberOfReplicas==3)].metadata.name}'); do
  kubectl patch volume $vol -n longhorn-system --type='merge' -p '{"spec":{"numberOfReplicas":2}}'
done
```

### Clean Up Stopped Replicas

Stopped replicas can block scheduling:
```bash
kubectl get replicas -n longhorn-system | grep stopped
kubectl delete replica <name> -n longhorn-system
```

## Why 2 Replicas

- Data remains on 2 nodes, survives single node failure
- Longhorn can choose optimal placement from 3 nodes
- Reduces storage overhead by ~33%

With 3 replicas on 3 nodes, there is no scheduling flexibility.

## Current Settings

| Setting | Value |
|---------|-------|
| replica-soft-anti-affinity | true |
| default-replica-count | 2 |
| replica-auto-balance | best-effort |

## Disk UUIDs

For manual replica creation (see docs/LONGHORN_REPLICA_FIX.md):

- rpi5: `6b448614-d360-4b48-826d-22dafcf29634`
- rpi4-cm4: `8b8c8597-a9f8-4bf4-b7d1-f77b3117970f`
- rpi4: `fc0d7213-3bb0-477d-8af2-4c64ddee013a`

## Troubleshooting

Volume stays degraded:
1. Check replica locations: `kubectl get replicas -n longhorn-system -l longhornvolume=<vol>`
2. Delete stopped replicas if present
3. Verify soft-anti-affinity is enabled
4. Check disk space on target node
