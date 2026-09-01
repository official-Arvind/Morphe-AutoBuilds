#!/system/bin/sh
export PATH="/sbin:/system/sbin:/system/bin:/system/xbin:/data/adb/magisk:/data/adb/ksu:/data/adb/ksud:/data/adb/apatch:$PATH"

MODDIR=${0%/*}
STATE_FILE="/data/adb/morphe_state.txt"

# Start Auto-Update Daemon in the background
sh $MODDIR/auto_update.sh &

# Check if we are in the middle of a double-flash operation
if [ -f "$STATE_FILE" ]; then
    # Give the system 10 seconds to fully boot up services
    sleep 10
    
    # Optional: Trigger an Android Toast Notification (requires an app or tricky command, fallback to log)
    cmd notification post -t 'Morphe Manager' 'Flashing remaining modules...' || true
    
    # Read the pending zip paths
    while IFS= read -r PENDING_ZIP; do
        if [ -f "$PENDING_ZIP" ]; then
            magisk --install-module "$PENDING_ZIP"
            rm -f "$PENDING_ZIP"
        fi
    done < "$STATE_FILE"
    
    # Delete the state file so we don't loop infinitely
    rm -f "$STATE_FILE"
    
    # Reboot again cleanly
    svc power reboot
    exit 0
fi

# Normal boot: Start the web UI server on port 8080 serving the www folder
chmod -R 755 $MODDIR/www/cgi-bin 2>/dev/null
busybox httpd -p 8080 -h $MODDIR/www
