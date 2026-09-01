#!/system/bin/sh
export PATH="/sbin:/system/sbin:/system/bin:/system/xbin:/data/adb/magisk:/data/adb/ksu:/data/adb/ksud:/data/adb/apatch:$PATH"

echo "Content-type: text/plain"
echo ""

read -r POST_DATA

# Super simple JSON extractor to avoid needing jq on device
URLS=$(echo "$POST_DATA" | grep -o '"https://[^"]*"' | sed 's/"//g')
TMP_DIR="/data/local/tmp/morphe_flasher"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

if [ -z "$URLS" ]; then
    echo "ERROR: Are you sending me empty air? No URLs provided."
    exit 1
fi

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
        echo "ERROR: Your system is so barebones it doesn't even have curl or wget."
        return 1
    fi
}

flash_module() {
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
}

COUNTER=1
SUCCESS_COUNT=0
TOTAL_COUNT=$(echo "$URLS" | wc -w)

echo "Starting download and flash for $TOTAL_COUNT modules..." >> "$TMP_DIR/master_log.txt"

for URL in $URLS; do
    FILEPATH="$TMP_DIR/module_${COUNTER}.zip"
    LOGPATH="$TMP_DIR/flash_log_${COUNTER}.txt"
    
    echo "[-] Downloading module $COUNTER..." >> "$TMP_DIR/master_log.txt"
    download_file "$FILEPATH" "$URL"
    
    if [ -f "$FILEPATH" ] && unzip -t "$FILEPATH" > /dev/null 2>&1; then
        echo "[-] Downloaded successfully. Flashing..." >> "$TMP_DIR/master_log.txt"
        
        if flash_module "$FILEPATH" "$LOGPATH"; then
            echo "[✓] Flashed module $COUNTER successfully." >> "$TMP_DIR/master_log.txt"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            echo "[x] Flashing failed for module $COUNTER." >> "$TMP_DIR/master_log.txt"
            cat "$LOGPATH" >> "$TMP_DIR/master_log.txt"
        fi
        
        # Clean up zip after flashing attempt to save space
        rm -f "$FILEPATH"
    else
        echo "[x] ERROR: Download failed or ZIP is corrupt for: $URL" >> "$TMP_DIR/master_log.txt"
        rm -f "$FILEPATH"
    fi
    COUNTER=$((COUNTER+1))
done

if [ "$SUCCESS_COUNT" -gt 0 ]; then
    echo "SUCCESS: Flashed $SUCCESS_COUNT out of $TOTAL_COUNT modules."
    # Wait a few seconds and reboot
    (sleep 3 && svc power reboot || reboot) &
    exit 0
else
    echo "ERROR: Absolute failure. Read the logs below to see how badly it went."
    cat "$TMP_DIR/master_log.txt"
    exit 1
fi
