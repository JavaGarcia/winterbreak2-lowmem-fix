#!/bin/sh
# Reproducer (run as root on the Kindle). Decompresses the same tarball compressed with
# a 64 MiB and an 8/16 MiB LZMA2 dictionary and reports BusyBox xz's result and free memory.
# Prepare on a PC: kmc9.tar.xz (xz -9) and kmc16.tar.xz (xz -9e --lzma2=dict=16MiB) in the same dir.
D=$(dirname "$0")
for f in kmc9.tar.xz kmc16.tar.xz; do
    echo "== $f"; free | sed -n 2p
    { xz -dc "$D/$f"; echo "xz_exit=$?" >&2; } | md5sum
done
