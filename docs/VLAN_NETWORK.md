# Network Segmentation (VLAN)

## Overview

The homelab network is segmented into multiple VLANs for security isolation, managed by OPNsense firewall and MikroTik switches.

## VLAN Design

| VLAN | Purpose | DHCP |
|------|---------|------|
| 1 | Legacy (migration transitional) | Yes |
| 10 | Management (switches, AP, iLO) | No — static only |
| 20 | Server (K3s cluster, storage, MetalLB) | No — static only |
| 30 | Trusted (family devices) | Yes |
| 40 | IoT (smart home, media) | Yes |
| 50 | Guest (isolated) | Yes |
| 60 | Untrusted Lab (test machines, game servers) | Yes |

## Architecture

- **Firewall**: OPNsense (VLAN gateway + DHCP + DNS via AdGuard Home)
- **Core Switch**: MikroTik CRS312 (10Gb SFP+ trunks)
- **Access Switches**: 3x MikroTik CRS310 (Basement, Bedroom, Living Room)
- **WiFi**: Zyxel NWA130BE with RADIUS/dynamic VLAN assignment
- **DNS Domain**: `home.arpa` (RFC 8375)

## Firewall Policy (Target State)

| Source | Destination | Policy |
|--------|-------------|--------|
| Trusted → Server | Jellyfin, HA, SMB, Printer, Monitoring | Allow specific ports |
| Trusted → IoT | Sonos control, Yeelight, mDNS relay | Allow specific ports |
| IoT → Server | MQTT, HA API | Allow specific ports |
| IoT → Internet | Cloud services (Alexa, Hue, Nest, Sonos) | Allow 80/443 |
| Untrusted → Internet | Web + game server ports | Allow |
| Trusted → Untrusted | Game server access | Allow specific ports |
| Untrusted → any internal | — | **DENY** |
| Guest → Internet | Web only | Allow 80/443 |
| Guest → any internal | — | **DENY** |

## Cross-VLAN Service Discovery

- **Sonos/Yeelink**: OPNsense Avahi plugin as mDNS repeater (VLAN 30 ↔ 40)
- **IGMP Snooping**: Enabled on all MikroTik switches with querier on core

## Migration Strategy

Phased approach: VLAN infrastructure configured first (trunks + interfaces), all devices remain on Legacy VLAN 1 until individually migrated. Each device migration is < 1 min downtime with instant rollback by reverting PVID.

## Status

- [x] Phase 0: IP conflicts resolved, Pi-hole removed (AdGuard on OPNsense)
- [x] Phase 1A: OPNsense VLAN interfaces + DHCP + firewall (allow-all temp)
- [x] Phase 1B: MikroTik VLAN trunks (Core + 3x Access)
- [ ] Phase 3: Test with single device on VLAN 30
- [ ] Phase 4: K3s cluster migration to VLAN 20
- [ ] Phase 5: IoT migration + mDNS relay testing
- [ ] Phase 6: WiFi RADIUS setup
- [ ] Phase 7: Full device migration
- [ ] Phase 8: Firewall hardening (remove allow-all rules)
