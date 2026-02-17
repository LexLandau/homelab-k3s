#!/bin/bash
# ============================================================
# Jellyfin Pre-Update Backup Script
# Usage: ./backup-before-update.sh [--restore TIMESTAMP]
# ============================================================

set -e

BACKUP_ROOT="/mnt/media/backup/jellyfin-backups"
NAMESPACE="jellyfin"
DEPLOYMENT="jellyfin"
KEEP=5

# ---- Colors ----
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_step() { echo -e "${GREEN}▶ $1${NC}"; }
print_warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_err()  { echo -e "${RED}✗ $1${NC}"; }

# ============================================================
# RESTORE MODE
# ============================================================
if [[ "$1" == "--restore" ]]; then
  TIMESTAMP="${2}"
  if [[ -z "$TIMESTAMP" ]]; then
    echo "Available backups:"
    ls -1 "${BACKUP_ROOT}" 2>/dev/null | grep "^[0-9]" | sort -r
    echo ""
    read -p "Enter timestamp to restore (e.g. 20260117_030012): " TIMESTAMP
  fi

  RESTORE_DIR="${BACKUP_ROOT}/${TIMESTAMP}"

  if [[ ! -d "$RESTORE_DIR" ]]; then
    print_err "Backup not found: ${RESTORE_DIR}"
    exit 1
  fi

  echo ""
  cat "${RESTORE_DIR}/backup-info.txt" 2>/dev/null || true
  echo ""
  print_warn "This will REPLACE the current Jellyfin data with the backup from ${TIMESTAMP}!"
  read -p "Are you sure? (yes/no): " CONFIRM
  [[ "$CONFIRM" != "yes" ]] && { echo "Aborted."; exit 0; }

  print_step "Scaling down Jellyfin..."
  kubectl scale deployment $DEPLOYMENT -n $NAMESPACE --replicas=0
  kubectl wait --for=delete pod -l app=jellyfin -n $NAMESPACE --timeout=120s || true

  # We need a temporary pod to access the PVC
  print_step "Starting restore pod..."
  kubectl run jellyfin-restore --rm -it --restart=Never \
    --image=alpine:latest \
    --overrides='{
      "spec": {
        "nodeSelector": {"kubernetes.io/hostname": "rpi5"},
        "volumes": [
          {"name":"config","persistentVolumeClaim":{"claimName":"jellyfin-config-nvme"}},
          {"name":"cache","persistentVolumeClaim":{"claimName":"jellyfin-cache-nvme"}},
          {"name":"backup","hostPath":{"path":"/mnt/media/backup"}}
        ],
        "containers": [{
          "name":"restore",
          "image":"alpine:latest",
          "command":["sh","-c","rm -rf /mnt/config/* && cp -a /mnt/backup/jellyfin-backups/'${TIMESTAMP}'/config/. /mnt/config/ && rm -rf /mnt/cache/* && cp -a /mnt/backup/jellyfin-backups/'${TIMESTAMP}'/cache/. /mnt/cache/ && echo DONE"],
          "volumeMounts":[
            {"name":"config","mountPath":"/mnt/config"},
            {"name":"cache","mountPath":"/mnt/cache"},
            {"name":"backup","mountPath":"/mnt/backup"}
          ]
        }]
      }
    }' -n $NAMESPACE 2>&1 | grep -v "^If"

  print_step "Scaling Jellyfin back up..."
  kubectl scale deployment $DEPLOYMENT -n $NAMESPACE --replicas=1
  kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=300s

  print_step "✅ Restore complete! Jellyfin restored from ${TIMESTAMP}"
  exit 0
fi

# ============================================================
# BACKUP MODE (default)
# ============================================================

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"

echo ""
echo "========================================"
echo "  Jellyfin Pre-Update Backup"
echo "  Timestamp: ${TIMESTAMP}"
echo "========================================"
echo ""

