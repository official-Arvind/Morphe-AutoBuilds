#!/system/bin/sh
export PATH="/data/adb/modules/morphe_manager/bin:/sbin:/system/sbin:/system/bin:/system/xbin:/data/adb/magisk:/data/adb/ksu:/data/adb/ksud:/data/adb/apatch:$PATH"

echo "Content-type: text/plain"
echo ""

if [ -n "$CONTENT_LENGTH" ] && [ "$CONTENT_LENGTH" -gt 0 ] 2>/dev/null; then
    POST_DATA=$(head -c "$CONTENT_LENGTH")
else
    read -r POST_DATA
fi
POST_DATA=$(echo "$POST_DATA" | tr -d '\\')
URLS=$(echo "$POST_DATA" | tr -s '",[]{} \t\r\n' '\n' | grep '^https://')

TMP_DIR="/data/local/tmp/morphe_flasher"
REQ_FILE="$TMP_DIR/request.txt"

mkdir -p "$TMP_DIR"
chmod 777 "$TMP_DIR"

if [ -z "$URLS" ]; then
    echo "ERROR: No URLs provided."
    exit 1
fi

echo "$URLS" > "$REQ_FILE"
chmod 666 "$REQ_FILE"

echo "QUEUED"
