with open("morphe_manager/customize.sh", "r") as f:
    content = f.read()

if "daemon.sh" not in content:
    content = content.replace("set_perm $MODPATH/service.sh 0 0 0755", "set_perm $MODPATH/service.sh 0 0 0755\nset_perm $MODPATH/daemon.sh 0 0 0755")
    with open("morphe_manager/customize.sh", "w") as f:
        f.write(content)
