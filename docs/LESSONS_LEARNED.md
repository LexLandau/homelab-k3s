# Lessons Learned

Regeln aus früheren Störungen und Wartungen. Vor Arbeiten an einem Thema den passenden Abschnitt lesen.
Datum = Herkunft, Details im Protokoll des Tages (z. B. [PROTOKOLL-2026-09-29.md](PROTOKOLL-2026-09-29.md)).
VLAN-Themen (Virtual LAN) stehen in [VLAN_NETWORK.md](VLAN_NETWORK.md).

## Allgemein

- **Nodes immer einzeln neu starten**, dazwischen Longhorn prüfen. Sonst verliert etcd (Cluster-Datenbank von k3s) das Quorum (Mehrheit der Server). Gilt für Updates, Zertifikate und Token-Rotation. (21.07. und 29.09.2026)
- **Jeden Reboot als eigenen Copy-Paste-Block.** Kommentare wie `# erst weiter, wenn ...` stoppen nichts, die Shell führt alles direkt nacheinander aus. (21.07.2026)
- **Mehrere Mountpoints mit `findmnt` nur per Schleife prüfen.** Zwei Argumente gelten als Source und Target eines einzigen Mounts: keine Ausgabe, Exit-Code 1, keine Fehlermeldung. (21.07.2026)

## Git und ArgoCD

- **Alles gehört in Git.** Git ist nur Single Source of Truth (SSOT, einzige maßgebliche Quelle), wenn nichts manuell installiert ist. Die Drift-Analyse fand manuelle Komponenten, nie ausgerollte Longhorn-RecurringJobs und eine k3s-Config abweichend vom Ansible-Stand. (29.09.2026)
- **Upgrades Minor für Minor.** Vor jeder Stufe die Upgrade Notes lesen, vorher `argocd admin export`. ArgoCD 2.13 auf 3.5 waren sieben Stufen. (29.09.2026)
- **Große CRDs (Custom Resource Definitions, eigene Kubernetes-Ressourcentypen) mit `ServerSideApply=true`.** Client-Side Apply scheitert an der 256-KB-Grenze der Annotation `last-applied-configuration`. (29.09.2026)
- **CRDs vor dem Chart-Upgrade einspielen:** `kubectl apply --server-side --force-conflicts` mit den CRDs der Zielversion. Sonst scheitert schon der Diff (`field not declared in schema`) und ArgoCD synct nicht. (29.09.2026)
- **Bei manuellem Sync per `kubectl patch` die syncOptions selbst mitgeben.** Die Optionen der App werden nicht übernommen. Alte Fehler bleiben im `operationState`, bis ein neuer Sync läuft. (29.09.2026)
- **`replicas` nicht in Git führen, wenn ein Job die Workload skaliert.** Mit selfHeal setzt ArgoCD die Anzahl sofort zurück. Das Jellyfin-Backup lief so wochenlang bei laufendem Pod. (29.09.2026)

## Helm und Monitoring

- **Values von Subcharts unter dem Chart-Namen eintragen:** `prometheus-node-exporter.resources`, nicht `nodeExporter.resources`. Falsche Keys werden stillschweigend ignoriert. (29.09.2026)
- **Grafana-Admin-Passwort per CLI (Command Line Interface) ändern:** `grafana cli admin reset-admin-password`. Der Wert aus den Values gilt nur beim ersten Start, danach zählt die Grafana-DB (Datenbank). Passwort in 1Password ablegen. (29.09.2026)
- **Prometheus-Werte pro Container auswerten, nicht pro Pod summieren:** Jeder Container-Neustart erzeugt eine neue Zeitreihe, sum by (pod) addiert alle Generationen (application-controller ergab so 3.533 MiB statt ca. 610 MiB). Richtig: max by (container) (quantile_over_time(0.95, ...)). (02.10.2026)

## Kubernetes-Cluster

