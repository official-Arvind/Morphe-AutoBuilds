#!/system/bin/sh
echo "Content-type: text/plain"
echo ""

PROG_FILE="/data/local/tmp/morphe_flasher/progress.txt"
if [ -f "$PROG_FILE" ]; then
    cat "$PROG_FILE"
else
    echo "WAITING"
fi
