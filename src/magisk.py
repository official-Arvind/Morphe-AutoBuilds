import os
import zipfile
from pathlib import Path
import tempfile
import shutil

UPDATE_BINARY_CONTENT = """#!/sbin/sh
#################
# Initialization
#################
umask 022
ui_print() { echo "$1"; }

require_new_magisk() {
  ui_print "*******************************"
  ui_print " Please install Magisk v20.4+! "
  ui_print "*******************************"
  exit 1
}

OUTFD=$2
ZIPFILE=$3
mount /data 2>/dev/null

[ -f /data/adb/magisk/util_functions.sh ] || require_new_magisk
. /data/adb/magisk/util_functions.sh
[ $MAGISK_VER_CODE -lt 20400 ] && require_new_magisk

install_module
exit 0
"""

UPDATER_SCRIPT_CONTENT = "#MAGISK\n"

def create_magisk_module(apk_path: str, app_name: str, version: str, source: str, package_name: str = "unknown") -> str:
    """Packages an APK into a flashable Magisk Module ZIP."""
    apk_file = Path(apk_path)
    if not apk_file.exists():
        return None
    zip_name = apk_file.with_suffix('.zip')
    
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        
        # 1. META-INF
        meta_inf = temp_path / "META-INF" / "com" / "google" / "android"
        meta_inf.mkdir(parents=True, exist_ok=True)
        (meta_inf / "update-binary").write_text(UPDATE_BINARY_CONTENT, encoding="utf-8", newline="\n")
        (meta_inf / "updater-script").write_text(UPDATER_SCRIPT_CONTENT, encoding="utf-8", newline="\n")

        # 2. module.prop
        module_id = f"morphe_{app_name.lower().replace(' ', '_').replace('-', '_')}"
        module_prop = temp_path / "module.prop"
        module_prop.write_text(f"""id={module_id}
name=Morphe {app_name}
version={version}
versionCode=1
author=Arvind Ji (The New Perfectionist)
description=Systemless Morphe patched app for {app_name}. Patch type: {source.capitalize()}
""", encoding="utf-8", newline="\n")
        
        # 3. Mount scripts and customize
        if package_name != "unknown":
            customize_sh = temp_path / "customize.sh"
            customize_sh.write_text(f"""#!/system/bin/sh
ui_print "- Installing Morphe Patched App"
ui_print "- App: {app_name}"
ui_print "- Package: {package_name}"
ui_print "- Version: {version}"
ui_print "- Author: Arvind Ji (The New Perfectionist)"

# Check if app is installed
PKG_NAME="{package_name}"
APK_PATH=$(pm path "$PKG_NAME" 2>/dev/null | head -n 1 | cut -d':' -f2)
if [ -z "$APK_PATH" ]; then
    APK_PATH=$(grep -o 'package name="'$PKG_NAME'" codePath="[^"]*' /data/system/packages.xml 2>/dev/null | cut -d'"' -f4)
fi

if [ -z "$APK_PATH" ]; then
    ui_print "⚠️ WARNING: Original app is NOT installed!"
    ui_print "⚠️ Please install {package_name} before rebooting!"
else
    ui_print "✓ Detected existing target: $APK_PATH"
fi

# Ensure correct permissions on custom APK
chmod 644 $MODPATH/custom_apk/app.apk 2>/dev/null
chown system:system $MODPATH/custom_apk/app.apk 2>/dev/null
chcon u:object_r:apk_data_file:s0 $MODPATH/custom_apk/app.apk 2>/dev/null
""", encoding="utf-8", newline="\n")

            mount_logic = f"""#!/system/bin/sh
MODDIR=${{0%/*}}
PKG_NAME="{package_name}"

mount_patched_apk() {{
    TARGET_APK=""
    # 1. Try pm path
    BASE=$(pm path "$PKG_NAME" 2>/dev/null | head -n 1 | cut -d':' -f2)
    if [ -n "$BASE" ] && [ -f "$BASE" ]; then
        TARGET_APK="$BASE"
    else
        # 2. Try packages.xml
        APK_DIR=$(grep -o 'package name="'$PKG_NAME'" codePath="[^"]*' /data/system/packages.xml 2>/dev/null | cut -d'"' -f4)
        if [ -d "$APK_DIR" ]; then
            [ -f "$APK_DIR/base.apk" ] && TARGET_APK="$APK_DIR/base.apk" || TARGET_APK=$(ls $APK_DIR/*.apk 2>/dev/null | head -n 1)
        elif [ -f "$APK_DIR" ]; then
            TARGET_APK="$APK_DIR"
        fi
    fi

    if [ -n "$TARGET_APK" ] && [ -f "$TARGET_APK" ]; then
        chmod 644 $MODDIR/custom_apk/app.apk
        chown system:system $MODDIR/custom_apk/app.apk
        chcon u:object_r:apk_data_file:s0 $MODDIR/custom_apk/app.apk 2>/dev/null

        # Unmount old mount if active
        su -M -c umount -l "$TARGET_APK" 2>/dev/null || umount -l "$TARGET_APK" 2>/dev/null || true
        
        # Bind mount
        mount -o bind $MODDIR/custom_apk/app.apk "$TARGET_APK"
        am force-stop "$PKG_NAME" 2>/dev/null || true
        return 0
    fi
    return 1
}}
"""

            post_fs_sh = temp_path / "post-fs-data.sh"
            post_fs_sh.write_text(f"""{mount_logic}
mount_patched_apk
""", encoding="utf-8", newline="\n")

            service_sh = temp_path / "service.sh"
            service_sh.write_text(f"""{mount_logic}
until [ "$(getprop sys.boot_completed)" = 1 ]; do
    sleep 2
done
sleep 3
mount_patched_apk
""", encoding="utf-8", newline="\n")

            action_sh = temp_path / "action.sh"
            action_sh.write_text(f"""{mount_logic}
if mount_patched_apk; then
    echo "✓ Morphe patched {app_name} successfully mounted!"
else
    echo "❌ Failed to locate target APK for {package_name}."
fi
""", encoding="utf-8", newline="\n")

        else:
            # Fallback system overlay
            customize_sh = temp_path / "customize.sh"
            customize_sh.write_text(f"""#!/system/bin/sh
ui_print "- Installing Morphe Patched App"
ui_print "- App: {app_name}"
ui_print "- Author: Arvind Ji (The New Perfectionist)"
mkdir -p $MODPATH/system/app/Morphe{app_name.replace(' ', '')}
mv $MODPATH/custom_apk/app.apk $MODPATH/system/app/Morphe{app_name.replace(' ', '')}/app.apk
chmod 644 $MODPATH/system/app/Morphe{app_name.replace(' ', '')}/app.apk
rm -rf $MODPATH/custom_apk
""", encoding="utf-8", newline="\n")

        # 4. Copy custom APK
        app_dir = temp_path / "custom_apk"
        app_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(apk_file, app_dir / "app.apk")
        
        # 5. Package into ZIP
        with zipfile.ZipFile(zip_name, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for root, dirs, files in os.walk(temp_path):
                for file in files:
                    file_path = os.path.join(root, file)
                    arcname = os.path.relpath(file_path, temp_path)
                    zipf.write(file_path, arcname)
        
        return str(zip_name)
