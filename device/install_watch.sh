#!/bin/sh
# Installs the gandalf setuid watcher (run as root on the Kindle, e.g. from a scriptlet).
# Copies kd_watch.sh to /var/local/kmc and an upstart job to /etc/upstart (rootfs is remounted rw briefly).
set -e
D=$(dirname "$0")
cp "$D/kd_watch.sh" /var/local/kmc/kd_watch.sh
chmod 755 /var/local/kmc/kd_watch.sh
mount -o remount,rw /
cp "$D/kd_watch.conf" /etc/upstart/kd_watch.conf
chmod 644 /etc/upstart/kd_watch.conf
sync
mount -o remount,ro /
start kd_watch || true
status kd_watch
ls -l /var/local/kmc/kindlepw2/bin/gandalf
