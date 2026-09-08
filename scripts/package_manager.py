#!/usr/bin/env python3
"""Build and package the official Morphe Manager Magisk/KernelSU/APatch module ZIP.

Ensures official BusyBox binaries for both arm64-v8a and armeabi-v7a are bundled,
validates all script permissions and LF line endings, and generates update.json.
"""

import os
import sys
import json
import zipfile
import tempfile
import argparse
import urllib.request
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

MAGISK_APK_URL = "https://github.com/topjohnwu/Magisk/releases/download/v30.7/Magisk-v30.7.apk"

def ensure_busybox_binaries(bin_dir: Path) -> None:
    """Ensure busybox-arm64, busybox-arm, and busybox exist in bin_dir."""
    bin_dir.mkdir(parents=True, exist_ok=True)
    arm64 = bin_dir / "busybox-arm64"
    arm = bin_dir / "busybox-arm"
    default_bb = bin_dir / "busybox"

    if arm64.exists() and arm.exists() and default_bb.exists():
        return

    print("📥 Fetching official BusyBox binaries from Magisk...")
    req = urllib.request.Request(MAGISK_APK_URL, headers={"User-Agent": "MorphePackager/1.0"})
    with tempfile.NamedTemporaryFile(suffix=".apk", delete=False) as tmp_apk:
        tmp_path = Path(tmp_apk.name)
        with urllib.request.urlopen(req) as resp:
            tmp_apk.write(resp.read())

    try:
        with zipfile.ZipFile(tmp_path, "r") as zf:
            if not arm64.exists() and "lib/arm64-v8a/libbusybox.so" in zf.namelist():
                arm64.write_bytes(zf.read("lib/arm64-v8a/libbusybox.so"))
                print("  ✓ Extracted arm64-v8a BusyBox")
            if not arm.exists() and "lib/armeabi-v7a/libbusybox.so" in zf.namelist():
                arm.write_bytes(zf.read("lib/armeabi-v7a/libbusybox.so"))
                print("  ✓ Extracted armeabi-v7a BusyBox")
            if not default_bb.exists() and arm64.exists():
                default_bb.write_bytes(arm64.read_bytes())
                print("  ✓ Set default busybox")
    finally:
        tmp_path.unlink(missing_ok=True)

def package_manager(manager_dir: Path, output_zip: Path, update_json_path: Path | None = None) -> Path:
    """Packages manager_dir into flashable module zip."""
    if not manager_dir.exists():
        raise FileNotFoundError(f"Manager directory not found: {manager_dir}")

    ensure_busybox_binaries(manager_dir / "bin")

    output_zip.parent.mkdir(parents=True, exist_ok=True)

    # Read module.prop to extract version info
    prop_file = manager_dir / "module.prop"
    version = "2.1"
    version_code = "21"
    if prop_file.exists():
        for line in prop_file.read_text(encoding="utf-8").splitlines():
            if line.startswith("version="):
                version = line.split("=", 1)[1].strip()
            elif line.startswith("versionCode="):
                version_code = line.split("=", 1)[1].strip()

    print(f"📦 Packaging Morphe Manager v{version} (code {version_code}) into {output_zip}...")
    with zipfile.ZipFile(output_zip, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk(manager_dir):
            for file in files:
                file_path = Path(root) / file
                arcname = os.path.relpath(file_path, manager_dir)

                # Ensure LF endings for scripts and config files
                if file_path.suffix in [".sh", ".prop", ".html", ".css", ".js", ".json"] or file in ["update-binary", "updater-script"]:
                    data = file_path.read_bytes().replace(b"\r\n", b"\n")
                    info = zipfile.ZipInfo(arcname)
                    info.external_attr = 0o755 << 16  # Executable
                    zf.writestr(info, data)
                else:
                    info = zipfile.ZipInfo.from_file(file_path, arcname)
                    if "bin" in Path(arcname).parts:
                        info.external_attr = 0o755 << 16  # Executable
                    zf.write(file_path, arcname)

    print(f"✅ Created {output_zip} ({output_zip.stat().st_size} bytes)")

    if update_json_path:
        update_json_path.parent.mkdir(parents=True, exist_ok=True)
        update_info = {
            "version": version,
            "versionCode": int(version_code) if version_code.isdigit() else 21,
            "zipUrl": "https://github.com/official-Arvind/Morphe-AutoBuilds/releases/latest/download/morphe-manager.zip",
            "changelog": "https://raw.githubusercontent.com/official-Arvind/Morphe-AutoBuilds/main/morphe_manager/CHANGELOG.md"
        }
        update_json_path.write_text(json.dumps(update_info, indent=2) + "\n", encoding="utf-8")
        print(f"✅ Generated {update_json_path}")

    return output_zip

def main():
    parser = argparse.ArgumentParser(description="Package Morphe Manager Module ZIP")
    parser.add_argument("--source", type=Path, default=Path("morphe_manager"), help="Path to morphe_manager folder")
    parser.add_argument("--output", type=Path, default=Path("dist/morphe-manager.zip"), help="Path to output zip")
    parser.add_argument("--update-json", type=Path, default=None, help="Path to write update.json")
    args = parser.parse_args()

    package_manager(args.source, args.output, args.update_json)

if __name__ == "__main__":
    main()
