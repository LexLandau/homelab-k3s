# Jellyfin Setup Notes

## Current Configuration (Working!)

**Version:** 10.11.6 (stable)
**Updated:** February 17, 2026
**Update Path:** 10.10.3 → 10.10.7 → 10.11.6 (Zwischenschritt auf 10.10.7 ist Pflicht!)

**Key Settings:**
- Parallel scan tasks: 1
- FFmpeg probesize: 50M
- FFmpeg analyzeduration: 50M
- Memory limit: 6Gi (erhöht von 4Gi, 10.11.x cached DB im RAM)
- MALLOC_TRIM_THRESHOLD: 100000

**10.11.x Besonderheiten:**
- EF Core DB Migration beim ersten Start (~70 Sekunden bei dieser Library-Größe)
- Mehr RAM-Nutzung als 10.10.x durch aggressives DB-Caching (normal!)
- ARM32 nicht mehr unterstützt (kein Problem, rpi5/rpi4 laufen ARM64)

**Getestete Werte nach Update:**
- Peak Memory (Library Scan): ~769Mi CPU-intensiv
- Stable Memory: ~549Mi

## Plugins

**Entfernt (inkompatibel mit 10.11.x):**
- TMDbBoxSets 12.0.0.0 → crasht mit MissingMethodException

## Migration Path

~~Wait for Jellyfin 10.11.6+ which should fix the memory leak.~~
✅ Erledigt am 17.02.2026
