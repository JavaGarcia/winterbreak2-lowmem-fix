#!/bin/sh
# Keeps the jailbreak's gandalf (su) usable on Kindle PW2 FW 5.12.2.2.
# Observed: after reboot gandalf loses its setuid bit (and jb.sh's symlinks in
# /var/local/kmc and /var/local/mkk disappear). Without setuid, scriptlets/KUAL
# fail with "Application Error". Started by /etc/upstart/kd_watch.conf.
# Never touches /mnt/us: an open file there blocks USB mass-storage mode.
P=kindlepw2
B=/var/local/kmc/$P/bin
LOG=/var/local/kmc/kd_watch.log
fix_gandalf() {
    [ -f "$B/gandalf" ] || { echo "$(date) no gandalf" >> "$LOG"; return; }
    # Hard links / real dirs instead of jb.sh's symlinks
    mkdir -p /var/local/kmc/bin /var/local/kmc/lib /var/local/mkk
    for f in "$B"/*; do [ -e "/var/local/kmc/bin/${f##*/}" ] || ln "$f" "/var/local/kmc/bin/${f##*/}"; done
    for f in /var/local/kmc/$P/lib/*; do [ -e "/var/local/kmc/lib/${f##*/}" ] || ln "$f" "/var/local/kmc/lib/${f##*/}"; done
    [ -e /var/local/mkk/gandalf ] || ln "$B/gandalf" /var/local/mkk/gandalf
    [ -e /var/local/mkk/su ] || ln "$B/gandalf" /var/local/mkk/su
    [ -e "$B/su" ] || ln "$B/gandalf" "$B/su"
    chown root:root "$B/gandalf"; chmod 6755 "$B/gandalf"
    echo "$(date) up=$(cut -d' ' -f1 /proc/uptime)s $1: $(ls -l "$B/gandalf")" >> "$LOG"
}
[ -f "$LOG" ] && tail -n 200 "$LOG" > "$LOG.old"
echo "$(date) up=$(cut -d' ' -f1 /proc/uptime)s start" > "$LOG"
fix_gandalf boot
# Every 10 s for 15 min, then every 5 min (sleeping does not prevent device suspend)
i=0
while :; do
    if [ $i -lt 90 ]; then sleep 10; else sleep 300; fi
    i=$((i+1))
    [ -u "$B/gandalf" ] || fix_gandalf "lost"
done
