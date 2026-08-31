#!/system/bin/sh
CONFIG_FILE="/data/adb/morphe_config.json"
REPO="official-Arvind/Morphe-AutoBuilds"

# Kill any existing instance of auto_update daemon (prevent duplicates)
for pid in $(pgrep -f "morphe_manager/auto_update.sh"); do
    if [ "$pid" != "$$" ]; then
        kill -9 $pid
    fi
done

while true; do
    # Sleep 10 minutes between checks
    sleep 600

    if [ -f "$CONFIG_FILE" ]; then
        ENABLED=$(grep -o '"enabled": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
        TARGET_TIME=$(grep -o '"time": "[^"]*"' "$CONFIG_FILE" | cut -d'"' -f4)
        
        if [ "$ENABLED" = "true" ] && [ -n "$TARGET_TIME" ]; then
            CURRENT_TIME=$(date +%H:%M)
            
            # Allow a small window to match (since we check every 10 min)
            # The target time is like "03:00". We check if current time starts with the same hour, 
            # and minutes are within the 10 min window.
            TH=${TARGET_TIME%:*}
            TM=${TARGET_TIME#*:}
            CH=${CURRENT_TIME%:*}
            CM=${CURRENT_TIME#*:}
            
            if [ "$TH" = "$CH" ]; then
                DIFF=$(( 10#$CM - 10#$TM ))
                # If current time is between Target and Target+9 minutes
                if [ "$DIFF" -ge 0 ] && [ "$DIFF" -lt 10 ]; then
                    
                    # We are in the update window! Trigger update!
                    TMP_DIR="/data/local/tmp/morphe_flasher"
                    rm -rf "$TMP_DIR"
                    mkdir -p "$TMP_DIR"
                    
                    # Fetch latest release
                    curl -s -o "$TMP_DIR/release.json" "https://api.github.com/repos/$REPO/releases/latest"
                    
                    # Get all zip URLs (excluding manager itself)
                    grep -o '"browser_download_url": "[^"]*\.zip"' "$TMP_DIR/release.json" | cut -d'"' -f4 | grep -v 'morphe-manager' > "$TMP_DIR/update_urls.txt"
                    
                    if [ -s "$TMP_DIR/update_urls.txt" ]; then
                        COUNTER=1
                        while IFS= read -r URL; do
                            FILEPATH="$TMP_DIR/module_${COUNTER}.zip"
                            curl -L -s -o "$FILEPATH" "$URL"
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
                                    magisk --install-module "$ZIP"
                                    rm -f "$ZIP"
                                    FIRST=false
                                else
                                    echo "$ZIP" >> "$STATE_FILE"
                                fi
                            done < "$TMP_DIR/zip_list.txt"
                            
                            # Reboot system
                            su -c svc power reboot &
                        fi
                    fi
                    
                    # Prevent multiple runs during the same 10 min window
                    sleep 3600
                fi
            fi
        fi
    fi
done
