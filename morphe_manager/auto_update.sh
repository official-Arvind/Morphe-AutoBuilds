#!/system/bin/sh
export PATH="/data/adb/modules/morphe_manager/bin:/sbin:/system/sbin:/system/bin:/system/xbin:/data/adb/magisk:/data/adb/ksu:/data/adb/ksud:/data/adb/apatch:$PATH"
CONFIG_FILE="/data/adb/morphe_config.json"
REPO="official-Arvind/Morphe-AutoBuilds"

# Kill any existing instance of auto_update daemon
for pid in $(pgrep -f "auto_update.sh"); do
    if [ "$pid" != "$$" ]; then
        kill -9 $pid >/dev/null 2>&1
    fi
done

download_file() {
    local FILE="$1"
    local URL="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -f -L -s -o "$FILE" "$URL"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$FILE" "$URL"
    elif command -v busybox >/dev/null 2>&1; then
        busybox wget -q -O "$FILE" "$URL"
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
    # Sleep 10 minutes between checks
    sleep 600

    if [ -f "$CONFIG_FILE" ]; then
        ENABLED=$(grep -o '"enabled": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
        TARGET_TIME=$(grep -o '"time": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
        
        if [ "$ENABLED" = "true" ] && [ -n "$TARGET_TIME" ]; then
            CURRENT_TIME=$(date +%H:%M)
            TH=${TARGET_TIME%:*}
            TM=${TARGET_TIME#*:}
            CH=${CURRENT_TIME%:*}
            CM=${CURRENT_TIME#*:}
            
            if [ "$TH" = "$CH" ]; then
                DIFF=$(( 10#$CM - 10#$TM ))
                # Within 10 min window
                if [ "$DIFF" -ge 0 ] && [ "$DIFF" -lt 10 ]; then
                    TMP_DIR="/data/local/tmp/morphe_flasher"
                    rm -rf "$TMP_DIR"
                    mkdir -p "$TMP_DIR"
                    
                    download_file "$TMP_DIR/release.json" "https://api.github.com/repos/$REPO/releases/latest"
                    
                    if [ -f "$TMP_DIR/release.json" ]; then
                        # Get all zip URLs (excluding manager itself)
                        grep -o '"browser_download_url": "[^"]*\.zip"' "$TMP_DIR/release.json" | cut -d'"' -f4 | grep -v 'morphe-manager' > "$TMP_DIR/update_urls.txt"
                        
                        if [ -s "$TMP_DIR/update_urls.txt" ]; then
                            COUNTER=1
                            while IFS= read -r URL; do
                                FILEPATH="$TMP_DIR/module_${COUNTER}.zip"
                                download_file "$FILEPATH" "$URL"
                                if [ -f "$FILEPATH" ] && unzip -t "$FILEPATH" > /dev/null 2>&1; then
                                    echo "$FILEPATH" >> "$TMP_DIR/zip_list.txt"
                                else
                                    rm -f "$FILEPATH"
                                fi
                                COUNTER=$((COUNTER+1))
                            done < "$TMP_DIR/update_urls.txt"
                            
                            if [ -f "$TMP_DIR/zip_list.txt" ]; then
                                STATE_FILE="/data/adb/morphe_state.txt"
                                FIRST=true
                                while IFS= read -r ZIP; do
                                    if $FIRST; then
                                        flash_module "$ZIP"
                                        rm -f "$ZIP"
                                        FIRST=false
                                    else
                                        echo "$ZIP" >> "$STATE_FILE"
                                    fi
                                done < "$TMP_DIR/zip_list.txt"
                                
                                # Reboot system
                                svc power reboot &
                            fi
                        fi
                    fi
                    
                    # Prevent multiple runs during the same 10 min window
                    sleep 3600
                fi
            fi
        fi
    fi
done
