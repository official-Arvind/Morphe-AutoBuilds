### v
- Background WebUI flashing improvements
- Built-in root binary detection fixes
- Bundled static busybox for universal compatibility

### v
- Background WebUI flashing improvements
- Built-in root binary detection fixes
- Bundled static busybox for universal compatibility

### v1.9
- Crucial Fix: Standardized root installation by switching to bind mounts (`post-fs-data.sh`). Apps like Facebook are no longer forced into `/system/app`, preventing permissions-related crashes.
- The build engine now natively extracts the package name from `apps/` configs to dynamically mount the patched APK directly over the user's base APK.

### v1.8
- Major UI overhaul: WebUI now groups releases by App and Patch Type (e.g. YouTube -> Morphe).
- WebUI now displays both Root (ZIP) and Non-Root (APK) versions of patched apps side-by-side.
- Enhanced Module property headers: Magisk modules now explicitly state the patch type applied (e.g. revanced, morphe) in their description.

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
