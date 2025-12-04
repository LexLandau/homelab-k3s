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
