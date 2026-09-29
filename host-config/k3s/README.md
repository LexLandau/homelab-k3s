# k3s-Hostkonfiguration

Auf jedem Server liegt /etc/rancher/k3s/config.yaml (enthaelt Token, NICHT in Git; aktueller Inhalt u.a. disable: servicelb).
Zusatzdateien aus config.yaml.d/ werden in alphabetischer Reihenfolge gelesen und hier versioniert.

Verteilen: Datei per scp auf den Knoten, nach /etc/rancher/k3s/config.yaml.d/ installieren, k3s neu starten.
Immer nur einen Knoten gleichzeitig neu starten (etcd-Quorum 2 von 3), rpi5 zuletzt.
Ein Neustart erneuert zudem bald ablaufende k3s-Zertifikate.

Hinweis: Die Ansible-Rolle im Repository beschreibt die Startparameter nicht korrekt (Stand 29.09.2026), Angleichung offen.
