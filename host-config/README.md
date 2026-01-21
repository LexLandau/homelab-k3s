# Host Configuration Files

Configuration files applied directly to cluster nodes (not managed by Kubernetes).

## rpi5 - Media Server Configuration

### NTFS Performance Optimization (December 2025)

Optimized NTFS USB HDDs from 40 MB/s to 110+ MB/s by switching from `ntfs-3g` (userspace FUSE) to `ntfs3` (kernel driver).

| Test | Before | After |
|------|--------|-------|
| Local read | 40 MB/s | 111 MB/s |
| SMB write | 40 MB/s | 113-125 MB/s |
| SMB read (robocopy) | 40 MB/s | 125 MB/s |

### Files

- `mnt-media-*.mount` - Systemd mount units with ntfs3 driver
- `smb.conf` - Optimized Samba configuration for 2.5GbE
- `99-readahead.rules` - udev rule for increased read-ahead buffer

### Installation
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
```

### Network

- eth0 (pihole-0.pihole-headless.pihole.svc.cluster.local) - 1GbE onboard - K3s cluster
- eth1 (192.168.1.15) - 2.5GbE USB adapter - SMB traffic

### Windows Tip

Use `robocopy` for max speed: `robocopy "\\192.168.1.15\Movies" C:\dest /MT:8`
