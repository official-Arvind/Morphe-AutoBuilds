#!/system/bin/sh
export PATH="/data/adb/modules/morphe_manager/bin:/sbin:/system/sbin:/system/bin:/system/xbin:/data/adb/magisk:/data/adb/ksu:/data/adb/ksud:/data/adb/apatch:$PATH"
echo "Content-type: application/json"
echo ""

CONFIG_FILE="/data/adb/morphe_config.json"

DEVICE_ABI=$(getprop ro.product.cpu.abi)
[ -z "$DEVICE_ABI" ] && DEVICE_ABI="unknown"
DEVICE_MODEL=$(getprop ro.product.model)
[ -z "$DEVICE_MODEL" ] && DEVICE_MODEL="Android Device"
DEVICE_RELEASE=$(getprop ro.build.version.release)
[ -z "$DEVICE_RELEASE" ] && DEVICE_RELEASE="11"

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
    echo "{\"status\":\"ok\", \"enabled\":\"$ENABLED\", \"time\":\"$TIME\", \"device_abi\":\"$DEVICE_ABI\", \"device_model\":\"$DEVICE_MODEL\", \"device_release\":\"$DEVICE_RELEASE\"}"
else
    ENABLED="false"
    TIME="03:00"
    if [ -f "$CONFIG_FILE" ] && [ -s "$CONFIG_FILE" ]; then
        CONF=$(cat "$CONFIG_FILE")
        case "$CONF" in
            *enabled*true*) ENABLED="true" ;;
            *) ENABLED="false" ;;
        esac
        SAVED_TIME=$(echo "$CONF" | sed -n 's/.*time[^0-9]*\([0-9]*:[0-9]*\).*/\1/p')
        [ -n "$SAVED_TIME" ] && TIME="$SAVED_TIME"
    fi
    echo "{\"enabled\":\"$ENABLED\", \"time\":\"$TIME\", \"device_abi\":\"$DEVICE_ABI\", \"device_model\":\"$DEVICE_MODEL\", \"device_release\":\"$DEVICE_RELEASE\"}"
fi