- **Für jede Workload Requests nach Messung setzen:** RAM-Request = 95. Perzentil (p95) über 7 Tage, RAM-Limit = Spitzenwert plus Puffer, keine CPU-Limits. Der Scheduler plant nach Requests, nicht nach realer Last, und verteilt laufende Pods nie neu. Pods ohne Requests zählen mit 0, volle Nodes wirken dadurch leer. ArgoCD lief so komplett ohne Requests auf rpi4 (Raspberry Pi 4). (29.09. und 02.10.2026)
- **Eigenverbrauch von k3s mit kube-reserved und system-reserved reservieren:** k3s-server (API-Server, etcd und kubelet in einem Prozess) belegt je Node 1,0 bis 1,4 GiB RSS (tatsächlich belegter RAM), containerd und containerd-shims weitere 0,3 bis 0,5 GiB. Ohne Reservierung zählt der Scheduler diesen RAM als frei. Werte in host-config/k3s/<node>/30-reserved.yaml. (02.10.2026)
- **k3s setzt keine RAM-Eviction-Schwelle:** evictionHard enthält nur imagefs und nodefs, memory.available fällt dadurch auf 0. Ein eigenes eviction-hard-Flag ersetzt die ganze Liste, also immer alle Werte angeben. (02.10.2026)
- **`kubectl top nodes` rechnet Prozent gegen Allocatable (für Pods verfügbarer RAM nach Abzug der Reservierungen), nicht gegen den physischen RAM:** Seit kube-reserved und system-reserved zeigt rpi4 z. B. 129 %, real sind 2.593 MiB von 3,7 GiB belegt (ca. 68 %). Für die echte Auslastung MEMORY(bytes) mit der Kapazität vergleichen: `kubectl get nodes -o custom-columns=NAME:.metadata.name,CAP:.status.capacity.memory`. (02.10.2026)
- **Node-Änderungen zuerst auf dem Node mit den wenigsten Longhorn-Volumes testen**, den Node mit den meisten zuletzt. (02.10.2026)
- **system-upgrade-controller hält keine Node-Reihenfolge ein:** Der Controller (rollt k3s-Updates per Job auf die Nodes aus) arbeitet einen Plan mit `concurrency: 1` zwar Node für Node ab, die Reihenfolge wählt er aber selbst. Beim Upgrade auf k3s v1.35.9 war es rpi4, rpi5, rpi4-cm4, der Node mit den meisten Longhorn-Volumes also nicht zuletzt. Soll die Reihenfolge stimmen: je Node ein eigener Plan mit `nodeSelector` auf `kubernetes.io/hostname`, nacheinander committen. (02.10.2026)
- **Hängt ein Namespace in `Terminating`, Finalizer prüfen.** Alte LoadBalancer-Services aus der ServiceLB-Zeit (in k3s eingebauter LoadBalancer) tragen `service.kubernetes.io/load-balancer-cleanup`, den niemand mehr entfernt. (29.09.2026)
- **Zertifikate:** k3s erneuert sie beim Neustart, wenn sie innerhalb von 120 Tagen ablaufen. (29.09.2026)
- **Token-Rotation:** etcd-Snapshot und altes Token sichern (ältere Snapshots brauchen es), Token auf allen Servern gleich per token-file, dann `k3s token rotate`. (29.09.2026)
- **Major-Upgrade mit DB-Migration:** Image-Tag pinnen statt `latest`, Backup bei gestopptem Pod, `startupProbe` mit großzügigem Timeout, damit die livenessProbe die Migration nicht abbricht. Angewendet bei Jellyfin 12, am 01.10.2026 auf 12.1. (29.09.2026)

## Longhorn und Storage

