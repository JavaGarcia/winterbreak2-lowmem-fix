#!/bin/sh
# Read-only jailbreak diagnostics. Writes /mnt/us/jb_diag.txt
OUT=/mnt/us/jb_diag.txt
{
echo "== date"; date
echo "== kmc tree"; ls -laR /var/local/kmc 2>&1 | head -80
echo "== mkk"; ls -la /var/local/mkk 2>&1
echo "== lsattr gandalf"; lsattr /var/local/kmc/kindlepw2/bin/gandalf 2>&1
echo "== su test"; /var/local/mkk/su -c id 2>&1
echo "== su test as framework"; su framework -s /bin/sh -c '/var/local/mkk/su -c id' 2>&1
echo "== launcher run"; /var/local/kmc/bin/sh_integration_launcher --help 2>&1 | head -5
echo "== libkh"; ls -la /mnt/us/libkh/bin 2>&1
echo "== appreg launcher"; echo "SELECT * FROM properties WHERE handlerId LIKE 'tech.hackerdude%';" | sqlite3 /var/local/appreg.db 2>&1
echo "== appreg assoc sh"; echo "SELECT * FROM associations WHERE contentId LIKE '%shellscript%' OR contentId LIKE '%.sh';" | sqlite3 /var/local/appreg.db 2>&1
echo "== pubdevkey"; ls -la /etc/uks 2>&1; md5sum /etc/uks/pubdevkey01.pem 2>&1
echo "== keystore"; md5sum /var/local/java/keystore/developer.keystore 2>&1
echo "== ccat so"; ls -la /usr/lib/ccat/sh_integration_extractor.so 2>&1
echo "== ota"; ls -la /usr/bin/otaupd* /usr/bin/otav3* 2>&1
echo "== upstart"; ls -la /etc/upstart/kmc.conf 2>&1
echo "== logThis"; ls -la /usr/bin/logThis.sh 2>&1
echo "== messages"; (cat /var/log/messages 2>/dev/null; logread 2>/dev/null) | grep -iE 'shell_integration|sh_integration|hackerdude|appmgr.*(fail|error)|KUAL|gandalf|JB_SH' | tail -60
echo "== done"
} > "$OUT" 2>&1
sync
eips 0 38 "jb_diag: done" 2>/dev/null
