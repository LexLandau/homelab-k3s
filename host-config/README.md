# Host-Konfiguration

Dateien, die direkt auf den Knoten liegen (nicht über Kubernetes verwaltet). Nach Änderungen per scp/ssh verteilen, danach den Dienst neu starten.

## k3s (alle Knoten)

Siehe k3s/README.md. Zusatzdatei config.yaml.d/10-disable.yaml deaktiviert traefik und local-storage.

- rpi4: k3s-Drop-in `io-priority.conf` (IOSchedulingClass=realtime): ohne BFQ-Scheduler wirkungslos, Entfernen prüfen.

## rpi5 (Mediendienste)

| Datei | Ziel auf rpi5 | Zweck |
|---|---|---|
| mnt-media-backup.mount | /etc/systemd/system/ | USB-HDD 3,6 TB, ext4, /mnt/media/backup |
| mnt-media-movies.mount | /etc/systemd/system/ | USB-HDD 1,8 TB, ext4, /mnt/media/movies |
| mnt-media-series.mount | /etc/systemd/system/ | USB-HDD 1,8 TB, ext4, /mnt/media/series |
| smb.conf | /etc/samba/smb.conf | Samba auf eth1 (192.168.1.15, 2,5 GbE) |
| 99-readahead.rules | /etc/udev/rules.d/ | Read-ahead 2 MB für USB-HDDs |

Samba-Freigaben:

| Freigabe | Pfad | Zugriff |
|---|---|---|
| Movies, Series | /mnt/media/movies, /mnt/media/series | Gast lesen/schreiben |
| Backup | /mnt/media/backup | Gast lesen/schreiben (bewusst, nur LAN) |
| LonghornBackup | /mnt/media/backup/longhorn | nur Benutzer longhorn-backup (Passwort in 1Password) |

Änderung smb.conf übernehmen (Prüfung vor Übernahme):

```bash
scp host-config/rpi5/smb.conf rpi5:/tmp/smb.conf.neu
ssh -t rpi5 'testparm -s /tmp/smb.conf.neu >/dev/null && sudo install -m 0644 /tmp/smb.conf.neu /etc/samba/smb.conf && sudo systemctl reload smbd; rm -f /tmp/smb.conf.neu'
```

Hinweis: Die Mount-Units hießen früher „NTFS“; alle Platten sind inzwischen ext4. Die Beschreibung auf dem Host ändert sich erst beim nächsten Kopieren der Units.
