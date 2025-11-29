# Jellyfin Setup

## Version

Currently running 10.10.3. Version 10.11.x has a memory leak on ARM64 during library scans that leads to OOM kills.

Related issues: #15728, #13165, #11588

Will upgrade once 10.11.6+ is released with a fix.

## Configuration

Environment variables:
```yaml
JELLYFIN_parallel_scan_tasks: "1"
JELLYFIN_FFmpeg__probesize: "50000000"
JELLYFIN_FFmpeg__analyzeduration: "50000000"
MALLOC_TRIM_THRESHOLD_: "100000"
```

Resource limits: 4Gi memory, 2 CPU cores.

## Storage

Config and cache on Longhorn (NVMe-backed PVCs):
- jellyfin-config-nvme: 10Gi
- jellyfin-cache-nvme: 10Gi

Media mounts (USB HDDs on rpi5):
- /mnt/media/movies
- /mnt/media/series
- /mnt/media/backup

## Known Issues

- Occasional crashes during playback (under investigation)
- Library scans are slow with large collections
- No hardware transcoding (RPi5 GPU not supported by Jellyfin)
