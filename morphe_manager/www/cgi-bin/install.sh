#!/system/bin/sh
echo "Content-type: text/plain"
echo ""

read -r POST_DATA
# Super simple JSON extractor to avoid needing jq on device
URLS=$(echo "$POST_DATA" | grep -o '"https://[^"]*"' | sed 's/"//g')

STATE_FILE="/data/adb/morphe_state.txt"
TMP_DIR="/data/local/tmp/morphe_flasher"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

if [ -z "$URLS" ]; then
    echo "ERROR: No URLs provided."
    exit 1
fi

COUNTER=1
for URL in $URLS; do
    FILEPATH="$TMP_DIR/module_${COUNTER}.zip"
    
    curl -L -s -o "$FILEPATH" "$URL"
    
    if [ -f "$FILEPATH" ] && unzip -t "$FILEPATH" > /dev/null 2>&1; then
        echo "$FILEPATH" >> "$TMP_DIR/zip_list.txt"
    else
        echo "ERROR: Download failed or invalid zip for $URL"
        rm -f "$FILEPATH"
    fi
    COUNTER=$((COUNTER+1))
done

if [ -f "$TMP_DIR/zip_list.txt" ]; then
    FIRST=true
    while IFS= read -r ZIP; do
        if $FIRST; then
            # Flash the first one immediately in this context
            if magisk --install-module "$ZIP" > "$TMP_DIR/flash_log.txt" 2>&1; then
                rm -f "$ZIP"
                FIRST=false
            else
                echo "ERROR: Magisk install failed for first module."
                cat "$TMP_DIR/flash_log.txt"
                exit 1
            fi
        else
            # Queue remaining for the boot script
            echo "$ZIP" >> "$STATE_FILE"
        fi
    done < "$TMP_DIR/zip_list.txt"
    
    echo "SUCCESS"
    # Reboot in background so response reaches client
    (sleep 2 && su -c svc power reboot) &
    exit 0
else
    echo "ERROR: No valid modules downloaded."
    exit 1
fi
