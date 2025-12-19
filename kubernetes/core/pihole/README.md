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
   - Cloudflare: 1.1.1.1, 1.0.0.1
   - Quad9: 9.9.9.9
   - Fritz!Box: 192.168.1.1
4. Settings → System:
   - DNS Cache: 50000
5. Configure blocklists as needed

## Persistence
- Config: volumeClaimTemplate (2Gi)
- Dnsmasq: volumeClaimTemplate (1Gi)
- Settings persist across restarts

## Why minimal FTLCONF_?
FTLCONF_ variables make Web-UI read-only.
We only set password + listening mode.
Everything else via Web-UI = fully editable!

## Performance Optimizations
- Query log retention: 1 day (MAXDBDAYS=1)
- Storage: longhorn-fast with 2 replicas
- Reduces restart time from 10s to 3s

## Performance Optimizations

- **Query Log Retention**: 1 day (MAXDBDAYS=1) - keeps database small
- **Storage**: longhorn-fast with 2 replicas instead of 3
- **Results**: 
  - UI save time reduced from 10-12s to 3s (70% improvement)
  - Database size reduced from 100MB+ to <100KB
  - DNS cache hits at 0ms consistently
  - No more "stale answer" warnings