# Check if running on rpi5 (backup HDD is there)
if [[ ! -d "/mnt/media/backup" ]]; then
  print_err "Run this script on rpi5 (backup HDD not found at /mnt/media/backup)"
  print_warn "SSH to rpi5 first: ssh alex@192.168.1.10"
  exit 1
fi

print_step "Scaling down Jellyfin (replicas=0)..."
kubectl scale deployment $DEPLOYMENT -n $NAMESPACE --replicas=0
echo "Waiting for pod to stop..."
kubectl wait --for=delete pod -l app=jellyfin -n $NAMESPACE --timeout=120s || true
echo "✓ Jellyfin stopped"

# Ensure scale-up happens on exit (even on error)
trap 'print_warn "Scaling Jellyfin back up (trap)..."; kubectl scale deployment '"$DEPLOYMENT"' -n '"$NAMESPACE"' --replicas=1' EXIT

print_step "Creating backup directory: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/config" "${BACKUP_DIR}/cache"

print_step "Mounting PVCs via temporary pod and copying data..."
# Use kubectl cp via a temporary pod
kubectl run jellyfin-backup-tmp --restart=Never \
  --image=alpine:latest \
  --overrides='{
    "spec": {
      "nodeSelector": {"kubernetes.io/hostname": "rpi5"},
      "volumes": [
        {"name":"config","persistentVolumeClaim":{"claimName":"jellyfin-config-nvme"}},
        {"name":"cache","persistentVolumeClaim":{"claimName":"jellyfin-cache-nvme"}}
      ],
      "containers": [{
        "name":"backup",
        "image":"alpine:latest",
        "command":["sleep","3600"],
        "volumeMounts":[
          {"name":"config","mountPath":"/mnt/config"},
          {"name":"cache","mountPath":"/mnt/cache"}
        ]
      }]
    }
  }' -n $NAMESPACE

echo "Waiting for backup pod..."
kubectl wait --for=condition=Ready pod/jellyfin-backup-tmp -n $NAMESPACE --timeout=60s

print_step "Copying Config PVC..."
kubectl cp $NAMESPACE/jellyfin-backup-tmp:/mnt/config "${BACKUP_DIR}/config"
CONFIG_SIZE=$(du -sh "${BACKUP_DIR}/config" | cut -f1)
echo "  Config: ${CONFIG_SIZE}"

print_step "Copying Cache PVC..."
kubectl cp $NAMESPACE/jellyfin-backup-tmp:/mnt/cache "${BACKUP_DIR}/cache"
CACHE_SIZE=$(du -sh "${BACKUP_DIR}/cache" | cut -f1)
echo "  Cache: ${CACHE_SIZE}"

print_step "Cleaning up backup pod..."
kubectl delete pod jellyfin-backup-tmp -n $NAMESPACE --grace-period=0

# Write metadata
cat > "${BACKUP_DIR}/backup-info.txt" << EOF
Timestamp: ${TIMESTAMP}
Date: $(date)
Config Size: ${CONFIG_SIZE}
Cache Size: ${CACHE_SIZE}
Trigger: Manual pre-update backup
EOF

print_step "Rotating old backups (keeping ${KEEP})..."
ls -1d "${BACKUP_ROOT}"/[0-9]* 2>/dev/null | sort | head -n -${KEEP} | while read OLD; do
  echo "  Deleting: ${OLD}"
  rm -rf "${OLD}"
done

echo ""
echo "========================================"
echo "  ✅ Backup complete!"
echo "  Location: ${BACKUP_DIR}"
echo "  Config:   ${CONFIG_SIZE}"
echo "  Cache:    ${CACHE_SIZE}"
echo ""
echo "  Current backups:"
ls -1 "${BACKUP_ROOT}" | grep "^[0-9]" | sort -r | head -10
echo "========================================"
echo ""
echo "  Now update Jellyfin. If something breaks:"
echo "  ./backup-before-update.sh --restore ${TIMESTAMP}"
echo ""

# trap handles scale-up
