#!/bin/sh
# Optional fallback, placed at /mnt/us/emergency.sh. jb.sh's /etc/upstart/kmc.conf runs it as root
# at boot *if* /mnt/us is already mounted (race: not every boot). Repairs once if kd_watch is absent.
# Must not leave processes running from /mnt/us (blocks USB mode).
[ -f /etc/upstart/kd_watch.conf ] && exit 0
B=/var/local/kmc/kindlepw2/bin
[ -f "$B/gandalf" ] || exit 0
mkdir -p /var/local/mkk
[ -e /var/local/mkk/su ] || ln "$B/gandalf" /var/local/mkk/su
[ -e /var/local/mkk/gandalf ] || ln "$B/gandalf" /var/local/mkk/gandalf
chown root:root "$B/gandalf"; chmod 6755 "$B/gandalf"
exit 0
