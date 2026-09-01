with open("morphe_manager/service.sh", "r") as f:
    content = f.read()

if "daemon.sh" not in content:
    content = content.replace("sh $MODDIR/auto_update.sh &", "sh $MODDIR/auto_update.sh &\n# Start IPC daemon for WebUI flashing\nsh $MODDIR/daemon.sh &")
    with open("morphe_manager/service.sh", "w") as f:
        f.write(content)
