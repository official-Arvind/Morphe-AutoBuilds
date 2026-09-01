import os
import zipfile
from pathlib import Path
import tempfile
import shutil

def create_magisk_module(apk_path: str, app_name: str, version: str, source: str, package_name: str = "unknown") -> str:
    """Packages an APK into a flashable Magisk Module ZIP."""
    apk_file = Path(apk_path)
    if not apk_file.exists():
        return None
    zip_name = apk_file.with_suffix('.zip')
    
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        
        # Create module.prop
        module_prop = temp_path / "module.prop"
        module_prop.write_text(f"""id=morphe_{app_name.lower().replace(' ', '_')}
name=Morphe {app_name}
version={version}
versionCode=1
author=Arvind Ji (The New Perfectionist)
description=Systemless Morphe patched app for {app_name}. Patch type: {source.capitalize()}
""")
        
        # Create customize.sh
        customize_sh = temp_path / "customize.sh"
        if package_name != "unknown":
            customize_sh.write_text(f"""#!/system/bin/sh
ui_print "- Installing Morphe Patched App"
ui_print "- App: {app_name}"
ui_print "- Package: {package_name}"
ui_print "- Author: Arvind Ji (The New Perfectionist)"
ui_print "- Configuring bulletproof bind mount for data overlay"

# Warn if not installed
PKG_NAME="{package_name}"
APK_PATH=$(grep -o 'package name="'$PKG_NAME'" codePath="[^"]*' /data/system/packages.xml | cut -d'"' -f4)
if [ -z "$APK_PATH" ]; then
    ui_print "⚠️ WARNING: Original app is NOT installed!"
    ui_print "⚠️ Please install {package_name} before rebooting!"
fi

# Create post-fs-data.sh to bind mount over the original app seamlessly
cat << 'EOF2' > $MODPATH/post-fs-data.sh
#!/system/bin/sh
MODDIR=${{0%/*}}
PKG_NAME="{package_name}"

# Find package path from packages.xml reliably
APK_DIR=$(grep -o 'package name="'$PKG_NAME'" codePath="[^"]*' /data/system/packages.xml | cut -d'"' -f4)

if [ -n "$APK_DIR" ]; then
    TARGET_APK=""
    if [ -d "$APK_DIR" ]; then
        if [ -f "$APK_DIR/base.apk" ]; then
            TARGET_APK="$APK_DIR/base.apk"
        else
            TARGET_APK=$(ls $APK_DIR/*.apk 2>/dev/null | head -n 1)
        fi
    elif [ -f "$APK_DIR" ]; then
        TARGET_APK="$APK_DIR"
    fi

    if [ -n "$TARGET_APK" ] && [ -f "$TARGET_APK" ]; then
        # Fix SELinux contexts and permissions so Zygote doesn't panic
        chmod 644 $MODDIR/custom_apk/app.apk
        chown system:system $MODDIR/custom_apk/app.apk
        chcon u:object_r:apk_data_file:s0 $MODDIR/custom_apk/app.apk 2>/dev/null
        
        # Bind mount the APK
        mount -o bind $MODDIR/custom_apk/app.apk $TARGET_APK
    fi
fi
EOF2
chmod +x $MODPATH/post-fs-data.sh
""")
        else:
            customize_sh.write_text(f"""#!/system/bin/sh
ui_print "- Installing Morphe Patched App"
ui_print "- App: {app_name}"
ui_print "- Author: Arvind Ji (The New Perfectionist)"
ui_print "- Placing patched app in system/app to override"
mkdir -p $MODPATH/system/app/Morphe{app_name.replace(' ', '')}
mv $MODPATH/custom_apk/app.apk $MODPATH/system/app/Morphe{app_name.replace(' ', '')}/app.apk
rm -rf $MODPATH/custom_apk
""")
        
        # Copy the APK to a custom dir so customize.sh can handle it
        app_dir = temp_path / "custom_apk"
        app_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(apk_file, app_dir / "app.apk")
        
        # Package into ZIP
        with zipfile.ZipFile(zip_name, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for root, dirs, files in os.walk(temp_path):
                for file in files:
                    file_path = os.path.join(root, file)
                    arcname = os.path.relpath(file_path, temp_path)
                    zipf.write(file_path, arcname)
        
        return str(zip_name)
