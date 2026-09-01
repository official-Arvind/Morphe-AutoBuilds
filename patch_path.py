import os

def patch_file(filepath):
    with open(filepath, "r") as f:
        content = f.read()
    
    if "export PATH=" not in content:
        content = content.replace("#!/system/bin/sh", "#!/system/bin/sh\nexport PATH=\"/sbin:/system/sbin:/system/bin:/system/xbin:/data/adb/magisk:/data/adb/ksu:/data/adb/ksud:/data/adb/apatch:$PATH\"\n")
        with open(filepath, "w") as f:
            f.write(content)
        print(f"Patched {filepath}")

patch_file("morphe_manager/www/cgi-bin/install.sh")
patch_file("morphe_manager/www/cgi-bin/config.sh")
patch_file("morphe_manager/auto_update.sh")
patch_file("morphe_manager/service.sh")
