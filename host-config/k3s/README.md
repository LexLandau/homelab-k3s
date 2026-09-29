# k3s-Hostkonfiguration

Auf jedem Server liegt /etc/rancher/k3s/config.yaml (enthaelt Token, NICHT in Git; aktueller Inhalt u.a. disable: servicelb).
Zusatzdateien aus config.yaml.d/ werden in alphabetischer Reihenfolge gelesen und hier versioniert.

Verteilen: Datei per scp auf den Knoten, nach /etc/rancher/k3s/config.yaml.d/ installieren, k3s neu starten.
Immer nur einen Knoten gleichzeitig neu starten (etcd-Quorum 2 von 3), rpi5 zuletzt.
Ein Neustart erneuert zudem bald ablaufende k3s-Zertifikate.

Hinweis: Die Ansible-Rolle im Repository beschreibt die Startparameter nicht korrekt (Stand 29.09.2026), Angleichung offen.

## Cluster-Token

Seit 29.09.2026 einheitlich per token-file (20-token.yaml). Das Token liegt je Knoten in /etc/rancher/k3s/cluster-token (root, 0600), Quelle 1Password.
Grund: Das urspruengliche Token war von 01.12. bis 19.12.2025 im oeffentlichen Repository und wurde rotiert (k3s token rotate).
Altes Token je Knoten in /root/k3s-server-token-alt-2026-09-29; noetig nur zur Wiederherstellung von etcd-Snapshots vor der Rotation.
