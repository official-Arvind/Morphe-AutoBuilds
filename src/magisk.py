import os
import zipfile
from pathlib import Path
import tempfile
import shutil

def create_magisk_module(apk_path: str, app_name: str, version: str) -> str:
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
description=Systemless Morphe patched app for {app_name}
""")

                # Create customize.sh
        customize_sh = temp_path / "customize.sh"
        customize_sh.write_text(f"""#!/system/bin/sh
ui_print "- Installing Morphe Patched App"
ui_print "- App: {app_name}"
ui_print "- Author: Arvind Ji (The New Perfectionist)"

# Find the installed package path (dumb fallback)
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
