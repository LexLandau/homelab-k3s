# Host Configuration

Configuration files applied directly to cluster nodes (not managed by Kubernetes).

## rpi5

### USB HDD Mounts

Systemd mount units for three USB drives at `/etc/systemd/system/`.

Two drives were migrated from NTFS to EXT4. NTFS on Linux has significant overhead:
- ntfs-3g (FUSE userspace driver): ~40 MB/s, high CPU usage
- ntfs3 (kernel driver): ~110 MB/s, better but still slower than native
- EXT4: ~120 MB/s, lower CPU usage, better for sustained I/O

### Samba

Configuration at `/etc/samba/smb.conf`. Optimized for the 2.5GbE USB adapter.

Samba binds only to eth1 (192.168.1.15), not the cluster interface.

### udev Rules

`99-readahead.rules` sets read-ahead buffer to 2048kb for USB HDDs. Improves sequential read performance for video streaming.

## Installation

```bash
# Mount units
sudo cp rpi5/mnt-media-*.mount /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now mnt-media-movies.mount mnt-media-series.mount mnt-media-backup.mount

# Samba
sudo cp rpi5/smb.conf /etc/samba/smb.conf
sudo systemctl restart smbd

# udev
sudo cp rpi5/99-readahead.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
```

## Network on rpi5

- eth0: 192.168.1.10 - onboard 1GbE, K3s cluster traffic
- eth1: 192.168.1.15 - UGREEN 2.5GbE USB adapter, SMB traffic
