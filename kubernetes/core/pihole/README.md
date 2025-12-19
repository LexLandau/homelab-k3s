# Pi-hole Configuration

## Version
- Pi-hole: 2025.11.1
- Image: pihole/pihole:2025.11.1

## GitOps Philosophy
**Git manages infrastructure:**
- StatefulSet, Services, Networking
- Resource limits, Persistence
- Image versions, Permissions

**Web-UI manages Pi-hole config:**
- DNS upstream servers
- Blocklists, Whitelists
- Cache size, Query logging

## Services
- DNS: 192.168.1.225:53 (TCP+UDP)
- Web-UI: http://192.168.1.220/admin

## Initial Setup
1. Open: http://192.168.1.220/admin
2. Login with password from secret
3. Settings → DNS:
   - Fritz!Box: 192.168.1.1 (DNS-over-TLS, primary)
   - Google: 8.8.8.8 (fallback)
   - Cloudflare: 1.1.1.1 (fallback)
4. Settings → System:
   - DNS Cache: 50000
5. Configure blocklists as needed

## Persistence
- Config: volumeClaimTemplate (2Gi, longhorn-fast)
- Dnsmasq: volumeClaimTemplate (1Gi, longhorn-fast)
- Settings persist across restarts

## Why minimal FTLCONF_?
FTLCONF_ variables make Web-UI read-only.
We only set password + listening mode.
Everything else via Web-UI = fully editable!

## Performance Optimizations

### Changes Made
- **Storage**: Uses `longhorn-fast` StorageClass with 2 replicas (instead of 3)
- **Query Log**: Limited to 1 day retention (`MAXDBDAYS=1`)
- **Upstream DNS**: Fritz!Box (DNS-over-TLS) → Google DNS → Cloudflare DNS

### Results
- UI save time: **10-12s → 3s** (70% improvement)
- Database size: **100MB+ → 96KB** (99.9% reduction)
- DNS cache hits: **0ms** consistently
- Write performance: **60 MB/s** average
- Storage overhead: **33% reduction** (2 replicas vs 3)
- No more "stale answer" warnings

### Technical Details
The massive performance improvement came from two factors:
1. Reducing Longhorn replicas from 3 to 2 (less network overhead)
2. Limiting query log retention to 1 day (database stayed at 365k rows, causing 10s restarts)

The database size was the primary bottleneck - Pi-hole loads ALL queries from disk on every restart (which happens on every settings save).
