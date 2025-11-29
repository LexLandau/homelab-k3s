# Longhorn Replica Node Redundancy Fix

January 2026

## Problem

Several volumes had both replicas on the same node, providing no redundancy against node failure.

Affected volumes:
- mosquitto-data: 2x rpi4
- alertmanager: 1x rpi5 only
- config-pihole-0: 2x rpi4-cm4
- terraria-data: 2x rpi4
- grafana: 2x rpi4
- dnsmasq-pihole-0: 2x rpi4-cm4

## Cause

Longhorn attempts to distribute replicas across nodes, but when replicas fail and are recreated, they may end up on the same node if one node has more available space.

## Solution

Manual replica creation on a different node.

### Key Points

1. The replica `spec.image` must match `volume.status.currentImage` (not `volume.spec.image`)

2. The `diskID` is the UUID directly from the node's disk status

3. Disk UUIDs:
   - rpi5: `6b448614-d360-4b48-826d-22dafcf29634`
   - rpi4-cm4: `8b8c8597-a9f8-4bf4-b7d1-f77b3117970f`
   - rpi4: `fc0d7213-3bb0-477d-8af2-4c64ddee013a`

### Replica YAML Template

```yaml
apiVersion: longhorn.io/v1beta2
kind: Replica
metadata:
  name: <volume>-r-<node>-manual
  namespace: longhorn-system
  labels:
    longhornvolume: <volume>
    longhorndiskuuid: <disk-uuid>
    longhornnode: <node>
spec:
  active: true
  dataDirectoryName: <volume>-<node>-manual
  dataEngine: v1
  desireState: running
  diskID: <disk-uuid>
  diskPath: /var/lib/longhorn/
  engineName: <volume>-e-0
  image: <volume.status.currentImage>
  nodeID: <node>
  revisionCounterDisabled: true
  snapshotMaxCount: 250
  volumeName: <volume>
  volumeSize: "<size in bytes>"
```

### Procedure

1. Check current replica locations:
   ```bash
   kubectl get replicas -n longhorn-system -l longhornvolume=<vol> -o wide
   ```

2. Delete one replica from the node that has duplicates

3. Create new replica on a different node using the template above

4. Wait for engine to rebuild the replica

## Verification Script

Check if all volumes have replicas on multiple nodes:

```bash
for vol in $(kubectl get volumes.longhorn.io -n longhorn-system -o jsonpath='{.items[*].metadata.name}'); do
  NODES=$(kubectl get replicas -n longhorn-system -l longhornvolume=$vol \
    -o jsonpath='{range .items[?(@.status.currentState=="running")]}{.spec.nodeID}{"\n"}{end}' | sort -u)
  UNIQUE=$(echo "$NODES" | wc -l)
  if [ "$UNIQUE" -lt 2 ]; then
    echo "WARNING: $vol has only $UNIQUE unique node(s)"
  fi
done
```

## Result

After fix: 15/15 volumes healthy with replicas distributed across at least 2 different nodes.
