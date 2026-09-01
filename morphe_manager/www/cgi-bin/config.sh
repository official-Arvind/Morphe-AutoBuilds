#!/system/bin/sh
export PATH="/data/adb/modules/morphe_manager/bin:/sbin:/system/sbin:/system/bin:/system/xbin:/data/adb/magisk:/data/adb/ksu:/data/adb/ksud:/data/adb/apatch:$PATH"
echo "Content-type: application/json"
echo ""

CONFIG_FILE="/data/adb/morphe_config.json"

if [ "$REQUEST_METHOD" = "POST" ]; then
    read -r POST_DATA
    # Basic JSON extraction
    ENABLED=$(echo "$POST_DATA" | grep -o '"enabled":[^,}]*' | cut -d'"' -f4)
    TIME=$(echo "$POST_DATA" | grep -o '"time":[^,}]*' | cut -d'"' -f4)
    
    echo "{\"enabled\": \"$ENABLED\", \"time\": \"$TIME\"}" > "$CONFIG_FILE"
    echo "{\"status\":\"ok\"}"
else
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    else
        echo "{\"enabled\":\"false\", \"time\":\"03:00\"}"
    fi
fi
