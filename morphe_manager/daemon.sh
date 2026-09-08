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
                
                # Check if this module requires flashing twice (e.g. YouTube, YouTube Music, or explicitly tagged)
                IS_DOUBLE_FLASH=false
                URL_LOWER=$(echo "$URL $FILEPATH" | tr '[:upper:]' '[:lower:]')
                case "$URL_LOWER" in
                    *youtube*|*yt-music*|*ytmusic*)
                        IS_DOUBLE_FLASH=true
                        ;;
                esac

                # Check module.prop inside zip
                PROP_CONTENT=$(unzip -p "$FILEPATH" module.prop 2>/dev/null || busybox unzip -p "$FILEPATH" module.prop 2>/dev/null)
                PROP_LOWER=$(echo "$PROP_CONTENT" | tr '[:upper:]' '[:lower:]')
                case "$PROP_LOWER" in
                    *youtube*|*flash_twice=true*|*double_flash=true*|*twice*)
                        IS_DOUBLE_FLASH=true
                        ;;
                esac

                # First flash pass
                FLASH_PASS1_LOG=$(flash_module "$FILEPATH" 2>&1)
                echo "$FLASH_PASS1_LOG" >> "$PROG_FILE"

                # Also inspect flash pass 1 output for messages requiring a second flash
                LOG_LOWER=$(echo "$FLASH_PASS1_LOG" | tr '[:upper:]' '[:lower:]')
                case "$LOG_LOWER" in
                    *"flash twice"*|*"flashing twice"*|*"flash again"*|*"reflash"*|*"re-flash"*|*"second flash"*|*"flash the module again"*|*"flash module again"*)
                        IS_DOUBLE_FLASH=true
                        ;;
                esac

                if [ "$IS_DOUBLE_FLASH" = "true" ]; then
                    echo "[-] Notice: Module requires flashing twice (e.g. YouTube). Running automatic 2nd flash pass..." >> "$PROG_FILE"
                    sleep 2
                    FLASH_PASS2_LOG=$(flash_module "$FILEPATH" 2>&1)
                    echo "$FLASH_PASS2_LOG" >> "$PROG_FILE"
                    echo "[✓] Automatic 2nd flash pass completed successfully." >> "$PROG_FILE"
                fi

                echo "[✓] Module $COUNTER installation finished." >> "$PROG_FILE"
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
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
