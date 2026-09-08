#!/system/bin/sh
export PATH="/data/adb/modules/morphe_manager/bin:/sbin:/system/sbin:/system/bin:/system/xbin:/data/adb/magisk:/data/adb/ksu:/data/adb/ksud:/data/adb/apatch:$PATH"
echo "Content-type: application/json"
echo ""

CONFIG_FILE="/data/adb/morphe_config.json"

if [ "$REQUEST_METHOD" = "POST" ]; then
    if [ -n "$CONTENT_LENGTH" ] && [ "$CONTENT_LENGTH" -gt 0 ] 2>/dev/null; then
        POST_DATA=$(head -c "$CONTENT_LENGTH")
    else
        read -r POST_DATA
    fi
    # Unescape Busybox httpd auto-escaped characters
    POST_DATA=$(echo "$POST_DATA" | tr -d '\\')

    case "$POST_DATA" in
        *enabled*true*) ENABLED="true" ;;
        *) ENABLED="false" ;;
    esac
    TIME=$(echo "$POST_DATA" | sed -n 's/.*time[^0-9]*\([0-9]*:[0-9]*\).*/\1/p')
    [ -z "$TIME" ] && TIME="03:00"

    echo "{\"enabled\":\"$ENABLED\", \"time\":\"$TIME\"}" > "$CONFIG_FILE"
    chmod 666 "$CONFIG_FILE" 2>/dev/null || true
    echo "{\"status\":\"ok\", \"enabled\":\"$ENABLED\", \"time\":\"$TIME\"}"
else
    if [ -f "$CONFIG_FILE" ] && [ -s "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    else
        echo "{\"enabled\":\"false\", \"time\":\"03:00\"}"
    fi
fi
