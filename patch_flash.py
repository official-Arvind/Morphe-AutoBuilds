with open("morphe_manager/www/cgi-bin/install.sh", "r") as f:
    content = f.read()

new_flash = """flash_module() {
    local ZIP="$1"
    local LOG="$2"

    if command -v magisk >/dev/null 2>&1; then
        magisk --install-module "$ZIP" > "$LOG" 2>&1
    elif command -v ksud >/dev/null 2>&1; then
        ksud module install "$ZIP" > "$LOG" 2>&1
    elif command -v apatch >/dev/null 2>&1; then
        apatch module install "$ZIP" > "$LOG" 2>&1
    elif [ -f "/data/adb/magisk/magisk" ]; then
        /data/adb/magisk/magisk --install-module "$ZIP" > "$LOG" 2>&1
    elif [ -f "/data/adb/ksu/ksud" ]; then
        /data/adb/ksu/ksud module install "$ZIP" > "$LOG" 2>&1
    elif [ -f "/data/adb/apatch/apatch" ]; then
        /data/adb/apatch/apatch module install "$ZIP" > "$LOG" 2>&1
    else
        echo "ERROR: Neither Magisk, KernelSU, nor APatch detected. Are you even rooted? (PATH=$PATH)" > "$LOG"
        return 1
    fi
}"""

import re
content = re.sub(r'flash_module\(\) \{.*?return 1\n    fi\n\}', new_flash, content, flags=re.DOTALL)

with open("morphe_manager/www/cgi-bin/install.sh", "w") as f:
    f.write(content)

