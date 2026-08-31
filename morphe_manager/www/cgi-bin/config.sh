#!/system/bin/sh
echo "Content-type: application/json"
echo ""

CONFIG_FILE="/data/adb/morphe_config.json"

if [ "$REQUEST_METHOD" = "GET" ]; then
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    else
        echo '{"enabled": "false", "time": "03:00"}'
    fi
elif [ "$REQUEST_METHOD" = "POST" ]; then
    read -r POST_DATA
    
    # Extract enabled and time fields
    ENABLED=$(echo "$POST_DATA" | grep -o '"enabled":"[^"]*"' | cut -d'"' -f4)
    TIME=$(echo "$POST_DATA" | grep -o '"time":"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$ENABLED" ]; then ENABLED=$(echo "$POST_DATA" | grep -o '"enabled":[^,}]*' | cut -d':' -f2 | tr -d ' "'); fi
    
    echo "{\"enabled\": \"$ENABLED\", \"time\": \"$TIME\"}" > "$CONFIG_FILE"
    
    # Restart daemon
    sh /data/adb/modules/morphe_manager/auto_update.sh &
    
    echo '{"status": "success"}'
fi
