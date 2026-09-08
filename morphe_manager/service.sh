#!/system/bin/sh
MODDIR=${0%/*}

# Set up bundled busybox
ARCH=$(getprop ro.product.cpu.abi)
if [ -f "$MODDIR/bin/busybox-arm64" ] && [ "$ARCH" = "arm64-v8a" ]; then
    cp "$MODDIR/bin/busybox-arm64" "$MODDIR/bin/busybox" 2>/dev/null || true
elif [ -f "$MODDIR/bin/busybox-arm" ]; then
    cp "$MODDIR/bin/busybox-arm" "$MODDIR/bin/busybox" 2>/dev/null || true
fi
[ -f "$MODDIR/bin/busybox" ] && chmod 755 "$MODDIR/bin/busybox" 2>/dev/null || true

# Robust busybox resolution (bundled -> magisk -> ksu -> apatch -> system)
BUSYBOX=""
if [ -x "$MODDIR/bin/busybox" ] && "$MODDIR/bin/busybox" true 2>/dev/null; then
    BUSYBOX="$MODDIR/bin/busybox"
elif [ -x /data/adb/magisk/busybox ]; then
    BUSYBOX="/data/adb/magisk/busybox"
elif [ -x /data/adb/ksu/bin/busybox ]; then
    BUSYBOX="/data/adb/ksu/bin/busybox"
elif [ -x /data/adb/ap/bin/busybox ]; then
    BUSYBOX="/data/adb/ap/bin/busybox"
elif command -v busybox >/dev/null 2>&1; then
    BUSYBOX="$(command -v busybox)"
fi

export PATH="$MODDIR/bin:/sbin:/system/sbin:/system/bin:/system/xbin:/data/adb/magisk:/data/adb/ksu:/data/adb/ksud:/data/adb/apatch:$PATH"

STATE_FILE="/data/adb/morphe_state.txt"

# Start Auto-Update Daemon in the background if not running
if ! pgrep -f "$MODDIR/auto_update.sh" >/dev/null 2>&1; then
    sh $MODDIR/auto_update.sh &
fi

# Start IPC daemon for WebUI flashing if not running
if ! pgrep -f "$MODDIR/daemon.sh" >/dev/null 2>&1; then
    sh $MODDIR/daemon.sh &
fi

flash_module() {
    local ZIP="$1"
    for p in "/data/adb/magisk/magisk" "/sbin/magisk" "/system/bin/magisk" "/system/xbin/magisk"; do
        if [ -f "$p" ] && [ -x "$p" ]; then "$p" --install-module "$ZIP"; return $?; fi
    done
    for p in "/data/adb/ksu/bin/ksud" "/data/adb/ksu/ksud" "/system/bin/ksud" "/sbin/ksud"; do
        if [ -f "$p" ] && [ -x "$p" ]; then "$p" module install "$ZIP"; return $?; fi
    done
    for p in "/data/adb/ap/bin/apatch" "/data/adb/ap/bin/apd" "/data/adb/apatch/apatch" "/data/adb/apatch/apd"; do
        if [ -f "$p" ] && [ -x "$p" ]; then "$p" module install "$ZIP"; return $?; fi
    done
    if command -v magisk >/dev/null 2>&1; then magisk --install-module "$ZIP"; return $?; fi
    if command -v ksud >/dev/null 2>&1; then ksud module install "$ZIP"; return $?; fi
    if command -v apatch >/dev/null 2>&1; then apatch module install "$ZIP"; return $?; fi
    return 1
}

# Check if we are in the middle of a double-flash operation
if [ -f "$STATE_FILE" ]; then
    # Give the system 10 seconds to fully boot up services
    sleep 10
    
    # Optional: Trigger an Android Toast Notification
    cmd notification post -t 'Morphe Manager' 'Flashing remaining modules...' || true
    
    # Read the pending zip paths
    while IFS= read -r PENDING_ZIP; do
        if [ -f "$PENDING_ZIP" ]; then
            flash_module "$PENDING_ZIP"
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
if [ -n "$BUSYBOX" ]; then
    if ! pgrep -f "httpd.*8080" >/dev/null 2>&1; then
        $BUSYBOX httpd -p 8080 -h $MODDIR/www
    fi
fi
