# Wartungsprotokoll: Modernisierung des k3s-Clusters

| | |
|---|---|
| Datum | 29.09.2026 |
| Durchführung | Alex |
| System | k3s-Cluster, 3 × Raspberry Pi (rpi5, rpi4-cm4, rpi4) |
| Grundsatz | Git ist die Quelle der Wahrheit; jede Änderung über Commit und Argo CD |

## 1. Ausgangslage (Ist-Analyse)

Abgleich des Clusters mit dem Git-Stand (Drift-Analyse) und Prüfung der Betriebsfähigkeit:

| Befund | Risiko |
|---|---|
| Keine Longhorn-Backups, kein Backup-Ziel; Snapshot-Jobs lagen außerhalb jedes Argo-CD-Pfads und wurden nie ausgerollt | Datenverlust bei Plattendefekt oder Fehlbedienung |
| Argo CD v2.13.2 (Support beendet), nicht mit Kubernetes 1.35 getestet; kube-prometheus-stack dauerhaft „Unknown“ | Keine Sicherheitsupdates, Monitoring nicht mehr über Git steuerbar |
| Grafana-Adminpasswort im Klartext im öffentlichen Repository | Unbefugter Zugriff |
| Argo CD, system-upgrade-controller und Terraria manuell installiert, nicht in Git | Nicht reproduzierbar |
| k3s-Konfiguration weicht von Ansible ab: Traefik lief trotz geplanter Deaktivierung, zwei Default-StorageClasses | Unklare Plattform, Fehlkonfiguration |
| Ungenutzte Dienste (Home Assistant, Mosquitto, Terraria, Portainer), leere Namespaces | Unnötiger RAM-Verbrauch, Angriffsfläche |
| kube-prometheus-stack Chart 65.8.1 (26 Major-Versionen alt) | Veraltete Komponenten |
| Ressourcenwerte für Node Exporter und kube-state-metrics wirkungslos (falscher Values-Schlüssel) | Keine Begrenzung |

## 2. Ziele

1. Datensicherung mit nachgewiesener Wiederherstellung.
2. Plattform aktuell (Argo CD, Monitoring) und vollständig in Git.
3. Keine Geheimnisse in Git; zentrale Verwaltung in 1Password.
4. Ungenutztes entfernen, Ressourcen entlasten.

## 3. Vorgehen

- Erst lesen, dann ändern: jede Maßnahme mit Bestandsaufnahme und Probelauf (`--dry-run=server`, `kubectl diff`).
- Offizielle Dokumentation als Grundlage (Upgrade-Hinweise Argo CD, UPGRADE.md kube-prometheus-stack, Longhorn- und k3s-Doku).
- Vor größeren Eingriffen Backup; kleine, einzeln prüfbare Schritte mit Rückfallweg (`git revert`).

## 4. Durchgeführte Maßnahmen

| Nr | Maßnahme | Ergebnis |
|---|---|---|
| 1 | Longhorn: Snapshot-, Backup- und Bereinigungsjobs über Git; Backup-Ziel SMB auf USB-HDD rpi5 mit eigenem Benutzer | 10 Volumes gesichert, Test-Wiederherstellung erfolgreich |
| 2 | Argo CD v2.13.2 auf v3.5.3 in 7 Stufen, danach Selbstverwaltung aus Git (Kustomize, Version fest) | Alle Apps Synced/Healthy, „Unknown“ behoben |
| 3 | External Secrets Operator mit 1Password-Service-Account (nur Lesen, eigener Tresor) | Samba- und Grafana-Zugang aus 1Password; Klartextpasswort aus Git entfernt |
| 4 | kube-prometheus-stack 65.8.1 → 83.7.0 → 91.8.1, CRDs jeweils vorab per Server-Side Apply | Prometheus 3.15, Grafana 13.2; Daten erhalten; 23 Scrape-Ziele aktiv |
| 5 | Values korrigiert (Unter-Charts), Limits angepasst (Prometheus 2Gi, Grafana 768Mi) | Ressourcen greifen |
| 6 | Home Assistant, Mosquitto, Terraria, Portainer entfernt; leere Namespaces gelöscht | RAM rpi4-cm4 82 % → 56 %; Wiederherstellung über Git-Tag möglich |
| 7 | k3s: traefik und local-storage per config.yaml.d deaktiviert, Knoten einzeln neu gestartet | Eine Default-StorageClass; Zertifikate erneuert bis 29.09.2027 |
| 8 | system-upgrade-controller in Git, Longhorn-Vorlage korrigiert, Dex abgeschaltet, ESO auf rpi5 | Plattform vollständig in Git |
| 9 | SSH: Kurznamen und Schlüssel mit Passphrase (1Password) | Keine Passwortabfragen mehr |
| 10 | Dokumentation überarbeitet, veraltete Dateien archiviert oder entfernt | Diese Datei, README, docs/ |

