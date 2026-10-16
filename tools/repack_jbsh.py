#!/usr/bin/env python3
"""Repack the official jb.sh (KindleModding) so it installs on low-RAM Kindles.

jb.sh embeds its payload as `echo "<base64>" | base64 -d | xz -d | tar xf -`.
The payload is compressed with `xz -9` (64 MiB LZMA2 dictionary). BusyBox's
unxz must malloc() the full dictionary; on a 256 MB device with no swap that
allocation fails intermittently and BusyBox reports it as "corrupted data".
jb.sh does not check the result and continues with an empty /tmp/kmc.

This tool downloads jb.sh, verifies its SHA-256, and writes a bundle that:
  * ships the payload as a plain gzip tarball (tiny memory footprint),
  * runs the *unmodified* remainder of jb.sh (lines 6..end),
  * aborts before touching the system if extraction is incomplete.

Usage: python3 repack_jbsh.py [--version v2.2.1] [--sha256 HASH] [--platform kindlepw2|kindlehf|all] OUTDIR
"""
import argparse, base64, hashlib, io, lzma, os, sys, tarfile, urllib.request

KNOWN = {"v2.2.1": "cf60f9f95db3f0a25bea80bbe0c85f4de86d2f900be872f8d22d118163b708ba"}
PREFIX, SUFFIX = 'echo "', '" | base64 -d | xz -d | tar xf - -C /tmp/kmc'

RUNNER = r'''#!/bin/sh
# Runs jb.sh (repacked by winterbreak2-lowmem-fix) with a gzip payload. Log: /mnt/us/jb_lowmem.log
D=$(dirname "$0")
LOG=/mnt/us/jb_lowmem.log
{
echo "== start $(date)"; free
rm -rf /tmp/kmc; mkdir /tmp/kmc
tar xzf "$D/kmc.tar.gz" -C /tmp/kmc
echo "== extracted"; du -sk /tmp/kmc
for f in system_patches/patch_system.sh sql/appreg_register_sh_integration_common.sql; do
    [ -f "/tmp/kmc/$f" ] || { echo "ABORT: missing $f"; eips 0 38 "jb_lowmem: extraction failed, see jb_lowmem.log"; exit 1; }
done
ls /tmp/kmc/*/bin/gandalf >/dev/null 2>&1 || { echo "ABORT: missing gandalf"; exit 1; }
echo "== running jb.sh body"
RUN_MODE=1 JB_HEADER="${JB_HEADER:-Winterbreak2 Jailbreak}" sh "$D/jb_body.sh"
echo "== jb.sh exit $?"
} > "$LOG" 2>&1
sync
'''

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("outdir")
    ap.add_argument("--version", default="v2.2.1")
    ap.add_argument("--sha256", help="expected SHA-256 (required for versions not in KNOWN)")
    ap.add_argument("--platform", default="kindlepw2", choices=["kindlepw2", "kindlehf", "all"])
    ap.add_argument("--jbsh", help="use a local jb.sh instead of downloading")
    a = ap.parse_args()

    if a.jbsh:
        data = open(a.jbsh, "rb").read()
    else:
        url = f"https://github.com/KindleModding/jb.sh/releases/download/{a.version}/jb.sh"
        print("downloading", url)
        data = urllib.request.urlopen(url).read()
    digest = hashlib.sha256(data).hexdigest()
    want = a.sha256 or KNOWN.get(a.version)
    if not want:
        sys.exit(f"no known hash for {a.version}; got {digest}. Verify it and pass --sha256.")
    if digest != want:
        sys.exit(f"SHA-256 mismatch: {digest} != {want}")

    lines = data.decode().split("\n")
    line = lines[4]
    if not (line.startswith(PREFIX) and line.endswith(SUFFIX)):
        sys.exit("unexpected jb.sh layout (line 5); the format may have changed")
    xz = base64.b64decode(line[len(PREFIX):-len(SUFFIX)])
    raw = lzma.decompress(xz)

    src = tarfile.open(fileobj=io.BytesIO(raw))
    out = io.BytesIO()
    with tarfile.open(fileobj=out, mode="w:gz", format=tarfile.USTAR_FORMAT) as dst:
        for m in src.getmembers():
            name = m.name[2:] if m.name.startswith("./") else m.name
            top = name.split("/", 1)[0]
            if a.platform != "all" and top in ("kindlepw2", "kindlehf") and top != a.platform:
                continue
            m.uid = m.gid = 0; m.uname = m.gname = "root"
            dst.addfile(m, src.extractfile(m) if m.isfile() else None)

    os.makedirs(a.outdir, exist_ok=True)
    open(os.path.join(a.outdir, "kmc.tar.gz"), "wb").write(out.getvalue())
    open(os.path.join(a.outdir, "jb_body.sh"), "w").write("\n".join(lines[5:]))
    open(os.path.join(a.outdir, "run.sh"), "w").write(RUNNER)
    print(f"jb.sh {a.version} ok ({digest[:12]}...), payload {len(raw)} B tar -> {len(out.getvalue())} B gzip [{a.platform}]")
    print("bundle written to", a.outdir)

if __name__ == "__main__":
    main()
