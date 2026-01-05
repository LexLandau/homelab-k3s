# Longhorn Replica Node-Redundanz Fix

## Problem (5. Januar 2026)

Mehrere Longhorn Volumes hatten alle Replicas auf dem gleichen Node - keine Node-Redundanz. Bei Node-Ausfall wären diese Daten verloren gegangen.

### Betroffene Volumes
| Volume | Problem | Lösung |
|--------|---------|--------|
| mosquitto-data | 2x rpi4 | rpi4 + rpi5 |
| alertmanager-kube-prometheus-stack | 1x rpi5 | rpi4 + rpi5 |
| config-pihole-0 | 2x rpi4-cm4 | rpi4-cm4 + rpi5 |
| terraria-data | 2x rpi4 | rpi4 + rpi4-cm4 |
| kube-prometheus-stack-grafana | 2x rpi4 | rpi4 + rpi5 |
| dnsmasq-pihole-0 | 2x rpi4-cm4 | rpi4-cm4 + rpi5 |

## Root Cause

Longhorn's Scheduler berücksichtigt Node-Redundanz, aber wenn ein Node voll ist oder Replicas fehlschlagen, können beide Replicas auf dem gleichen Node landen.

## Lösung: Manuelle Replica-Erstellung

### Wichtige Erkenntnisse

1. **Engine Image Version MUSS matchen**: Die Replica `spec.image` muss `volume.status.currentImage` entsprechen (NICHT `volume.spec.image`!)

2. **diskID ist die UUID direkt**: Kein Prefix, direkt die UUID aus dem Node's diskStatus verwenden

3. **Disk UUIDs der Nodes**:
   - rpi5: `6b448614-d360-4b48-826d-22dafcf29634`
   - rpi4-cm4: `8b8c8597-a9f8-4bf4-b7d1-f77b3117970f`
   - rpi4: `fc0d7213-3bb0-477d-8af2-4c64ddee013a`

### Replica Template
```yaml
apiVersion: longhorn.io/v1beta2
kind: Replica
metadata:
  name: <volume-name>-r-<target-node>-manual
  namespace: longhorn-system
  labels:
    longhornvolume: <volume-name>
    longhorndiskuuid: <disk-uuid>
    longhornnode: <target-node>
spec:
  active: true
  dataDirectoryName: <volume-name>-<target-node>-manual
  dataEngine: v1
  desireState: running
  diskID: <disk-uuid>
  diskPath: /var/lib/longhorn/
  engineName: <volume-name>-e-0
  image: <volume.status.currentImage>  # WICHTIG: currentImage, nicht spec.image!
  nodeID: <target-node>
  revisionCounterDisabled: true
  snapshotMaxCount: 250
  volumeName: <volume-name>
  volumeSize: "<size-in-bytes>"
```

### Prozess

1. **Volume Image prüfen**:
```bash
   kubectl get volumes.longhorn.io <vol> -n longhorn-system -o jsonpath='{.status.currentImage}'
```

2. **Bestehende Replicas prüfen**:
```bash
   kubectl get replicas -n longhorn-system -l longhornvolume=<vol> -o wide
```

3. **Eine Replica auf dem überfüllten Node löschen** (falls 2 auf gleichem Node)

4. **Neue Replica auf anderem Node erstellen** (mit korrektem Image!)

5. **Warten bis Engine die Replica erkennt** (RW Mode in replicaModeMap)

## Präventive Maßnahmen

### Node-Redundanz Check Script
```bash
for vol in $(kubectl get volumes.longhorn.io -n longhorn-system -o jsonpath='{.items[*].metadata.name}'); do
  NODES=$(kubectl get replicas -n longhorn-system -l longhornvolume=$vol \
    -o jsonpath='{range .items[?(@.status.currentState=="running")]}{.spec.nodeID}{"\n"}{end}' | sort -u)
  UNIQUE=$(echo "$NODES" | wc -l)
  if [ "$UNIQUE" -lt 2 ]; then
    echo "⚠️  $vol: nur $UNIQUE unique Node(s)"
  fi
done
```

## Ergebnis

Nach dem Fix:
- **15/15 Volumes healthy** ✅
- **15/15 Volumes node-redundant** ✅
- **Cluster überlebt Ausfall eines beliebigen Nodes** ✅

### Storage Distribution
- rpi5: 14 replicas (~73 GiB)
- rpi4-cm4: 10 replicas (~54 GiB)
- rpi4: 6 replicas (~29 GiB)
