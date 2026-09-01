### v
- Background WebUI flashing improvements
- Built-in root binary detection fixes
- Bundled static busybox for universal compatibility

### v1.7
- Fully resolved "Download failed or ZIP corrupt" errors by chaining HTTP clients.
- Bypassed strict SSL certificate validation missing in barebones root sandboxes (`curl -k`, `wget --no-check-certificate`).

### v1.6
- Complete APatch support & exhaustive legacy root detection (supports absolute binary fallback for Magisk, KernelSU, APatch/apd across 18+ different system paths).

### v1.5
- Removed APK Auto-Updates (Root devices only need module updates).

### v1.4
- IPC Background daemon added for robust flashing.
- Absolute root detection fixes.
- Bundled Osm0sis busybox to fix download failures on barebones devices.

### v1.2
- Initial Magisk auto-update logic.
- Web UI design improvements.