## 5. Soll-Ist-Vergleich

| Kriterium | Vorher | Nachher |
|---|---|---|
| Backup außerhalb Longhorn | nein | täglich, Wiederherstellung getestet |
| Argo CD | v2.13.2, manuell | v3.5.3, aus Git |
| Secrets in Git | Grafana-Passwort im Klartext | keine |
| Komponenten außerhalb Git | 3 | 0 (außer ESO-Token) |
| Default-StorageClasses | 2 | 1 |
| Argo-CD-Applications | 5, eine „Unknown“ | 7, alle Synced/Healthy |
| RAM rpi4 / rpi4-cm4 / rpi5 | 53 % / 75 % / 57 % (vor Umbau) | 74 % / 56 % / 61 % |

Hinweis RAM: rpi4 trägt jetzt Argo CD und Teile des Monitorings; rpi5 zusätzlich ESO. Gesamtverbrauch gesunken, Verteilung auf rpi4 noch ungünstig.

## 6. Probleme und Lösungen

| Problem | Ursache | Lösung |
|---|---|---|
| Git-Push abgelehnt (GH007) | Private E-Mail im Commit | GitHub-Noreply-Adresse |
| CRD-Sync „annotations too long“ | Veraltete Fehlermeldung im operationState; Client-Side Apply | Frischer Einzel-Sync mit ServerSideApply bestätigt |
| Chart 83.7.0 „Unknown“ | Neues Feld, alte CRD | CRDs der Zielversion vorab eingespielt |
| Namespaces hängen in „Terminating“ | Verwaister Finalizer aus ServiceLB-Zeit | Finalizer entfernt, auch vorsorglich bei übrigen Diensten |
| rpi4 kurz NotReady, ESO-Webhook Timeout | Speicherdruck durch Pod-Häufung auf rpi4 | ESO auf rpi5, Dex aus, ungenutzte Dienste entfernt |
| Grafana-Anmeldung nach Umstellung fehlgeschlagen | Grafana nutzt Datenbank-Passwort | Passwort aus Secret per grafana cli gesetzt, auf 25 Zeichen erhöht |

## 6a. Nachtrag: Sicherheitsprüfung des Repositorys

Prüfung aller 192 Commits mit gitleaks und gezielter Textsuche.

| Befund | Maßnahme |
|---|---|
| k3s-Cluster-Token von 01.12. bis 19.12.2025 im öffentlichen Repository, noch gültig | Token rotiert (k3s token rotate), alle Server neu gestartet; einheitlich per token-file, Quelle 1Password |
| Klarname im Protokoll | Entfernt |
| Private E-Mail-Adresse in Commit-Metadaten, alte Pi-hole- und Grafana-Passwörter in der Historie | Passwörter ungültig (Dienste entfernt bzw. Passwort geändert); E-Mail offen |
| Samba: Longhorn-Backups für Gäste gesperrt, Jellyfin-Sicherungen für Gäste lesbar | Longhorn in Ordnung; Jellyfin offen |

## 7. Offene Punkte

Siehe README.md, Abschnitt „Offene Punkte“ (u.a. Alertmanager-Benachrichtigung, Ansible-Angleichung, Backup außer Haus).

## 8. Fazit

Der Cluster ist gesichert, aktuell und vollständig über Git nachvollziehbar. Größter Gewinn ist die getestete Datensicherung; größter Lerneffekt die Upgrade-Methodik (Hinweise lesen, stufenweise, CRDs vorab, Probelauf vor jedem Eingriff).
