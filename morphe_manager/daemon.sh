#!/system/bin/sh
export PATH="/sbin:/system/sbin:/system/bin:/system/xbin:/data/adb/magisk:/data/adb/ksu:/data/adb/ksud:/data/adb/apatch:$PATH"

TMP_DIR="/data/local/tmp/morphe_flasher"
REQ_FILE="$TMP_DIR/request.txt"
PROG_FILE="$TMP_DIR/progress.txt"

mkdir -p "$TMP_DIR"
chmod 777 "$TMP_DIR"
rm -f "$REQ_FILE" "$PROG_FILE"

download_file() {
    local FILE="$1"
    local URL="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -f -L -s -o "$FILE" "$URL"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$FILE" "$URL"
    elif command -v busybox >/dev/null 2>&1; then
        busybox wget -q -O "$FILE" "$URL"
    else
        echo "ERROR: Missing download binaries." >> "$PROG_FILE"
        return 1
    fi
}

flash_module() {
    local ZIP="$1"
    if command -v magisk >/dev/null 2>&1; then
        magisk --install-module "$ZIP"
    elif command -v ksud >/dev/null 2>&1; then
        ksud module install "$ZIP"
    elif command -v apatch >/dev/null 2>&1; then
        apatch module install "$ZIP"
    elif [ -f "/data/adb/magisk/magisk" ]; then
        /data/adb/magisk/magisk --install-module "$ZIP"
    elif [ -f "/data/adb/ksu/ksud" ]; then
        /data/adb/ksu/ksud module install "$ZIP"
    elif [ -f "/data/adb/apatch/apatch" ]; then
        /data/adb/apatch/apatch module install "$ZIP"
    else
        echo "ERROR: Neither Magisk, KernelSU, nor APatch detected. Are you even rooted? (PATH=$PATH)" 
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
            
            if [ -f "$FILEPATH" ] && unzip -t "$FILEPATH" > /dev/null 2>&1; then
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
