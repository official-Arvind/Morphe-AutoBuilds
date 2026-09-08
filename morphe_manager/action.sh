#!/system/bin/sh
MODDIR=${0%/*}
# Ensure service is running
if ! pgrep -f "httpd.*8080" >/dev/null 2>&1; then
    sh $MODDIR/service.sh
fi
# Launch WebUI via Intent
am start -a android.intent.action.VIEW -d "http://127.0.0.1:8080"
