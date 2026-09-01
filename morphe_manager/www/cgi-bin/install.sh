#!/system/bin/sh
export PATH="/sbin:/system/sbin:/system/bin:/system/xbin:/data/adb/magisk:/data/adb/ksu:/data/adb/ksud:/data/adb/apatch:$PATH"

echo "Content-type: text/plain"
echo ""

read -r POST_DATA
URLS=$(echo "$POST_DATA" | grep -o '"https://[^"]*"' | sed 's/"//g')

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
