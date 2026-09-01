#!/system/bin/sh

ui_print "- Installing Morphe Manager WebUI"
ui_print "- Setting permissions..."
set_perm_recursive $MODPATH/bin 0 0 0755 0755

# Default magisk permissions for module
set_perm_recursive $MODPATH 0 0 0755 0644

# Ensure scripts in cgi-bin are fully executable!
set_perm_recursive $MODPATH/www/cgi-bin 0 0 0755 0755
set_perm $MODPATH/auto_update.sh 0 0 0755
set_perm $MODPATH/service.sh 0 0 0755
set_perm $MODPATH/daemon.sh 0 0 0755

ui_print "- Done!"
