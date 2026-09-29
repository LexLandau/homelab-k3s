# Lessons Learned

## 29.09.2026: Wartung und Modernisierung

- **Git ist nur Quelle der Wahrheit, wenn alles drin steht:** Drift-Analyse (Cluster gegen ArgoCD-Status) fand manuell installierte Komponenten, Teile außerhalb jedes ArgoCD-Pfads (Longhorn-RecurringJobs wurden nie ausgerollt) und eine k3s-Konfiguration, die nicht zum Ansible-Stand passte.
- **Snapshots sind kein Backup:** Ohne Backup-Ziel gab es keine Sicherung außerhalb der Longhorn-Datenträger. Ein Backup gilt erst nach erfolgreicher Test-Wiederherstellung als vorhanden.
- **Upgrades über mehrere Minor-Versionen stufenweise:** ArgoCD 2.13 nach 3.5 in sieben Stufen, vor jeder Stufe die offiziellen Upgrade-Hinweise gelesen. Vorher `argocd admin export`.
- **Server-Side Apply für große CRDs:** Client-Side Apply scheitert an der 256-KB-Grenze der Annotation `last-applied-configuration`. ArgoCD-Apps mit großen CRDs brauchen `ServerSideApply=true`.
- **Manuell ausgelöste Syncs übernehmen nicht automatisch die syncOptions der App:** Sync-Auftrag per `kubectl patch` mit `operation` muss die Optionen selbst mitgeben. Alte Fehlermeldungen bleiben im `operationState` stehen, bis ein neuer Sync läuft.
- **CRDs vor dem Chart-Update einspielen:** Nutzt eine neue Chart-Version Felder, die die alte CRD nicht kennt, scheitert schon der Vergleich (`field not declared in schema`) und ArgoCD synchronisiert nicht. Lösung: CRDs der Zielversion vorab per `kubectl apply --server-side --force-conflicts`.
- **Grafana übernimmt das Admin-Passwort nur beim ersten Start:** Danach gilt die Grafana-Datenbank. Passwortwechsel: 1Password, dann `grafana cli admin reset-admin-password`.
- **Helm-Values von Unter-Charts stehen unter dem Chart-Namen:** `prometheus-node-exporter.resources` statt `nodeExporter.resources`; die falschen Schlüssel wurden seit der Installation stillschweigend ignoriert.
- **Verwaiste Finalizer blockieren das Löschen:** LoadBalancer-Dienste aus der ServiceLB-Zeit trugen `service.kubernetes.io/load-balancer-cleanup`; ohne ServiceLB entfernt ihn niemand, Namespaces bleiben in `Terminating`.
- **Scheduler verteilt nach Requests, nicht nach Auslastung:** Nach vielen Neustarts landeten ArgoCD, ESO und Monitoring-Komponenten auf dem kleinsten Knoten (rpi4), der kurz `NotReady` wurde. Affinitäten gezielt setzen, ungenutzte Dienste entfernen.
- **k3s erneuert Zertifikate beim Neustart**, wenn sie innerhalb von 120 Tagen ablaufen. Knoten einzeln neu starten (etcd-Quorum).
- **Löschen ist kein Widerrufen:** Eine aus Git entfernte Datei bleibt in der Historie eines öffentlichen Repositorys lesbar. Veröffentlichte Geheimnisse gelten als kompromittiert und werden rotiert; Historie bereinigen ist nur Nacharbeit.
- **Token-Rotation k3s:** Vorher etcd-Snapshot und altes Token sichern (ältere Snapshots brauchen es), Token auf allen Servern einheitlich hinterlegen (token-file), dann `k3s token rotate` und alle Server einzeln neu starten.

## 21.07.2026: Update- und Storage-Störung

- **Soll-Replika-Inventur zuerst:** Vor Volume-Diagnosen und manuellem Löschen von Replikas `spec.numberOfReplicas` aller Volumes prüfen. Volumes der alten StorageClass `longhorn` standen auf Soll 3, Standard ist 2.
- **Engine-ERR-Geister nach Rolling-Restarts:** modeMap-Einträge ohne zugehörige Replica-CR blockieren Rebuilds dauerhaft (10-Minuten-Takt = replica-replenishment-wait-interval). Lösung: Workload auf 0 skalieren, Volume abhängen lassen, wieder hochskalieren.
- **iSCSI-I/O-Fehler (sdX) sind Folgesymptom:** session recovery timed out plus EXT4-Journal-Abbruch auf einem Longhorn-Device zeigt einen abgestürzten instance-manager an, keinen lokalen Plattendefekt.
- **Budget-SSD + etcd + parallele Rebuilds = Knotenausfall:** Fanxiang S101 (ohne DRAM-Cache) liefert unter Parallellast sekundenlange fsync-Stalls (etcd slow fdatasync bis 18 s, k3s-Startschleife, Last über 10). `concurrent-replica-rebuild-per-node-limit=1` ist Dauerstandard; rpi4 dauerhaft ohne Longhorn-Replika-Scheduling (vorhandene SSD bleibt).
- **Longhorn-Einstellungen gehören in die ConfigMap longhorn-default-setting (Git):** Live-Patches driften und überleben Neustarts und Upgrades nicht zuverlässig.
- **Reboot-Befehle als getrennte Blöcke:** Kommentar-Gates in Copy-Paste-Blöcken verschluckt die Shell; Knoten einzeln neu starten, dazwischen Longhorn-Robustness prüfen.
- **findmnt nimmt genau ein Argument;** Mehrfachprüfungen als Schleife.
- **rpi4-Sonderkonfiguration:** k3s-Drop-in IOSchedulingClass=realtime (io-priority.conf) bewusst belassen; ohne BFQ-Scheduler wirkungslos, dokumentiert zur Nachvollziehbarkeit.
