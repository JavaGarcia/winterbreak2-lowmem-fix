# Draft issue for KindleModding/jb.sh

**Title:** Payload extraction fails silently on low-RAM devices (xz -9 needs a 64 MiB malloc in BusyBox unxz)

**Body:**

On a Kindle Paperwhite 2 (kindlepw2, 256 MB RAM, no swap), FW 5.12.2.2, jb.sh v2.2.1 via WinterBreak2,
the payload line

```sh
echo "..." | base64 -d | xz -d | tar xf - -C /tmp/kmc
```

intermittently fails with `xz: corrupted data`. The payload is fine (same md5 after `base64 -d`, decompresses on a PC).
BusyBox 1.28.3's unxz allocates the whole LZMA2 dictionary with `malloc()` (64 MiB for `xz -9`) and reports
`XZ_MEM_ERROR` as "corrupted data". On the device it succeeds when free+buffers+cached ≈ 79 MB and fails at ≈ 63 MB.

Because the result is not checked, jb.sh continues with an empty `/tmp/kmc`, installs nothing (no keys, no
sh_integration, no KPM), and still writes `JAILBROKEN.txt` — which matches WinterBreak#64.

Suggestions:
1. Build the payload with a smaller dictionary, e.g. `xz -9e --lzma2=dict=16MiB`. For v2.2.1 the size is unchanged
   (3.96 MB at 16, 32 and 64 MiB; 6.60 MB at 8 MiB).
2. Check extraction before continuing, e.g. abort with an on-screen message if
   `/tmp/kmc/system_patches/patch_system.sh` is missing.

Full measurements and logs: https://github.com/javagarcia/winterbreak2-lowmem-fix

Separately, on the same device gandalf loses its setuid bit (and the `/var/local/kmc` / `/var/local/mkk` symlinks
disappear) after a reboot; we have a workaround but not the root cause — details in the repo.

---

# Draft comment for KindleModding/WinterBreak#64

I hit exactly this on a PW2 / 5.12.2.2. Root cause of the "JAILBROKEN.txt but nothing works" state: jb.sh's
`xz -9` payload needs a 64 MiB allocation in BusyBox unxz, which fails intermittently on 256 MB devices and is
reported as "corrupted data"; jb.sh doesn't check and continues with an empty /tmp/kmc. That also explains the
Update error 007 (dev key never installed). A second issue (gandalf losing setuid after reboot) breaks scriptlets
again after restart. Write-up, evidence and workaround: https://github.com/javagarcia/winterbreak2-lowmem-fix
