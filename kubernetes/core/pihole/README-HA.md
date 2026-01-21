# Pi-hole High Availability (HA) Setup

## Architektur
- **DaemonSet** mit 3 Pods (ein Pod pro Node)
- **hostNetwork: true** für direkte Client-IP Sichtbarkeit
- **Nebula-Sync** für automatische Konfigurationssynchronisation

## DNS Server
- **Primary**: 192.168.1.10 (rpi5)
- **Secondary**: 192.168.1.11 (rpi4-cm4)
- **Tertiary**: 192.168.1.12 (rpi4)

## Web Admin
- http://192.168.1.10/admin (Primary - für Config-Änderungen)
- http://192.168.1.11/admin (Read-only)
- http://192.168.1.12/admin (Read-only)
- http://192.168.1.220/admin (LoadBalancer - jeder Node)

## Fritz!Box Konfiguration
1. Öffne: http://192.168.1.1
2. Heimnetz → Netzwerk → Netzwerkeinstellungen
3. Lokaler DNS-Server: **192.168.1.10**
4. Übernehmen

## Deployment

### Secrets erstellen
```bash
# Pi-hole Admin Passwort
kubectl create secret generic pihole-password \
  --from-literal=password='DEIN_PASSWORT' \
  -n pihole

# Nebula-Sync Secret
ADMIN_PW='DEIN_PASSWORT'
kubectl create secret generic nebula-sync-env -n pihole \
  --from-literal=PRIMARY="http://192.168.1.10|${ADMIN_PW}" \
  --from-literal=REPLICAS="http://192.168.1.11|${ADMIN_PW},http://192.168.1.12|${ADMIN_PW}"
```

### Deployen
```bash
kubectl apply -f pihole-ha-daemonset.yaml
```

## Wartung

### Konfiguration ändern
**WICHTIG:** Nur auf Primary (192.168.1.10) ändern!
Nebula-Sync synchronisiert automatisch alle 5 Minuten.

### Manueller Sync
```bash
kubectl delete pod -n pihole -l app=nebula-sync
```

### Logs prüfen
```bash
# Pi-hole Logs
kubectl logs -n pihole -l app=pihole --tail=50

# Nebula-Sync Logs
kubectl logs -n pihole -l app=nebula-sync --tail=50
```

## Features
✅ Client-IPs werden angezeigt (via Fritz!Box Hostnamen)  
✅ HA durch 3 Nodes (manuelles Failover)  
✅ Automatische Config-Synchronisation (alle 5 Min)  
✅ Performance-optimiert (MAXDBDAYS=1)  

## Storage
- **hostPath**: `/var/lib/pihole/config` und `/var/lib/pihole/dnsmasq.d` auf jedem Node
- **Kein Longhorn**: Direkt auf Node für maximale Performance und Client-IP Tracking
