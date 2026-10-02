# k3s-Hostkonfiguration

Auf jedem Server liegt /etc/rancher/k3s/config.yaml (enthaelt Token, NICHT in Git; aktueller Inhalt u.a. disable: servicelb).
Zusatzdateien aus config.yaml.d/ werden in alphabetischer Reihenfolge gelesen und hier versioniert.
Knotenspezifische Zusatzdateien liegen in einem Unterordner je Knoten (rpi4/, rpi4-cm4/, rpi5/) und kommen auf dem jeweiligen Knoten ebenfalls nach /etc/rancher/k3s/config.yaml.d/.

Verteilen: Datei per scp auf den Knoten, nach /etc/rancher/k3s/config.yaml.d/ installieren, k3s neu starten.
Immer nur einen Knoten gleichzeitig neu starten (etcd-Quorum 2 von 3), rpi5 zuletzt.
Ein Neustart erneuert zudem bald ablaufende k3s-Zertifikate.

Hinweis: Die Ansible-Rolle im Repository beschreibt die Startparameter nicht korrekt (Stand 29.09.2026), Angleichung offen.

## Cluster-Token

Seit 29.09.2026 einheitlich per token-file (20-token.yaml). Das Token liegt je Knoten in /etc/rancher/k3s/cluster-token (root, 0600), Quelle 1Password.
Grund: Das urspruengliche Token war von 01.12. bis 19.12.2025 im oeffentlichen Repository und wurde rotiert (k3s token rotate).
Altes Token je Knoten in /root/k3s-server-token-alt-2026-09-29; noetig nur zur Wiederherstellung von etcd-Snapshots vor der Rotation.

## Speicherreservierung (30-reserved.yaml, je Knoten)

Seit 02.10.2026 per kubelet-arg kube-reserved und system-reserved, Werte nach Messung des Eigenverbrauchs:

| Knoten | kube-reserved | system-reserved | Allocatable (gemessen 02.10.2026) |
|---|---|---|---|
| rpi4 | 1536Mi | 256Mi | 2003Mi |
| rpi4-cm4 | 1792Mi | 256Mi | 1748Mi |
| rpi5 | 1536Mi | 256Mi | 6270Mi |

Allocatable = Kapazitaet - kube-reserved - system-reserved. k3s setzt in evictionHard nur imagefs und nodefs, eine RAM-Schwelle (memory.available) gibt es nicht.
Kontrolle: `kubectl describe node <KNOTEN> | grep -A 6 Allocatable`

Verteilen: Installation mit "install -m 0600 -o root -g root" (wie 10-disable.yaml und 20-token.yaml). Reihenfolge rpi4-cm4, rpi4, rpi5: zuerst der Node mit den wenigsten Longhorn-Volumes. Die Node-Schritte (scp, ssh, Neustart) führt Alex selbst aus.

Hinweis: Die Kopien auf den Nodes enthalten noch die alte Kommentarzeile, inhaltlich identisch, Abgleich beim nächsten Verteilen.

Offener Punkt: RAM-Eviction-Schwelle nachrüsten. Ein eigenes eviction-hard-Flag ersetzt die ganze Liste, dann immer memory.available, imagefs.available und nodefs.available zusammen setzen.
