# Jellyfin Setup Notes

## Current Configuration (Working!)

**Version:** 10.10.3 (stable)
**Reason:** 10.11.x has memory leak during library scan on ARM64

**Key Settings:**
- Parallel scan tasks: 1
- FFmpeg probesize: 50M
- FFmpeg analyzeduration: 50M
- Memory limit: 4Gi
- MALLOC_TRIM_THRESHOLD: 100000

**Tested:** 103 movies scanned successfully without OOM
**Peak Memory:** 758Mi
**Stable Memory:** 702Mi

## Migration Path to 10.11.x (Future)

Wait for Jellyfin 10.11.6+ which should fix the memory leak.
Monitor GitHub issues: #15728, #13165, #11588
