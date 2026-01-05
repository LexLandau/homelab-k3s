# Longhorn Storage Optimization

## Configuration for 3-Node Raspberry Pi Cluster

Optimized on January 5, 2026 to resolve replica scheduling issues and Grafana "No Data" problem.

## Problem Summary

- Grafana showed "No Data" for all dashboards
- Prometheus PVC was 100% full (10Gi)
- 5 Longhorn volumes were in "degraded" state
- Replica scheduling was failing due to strict anti-affinity

## Settings Applied

```bash
# Allow replicas on same node when necessary (was false)
kubectl patch settings replica-soft-anti-affinity -n longhorn-system --type='merge' -p '{"value": "true"}'

# Reduce default replicas from 3 to 2
kubectl patch settings default-replica-count -n longhorn-system --type='merge' -p '{"value": "{\"v1\":\"2\",\"v2\":\"2\"}"}'

# Enable auto-balancing (already was best-effort)
kubectl patch settings replica-auto-balance -n longhorn-system --type='merge' -p '{"value": "best-effort"}'
```

## Current Settings Summary

| Setting | Value | Description |
|---------|-------|-------------|
| `replica-soft-anti-affinity` | `true` | Allow replicas on same node if needed |
| `default-replica-count` | `2` | Default replicas for new volumes |
| `replica-auto-balance` | `best-effort` | Auto-distribute replicas |
| `storage-over-provisioning-percentage` | `100` | Allow 2x over-provisioning |
| `storage-minimal-available-percentage` | `25` | Reserve 25% disk space |
| `storage-reserved-percentage-for-default-disk` | `30` | Reserve 30% for system |

## Why 2 Replicas Instead of 3?

On a 3-node cluster with 3 replicas:
- Every node MUST have a copy of every volume
- If any node has disk issues → volume becomes degraded
- If one node is down for maintenance → cannot rebuild replicas
- No scheduling flexibility

With 2 replicas:
- Data is still fault-tolerant (survives 1 node failure)
- Longhorn can choose optimal 2 of 3 nodes for placement
- Better disk utilization across cluster
- ~33% storage savings

### Storage Savings Achieved

| Before (3 replicas) | After (2 replicas) | Saved |
|---------------------|---------------------|-------|
| 20Gi × 3 = 60Gi | 20Gi × 2 = 40Gi | 20Gi |
| Per volume | Per volume | 33% |

Total saved across 15 volumes: ~15-20Gi

## Reducing Replicas on Existing Volumes

```bash
# List all volumes with replica count
kubectl get volumes -n longhorn-system -o custom-columns=NAME:.metadata.name,REPLICAS:.spec.numberOfReplicas,ROBUSTNESS:.status.robustness

# Reduce specific volume to 2 replicas
kubectl patch volume <pvc-uuid> -n longhorn-system --type='merge' -p '{"spec":{"numberOfReplicas":2}}'

# Batch reduce all volumes with 3 replicas
for vol in $(kubectl get volumes -n longhorn-system -o jsonpath='{.items[?(@.spec.numberOfReplicas==3)].metadata.name}'); do
  echo "Reducing $vol to 2 replicas..."
  kubectl patch volume $vol -n longhorn-system --type='merge' -p '{"spec":{"numberOfReplicas":2}}'
done
```

## Cleaning Up Stopped/Failed Replicas

Stopped replicas can block new replica scheduling:

```bash
# Find stopped replicas
kubectl get replicas -n longhorn-system | grep -E "(stopped|failed)"

# Delete specific stopped replica
kubectl delete replica <replica-name> -n longhorn-system

# Delete all stopped replicas (careful!)
kubectl get replicas -n longhorn-system -o json | \
  jq -r '.items[] | select(.status.currentState=="stopped") | .metadata.name' | \
  xargs -I {} kubectl delete replica {} -n longhorn-system
```

## Node Disk Status

```bash
# Check disk space on each node
kubectl get nodes.longhorn.io -n longhorn-system -o custom-columns=\
NAME:.metadata.name,\
SCHEDULABLE:.spec.allowScheduling,\
STORAGE:.status.diskStatus.*.storageAvailable

# Detailed disk info
kubectl get nodes.longhorn.io -n longhorn-system rpi5 -o yaml
```

### Current Node Status

| Node | Storage Available | Schedulable |
|------|-------------------|-------------|
| rpi5 | 417GB (NVMe) | ✅ Yes |
| rpi4-cm4 | 385GB (NVMe) | ✅ Yes |
| rpi4 | 72GB (SSD) | ✅ Yes |

## Troubleshooting

### Volume Stuck in "Degraded" State

1. **Check replica status:**
   ```bash
   kubectl get replicas -n longhorn-system -l longhornvolume=<volume-name>
   ```

2. **Check if stopped replicas are blocking:**
   ```bash
   kubectl get replicas -n longhorn-system -l longhornvolume=<volume-name> | grep stopped
   # Delete if found
   ```

3. **Verify settings:**
   ```bash
   kubectl get settings replica-soft-anti-affinity -n longhorn-system -o jsonpath='{.value}'
   # Should be "true"
   ```

4. **Check node disk space:**
   ```bash
   kubectl get nodes.longhorn.io -n longhorn-system -o yaml | grep -A5 storageAvailable
   ```

### Replica Won't Schedule

Common causes:
1. `replica-soft-anti-affinity` is `false` → set to `true`
2. Node disk is full → check with `df -h` on node
3. Stopped replica exists → delete it
4. Volume has 3 replicas on 3-node cluster → reduce to 2

### PVC Expansion Fails

If expanding a PVC fails with "cannot expand volume before replica scheduling success":

1. First fix replica scheduling (steps above)
2. Wait for volume to become "healthy"
3. Then retry PVC expansion

## Monitoring Longhorn Health

```bash
# Quick health check
kubectl get volumes -n longhorn-system -o custom-columns=NAME:.metadata.name,ROBUSTNESS:.status.robustness | grep -v healthy

# Watch volume status
watch -n5 'kubectl get volumes -n longhorn-system -o custom-columns=NAME:.metadata.name,ROBUSTNESS:.status.robustness'

# Check Longhorn manager logs
kubectl logs -n longhorn-system -l app=longhorn-manager --tail=100
```

## References

- [Longhorn Best Practices](https://longhorn.io/docs/latest/best-practices/)
- [Longhorn Settings Reference](https://longhorn.io/docs/latest/references/settings/)
- [Longhorn Troubleshooting](https://longhorn.io/docs/latest/troubleshooting/)
