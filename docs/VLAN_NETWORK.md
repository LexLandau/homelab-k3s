# Netzwerksegmentierung (VLAN)

Stand: 02.10.2026

## Ziel

Umbau vom flachen Netz `192.168.1.0/24` auf getrennte VLANs (IEEE 802.1Q). OPNsense routet zwischen den VLANs und stellt Firewall, DHCP und DNS bereit. Die MikroTik-Switches führen die VLANs als Trunks.

## VLANs

| VLAN | Name | Netz | Zweck | DHCP |
|------|------|------|-------|------|
| 1 | Legacy | 192.168.1.0/24 | Altes Netz, nur noch Übergang | ja |
| 10 | MGMT | 10.10.10.0/24 | Switches, AP, iLO | nein, statisch |
| 20 | SERVER | 10.10.20.0/24 | K3s, Storage, MetalLB, Hyper-V | nein, statisch |
| 30 | TRUSTED | 10.10.30.0/24 | Familiengeräte | ja |
| 40 | IOT | 10.10.40.0/24 | Smart Home, Sonos, TV | ja |
| 50 | GUEST | 10.10.50.0/24 | Gäste, isoliert | ja |
| 60 | LAB | 10.10.60.0/24 | Testsysteme, Gameserver | ja |

## Hardware und Dienste

| Komponente | Details |
|------------|---------|
| Firewall | OPNsense auf Atom C3758 (4x 10G SFP+, 4x 2,5G), WAN auf `ix1` |
| Internet | Vodafone Kabel 1 Gbit/s, eigene IPv4, IPv6 noch aus |
| Core-Switch | MikroTik CRS312, STP Root Bridge |
| Access-Switches | 3x MikroTik CRS310 (Keller, Schlafzimmer, Wohnzimmer) |
| WLAN | Zyxel NWA130BE, Standalone, ein VLAN pro SSID |
| Hypervisor | Hyper-V, LBFO-Team (LACP), iLO |
| DHCP | Dnsmasq (OPNsense) |
| DNS | AdGuard Home (OPNsense), Domain `home.arpa` (RFC 8375) |
| Plugins | udpbroadcastrelay, miniupnpd (os-upnp), AdGuard Home, Zenarmor |

## Firewall (Zielzustand)

| Von | Nach | Regel |
|-----|------|-------|
| TRUSTED | SERVER | nur benötigte Ports (Jellyfin, HA, SMB, Drucker, Monitoring) |
| TRUSTED | IOT | Sonos, Yeelight |
| TRUSTED | LAB | Gameserver-Ports |
| IOT | SERVER | MQTT, HA-API |
| IOT | Internet | 80/443 |
| IOT | fremder DNS | Umleitung auf AdGuard (NAT) |
| Internet | LAB | Port-Forwarding (NAT) nur für die Gameserver-Ports |
| LAB | Internet | erlaubt |
| GUEST | Internet | 80/443 |
| LAB, GUEST | intern | **gesperrt** |

## Firewall (Ist)

- VLAN 30 und 40: Regeln per CSV-Import, Allow-All entfernt
- VLAN 40: NAT-Regel leitet DNS (TCP/UDP 53) an externe Ziele auf `127.0.0.1:53` um
- Restliche VLANs: noch Allow-All

Temporäre Regeln, später löschen:

- VLAN 30 → `192.168.1.134` (AP), bis AP in VLAN 10 ist
- TEMP-Regeln für `192.168.1.220/28` und `192.168.1.236/30` (MetalLB), bis K3s in VLAN 20 ist
- doppelte Floating-Regeln für Sonos

## Sonos über VLAN-Grenzen

Sonos findet Geräte per SSDP (UDP 1900, Multicast `239.255.255.250`, TTL 1). Ein IGMP-Proxy reicht deshalb nicht. Lösung: `udpbroadcastrelay` zwischen VLAN 30 und 40.

- Ports: UDP 1900 (`--msearch proxy`) und UDP 6969
- Start über `/usr/local/etc/rc.syshook.d/start/99-sonos-relay` mit `sleep 15`
- Flag `-d` ist Pflicht, sonst klappt der Multicast-Join nicht
- GUI-Instanz für Port 1900 bleibt deaktiviert
- IGMP Snooping auf den Switches (prüfen)

## Vorgehen bei der Migration

Gerät für Gerät, Ausfall unter 1 Minute, Rückweg über alte PVID.

1. OPNsense: DHCP-Reservierung und Regeln
2. MikroTik: Port untagged (Endgerät) oder tagged (Trunk, Host mit VLAN)
3. Gerät: VLAN-Einstellung (SSID, Hyper-V-vNIC)

## Status

- [x] Phase 0: IP-Konflikte gelöst, Pi-hole durch AdGuard ersetzt
- [x] Phase 1A: VLAN-Interfaces, DHCP, Firewall (Allow-All) auf OPNsense
- [x] Phase 1B: VLAN-Trunks auf allen MikroTik
- [x] Phase 3: Test-PC in VLAN 30 (`10.10.30.10`)
- [ ] Phase 4: Server nach VLAN 20 (läuft)
  - [ ] Hyper-V-Host
  - [ ] K3s und MetalLB
  - [ ] Routing VLAN 1 ↔ VLAN 20 für die Übergangszeit
- [ ] Phase 5: IoT nach VLAN 40 (fast fertig)
  - [x] 6x Sonos (`10.10.40.20` bis `.26`)
  - [x] Sonos-Relay
  - [x] IoT-SSID
  - [x] DNS-Umleitung
  - [ ] restliche IoT-Geräte
- [ ] Phase 6: WLAN
  - [x] SSID VLAN 40
  - [ ] SSIDs VLAN 30 und 50
  - [ ] AP-Management nach VLAN 10
  - [ ] RADIUS / dynamische VLANs (offen)
- [ ] Phase 7: alle restlichen Geräte
- [ ] Phase 8: Firewall härten (VLAN 30 und 40 fertig)

## Offen

- AP nach VLAN 10: Switch-PVID und AP-Management-VLAN gleichzeitig umstellen, sonst Aussperrung
- LBFO durch SET ersetzen (LBFO mit Hyper-V seit Server 2022 abgekündigt, SET kann kein LACP)
- VLAN 40 aus miniupnpd entfernen (Sonos braucht kein Port-Mapping)
- Gaming-PC im WLAN aus VLAN 40 holen (Discord und Minecraft gehen dort nicht), Ziel: Internet ja, intern nein
- Nach OPNsense-Updates: GUI-Relay Port 1900 weiter aus?
- IPv6 einrichten

## Stolperfallen

| Wo | Problem | Lösung |
|----|---------|--------|
| NWA130BE | Clients bekommen APIPA | VLAN-Eintrag mit `lan1` tagged anlegen, bevor die SSID aktiv wird |
| MikroTik | getaggte Frames werden verworfen | Port muss tagged Member sein, PVID allein reicht nicht |
| Hyper-V | Host offline nach VLAN-Umstellung | "VLAN-ID für Verwaltungsbetriebssystem" sendet getaggt, Switch-Port erwartet untagged |
| OPNsense | Heredocs und Umleitungen kaputt | `sh` statt `tcsh` nutzen |
| miniupnpd | `interface index not matching` | harmlos, kommt vom Relay |
| Firewall | Aussperrung | WebUI/SSH-Regeln für VLAN-Gateway und alte LAN-IP anlegen |

Fehlersuche: erst Layer 2 (MikroTik Host-Tabelle, VID), dann Layer 3 (`tcpdump` auf dem VLAN-Interface).