- **Snapshot ist kein Backup.** Es braucht ein Backup Target außerhalb der Longhorn-Volumes. Ein Backup zählt erst nach erfolgreichem Restore-Test. (29.09.2026)
- **Vor jeder Volume-Diagnose Desired Replicas prüfen:** `spec.numberOfReplicas` aller Volumes. Die alte StorageClass `longhorn` stand auf 3, Default ist 2. (21.07.2026)
- **Rebuild hängt im 10-Minuten-Takt (`replica-replenishment-wait-interval`):** Nach Rolling Restarts blockieren modeMap-Einträge mit ERR ohne zugehörige Replica-CR (Custom Resource). Fix: Workload auf 0, Volume detachen lassen, wieder hochskalieren. (21.07.2026)
- **iSCSI-Fehler (Internet Small Computer System Interface, Block-Storage über das Netz) sind Folgesymptom:** `session recovery timed out` plus EXT4-Journal-Abbruch (EXT4 = Linux-Dateisystem) heißt abgestürzter instance-manager, kein Plattendefekt. (21.07.2026)
- **Maximal ein Rebuild pro Node:** `concurrent-replica-rebuild-per-node-limit=1` bleibt Standard, rpi4 ohne Replica-Scheduling. Consumer-SSD (Solid State Drive) ohne DRAM-Cache (Zwischenspeicher der SSD) wie die Fanxiang S101 hat unter Parallellast fsync-Stalls (Hänger beim Schreiben auf Platte) bis 18 s, dann fallen etcd und k3s aus. (21.07.2026)
- **Longhorn-Settings nur über die ConfigMap `longhorn-default-setting` in Git.** Live-Patches driften und überleben Restart und Upgrade nicht zuverlässig. (21.07.2026)
- **Longhorn-Upgrades nur Minor für Minor:** 1.10 auf 1.13 sind drei Stufen (1.11.3, 1.12.1, 1.13.0). Übersprungene Minor-Versionen lehnt longhorn-manager selbst ab. Release Notes jeder Stufe lesen: 1.11.3 braucht Kubernetes ab 1.34 wegen CSI-Provisioner v6.3.0 (CSI = Container Storage Interface, Schnittstelle zwischen Kubernetes und Storage). Vorher frisches Backup per Job aus `daily-backup-all`. Ablauf in kubernetes/infrastructure/longhorn/README.md. (02.10.2026)
- **Lokale Anpassungen per diff gegen das Original der installierten Version ermitteln:** Herstellermanifest der alten Version holen, mit longhorn.yaml im Repo vergleichen, Unterschiede ins neue Manifest übertragen. Nicht allein auf die Liste in der README verlassen. (02.10.2026)
- **Manager-Upgrade stellt die Volumes nicht um:** Mit `concurrent-automatic-engine-upgrade-per-node-limit=0` (Longhorn-Default) laufen die Volumes nach dem Upgrade weiter mit der alten Engine (Prozess, der die Schreibzugriffe eines Volumes auf seine Replicas verteilt). Auf "1" stellt Longhorn die Engines im laufenden Betrieb um, 6 Volumes in unter einer Minute. Änderungen an `longhorn-default-setting` übernimmt Longhorn sofort, nicht nur bei der Installation. (02.10.2026)
- **Nach dem Live-Upgrade bleiben alte instance-manager stehen:** Der instance-manager (Longhorn-Pod je Node, in dem Engine- und Replica-Prozesse laufen) der alten Version läuft weiter, bis jedes seiner Volumes einmal detached war. `rollout restart` auf demselben Node reicht nicht, Kubernetes übergibt das Volume direkt an den neuen Pod. Nur Wechsel des Nodes oder Workload auf 0, warten bis `detached`, wieder hochskalieren. (02.10.2026)

## OPNsense

- **Destination NAT (Network Address Translation, hier: Zieladresse umschreiben) mit „Firewall rule: Pass“ anlegen.** Dann lädt OPNsense 26.7 die Regel als `rdr pass` (Umleitung inklusive Freigabe). Bei „Manual“ braucht das umgeleitete Paket eine eigene Pass-Regel, sonst greift Default Deny. Beim Klonen aufpassen: Die DNS-Umleitung (Domain Name System) war ein Klon der NTP-Regel (Network Time Protocol). Für NTP gab es eine passende Pass-Regel, für DNS nicht. (01.10.2026)
- **Nach NAT-Änderungen den geladenen Regelsatz prüfen, nicht die GUI (grafische Oberfläche):** `pfctl -sn | grep -n rdr` oder `grep -n rdr /tmp/rules.debug`, ohne `pass` im Suchmuster. Der Vergleich mit funktionierenden Regeln (z. B. WAN-Port-Forwards, WAN = Internetseite) zeigt Unterschiede sofort. (01.10.2026)

## Security

- **Veröffentlichte Secrets sofort rotieren.** Gelöscht ist nicht widerrufen: Die Datei bleibt in der History eines Public Repos lesbar. Ein History-Rewrite ist nur Nacharbeit. (29.09.2026)
- **Der Automatisierungszugang arbeitet im Cluster nur lesend:** eigener ServiceAccount, Änderungen nur über Git und ArgoCD, Node-Zugriffe per SSH führt Alex selbst aus. Damit ist Git push auf main der eigentliche Admin-Zugang. Details in kubernetes/infrastructure/ops-readonly/README.md. (02.10.2026)
