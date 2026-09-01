#!/system/bin/sh
export PATH="/data/adb/modules/morphe_manager/bin:/sbin:/system/sbin:/system/bin:/system/xbin:/data/adb/magisk:/data/adb/ksu:/data/adb/ksud:/data/adb/apatch:$PATH"

TMP_DIR="/data/local/tmp/morphe_flasher"
REQ_FILE="$TMP_DIR/request.txt"
PROG_FILE="$TMP_DIR/progress.txt"

mkdir -p "$TMP_DIR"
chmod 777 "$TMP_DIR"
rm -f "$REQ_FILE" "$PROG_FILE"

download_file() {
    local FILE="$1"
    local URL="$2"
    local SUCCESS=false

    if command -v curl >/dev/null 2>&1; then
        if curl -k -f -L -s -o "$FILE" "$URL"; then
            SUCCESS=true
        fi
    fi

    if [ "$SUCCESS" = "false" ] && command -v wget >/dev/null 2>&1; then
        if wget --no-check-certificate -q -O "$FILE" "$URL"; then
            SUCCESS=true
        fi
    fi

    if [ "$SUCCESS" = "false" ] && command -v busybox >/dev/null 2>&1; then
        if busybox wget --no-check-certificate -q -O "$FILE" "$URL"; then
            SUCCESS=true
        fi
    fi

    if [ "$SUCCESS" = "false" ]; then
        return 1
    fi
}

flash_module() {
    local ZIP="$1"
    local INSTALLER=""
    local CMD=""

    # 1. Search for Magisk (Latest & Legacy paths)
    for p in "/data/adb/magisk/magisk" "/sbin/magisk" "/system/bin/magisk" "/system/xbin/magisk"; do
        if [ -f "$p" ] && [ -x "$p" ]; then INSTALLER="$p"; CMD="--install-module"; break; fi
    done

    # 2. Search for KernelSU (ksud)
    if [ -z "$INSTALLER" ]; then
        for p in "/data/adb/ksu/bin/ksud" "/data/adb/ksu/ksud" "/system/bin/ksud" "/sbin/ksud" "/system/xbin/ksud" "/data/adb/ksu/bin/ksu"; do
            if [ -f "$p" ] && [ -x "$p" ]; then INSTALLER="$p"; CMD="module install"; break; fi
        done
    fi

    # 3. Search for APatch (apatch / apd)
    if [ -z "$INSTALLER" ]; then
        for p in "/data/adb/ap/bin/apatch" "/data/adb/ap/bin/apd" "/data/adb/apatch/apatch" "/data/adb/apatch/apd" "/system/bin/apatch" "/system/bin/apd" "/sbin/apatch" "/sbin/apd"; do
            if [ -f "$p" ] && [ -x "$p" ]; then INSTALLER="$p"; CMD="module install"; break; fi
        done
    fi

    # 4. Fallback to env PATH
    if [ -z "$INSTALLER" ]; then
        if command -v magisk >/dev/null 2>&1; then INSTALLER=$(command -v magisk); CMD="--install-module"; fi
    fi
    if [ -z "$INSTALLER" ]; then
        if command -v ksud >/dev/null 2>&1; then INSTALLER=$(command -v ksud); CMD="module install"; fi
    fi
    if [ -z "$INSTALLER" ]; then
        if command -v apatch >/dev/null 2>&1; then INSTALLER=$(command -v apatch); CMD="module install"; fi
    fi
    if [ -z "$INSTALLER" ]; then
        if command -v apd >/dev/null 2>&1; then INSTALLER=$(command -v apd); CMD="module install"; fi
    fi

    if [ -n "$INSTALLER" ]; then
        echo "Using root manager: $INSTALLER $CMD"
        $INSTALLER $CMD "$ZIP"
    else
        echo "ERROR: Root manager binary not found! Tried Magisk, KernelSU, and APatch paths."
        return 1
    fi
}

while true; do
    if [ -f "$REQ_FILE" ]; then
        URLS=$(cat "$REQ_FILE")
        rm -f "$REQ_FILE"
        
        echo "Starting download and flash..." > "$PROG_FILE"
        chmod 666 "$PROG_FILE"
        
        TOTAL_COUNT=$(echo "$URLS" | wc -w)
        COUNTER=1
        SUCCESS_COUNT=0
        
        for URL in $URLS; do
            FILEPATH="$TMP_DIR/module_${COUNTER}.zip"
            
            echo "[-] Downloading module $COUNTER ($URL)..." >> "$PROG_FILE"
            download_file "$FILEPATH" "$URL"
            
            if [ -f "$FILEPATH" ] && (unzip -t "$FILEPATH" > /dev/null 2>&1 || busybox unzip -t "$FILEPATH" > /dev/null 2>&1); then
                echo "[-] Downloaded successfully. Flashing..." >> "$PROG_FILE"
                
                # Append output of flash directly to progress
                if flash_module "$FILEPATH" >> "$PROG_FILE" 2>&1; then
                    echo "[✓] Flashed module $COUNTER successfully." >> "$PROG_FILE"
                    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
                else
                    echo "[x] Flashing failed for module $COUNTER." >> "$PROG_FILE"
                fi
                rm -f "$FILEPATH"
            else
                echo "[x] ERROR: Download failed or ZIP corrupt." >> "$PROG_FILE"
                rm -f "$FILEPATH"
            fi
            COUNTER=$((COUNTER+1))
        done
        
        if [ "$SUCCESS_COUNT" -gt 0 ]; then
            echo "STATUS: SUCCESS ($SUCCESS_COUNT/$TOTAL_COUNT). Rebooting in 5s..." >> "$PROG_FILE"
            sleep 5
            svc power reboot || reboot
        else
            echo "STATUS: FAILURE" >> "$PROG_FILE"
        fi
    fi
    sleep 2
done
