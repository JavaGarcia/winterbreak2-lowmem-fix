# winterbreak2-lowmem-fix

**Why WinterBreak2 / jb.sh "succeeds" but leaves a half-jailbroken Kindle on low-RAM devices — root cause, evidence and a working fix.**

Tested on a **Kindle Paperwhite 2 (2013, 6th gen, `kindlepw2`/armel, 256 MB RAM), firmware 5.12.2.2**, jailbroken with **WinterBreak2 → jb.sh v2.2.1**.
It is very likely the same problem reported in [KindleModding/WinterBreak#64](https://github.com/KindleModding/WinterBreak/issues/64) (closed without a confirmed fix).

> This is **not** a new jailbreak. All the hard work (the exploit, jb.sh, KMC, sh_integration, KPM) belongs to
> Scam.Net, Penguins184, Hackerdude and the KindleModding team. This repo only documents two failures we hit on
> old hardware and how we worked around them.

---

## Symptoms

After running WinterBreak2 you get `documents/JAILBROKEN.txt` ("You are jailbroken! (jb.sh v2.2.1)") and the Kindle restarts, but:

- `.sh` scriptlets (e.g. KUAL from PEKI) do not appear in the library, or open with **"Application Error / the selected application could not start"**;
- `;kpm`, `;log mrpi` do nothing;
- installing `Update_hotfix_universal.bin` via *Update your Kindle* fails with **Update error 007** (signature rejected — the developer key was never installed);
- `/mnt/us/libkh/bin/` is empty.

Two independent problems produce this. Fixing only the first one gets you a working jailbreak **until the next reboot**.

---

## Problem 1 — jb.sh payload extraction fails silently (memory)

### What jb.sh does

Line 5 of the monolithic `jb.sh` unpacks its payload (KMC: gandalf, sh_integration, KPM, keys…):

```sh
echo "<5.2 MB of base64>" | base64 -d | xz -d | tar xf - -C /tmp/kmc
```

The payload is compressed with `xz -9`, i.e. a **64 MiB LZMA2 dictionary**
(block header filter properties byte `0x1c` → 2^26 bytes).

### Why it fails

BusyBox's `unxz` (v1.28.3 on FW 5.12.2.2) uses xz-embedded in `XZ_DYNALLOC` mode and allocates the whole dictionary with a plain `malloc()`
(`archival/libarchive/unxz/xz_config.h`: `#define vmalloc(size) malloc(size)`; `xz_dec_lzma2.c` returns `XZ_MEM_ERROR` when it fails).
`decompress_unxz.c` then reports **every** non-OK result — including out-of-memory — as:

```
xz: corrupted data
```

The PW2 has 256 MB of RAM and **no swap**. Whether a 64 MiB allocation succeeds depends on how much memory is free *plus reclaimable* at that instant.
jb.sh does not check the result of the pipeline, so it carries on with an empty `/tmp/kmc`, "installs" nothing, and still writes `JAILBROKEN.txt`.

### Evidence (measured on the device, see [`evidence/`](evidence/))

Same file, same device, different moments:

| Test | Dictionary | free + buffers + cached (KB) | Result |
|---|---|---|---|
| `xz -dc kmc9.tar.xz` (run 1) | 64 MiB | 9 760 + 15 112 + 53 996 = **78 868** | ✅ exit 0 |
| `xz -dc kmc9.tar.xz` (run 3) | 64 MiB | 26 740 + 4 888 + 31 232 = **62 860** | ❌ `corrupted data` |
| original line 5 of jb.sh | 64 MiB | — | ❌ `corrupted data`, `tar: short read` |
| `cat kmc6.tar.xz \| xz -d` | 8 MiB | 22 628 + 6 408 + 34 184 | ✅ md5 matches |
| `echo "$P" \| base64 -d \| md5sum` | — | — | ✅ md5 matches (the 5 MB `echo` and BusyBox `base64` are fine) |

64 MiB = 65 536 KB: the allocation succeeds above that line and fails below it. This is consistent with the kernel's
default heuristic overcommit. We did **not** read `/proc/sys/vm/overcommit_memory`, so that part is inference.
Pipe vs. file makes no difference (`evidence/04_*`): we first thought it did, but that was the memory state changing between runs.

### Fix

Use a smaller dictionary. Compression ratio is identical down to 16 MiB for this payload:

| LZMA2 dictionary | payload size |
|---|---|
| 64 MiB (`xz -9`, current) | 3.96 MB |
| 32 MiB | 3.96 MB |
| **16 MiB** | **3.96 MB** |
| 8 MiB (`xz -6`) | 6.60 MB |

(16 MiB is enough because the payload is a 24 MB tar whose `kindlepw2` and `kindlehf` halves are near-duplicates ~12 MB apart.)

Upstream suggestion: build with `xz -9e --lzma2=dict=16MiB` **and** abort if extraction is incomplete — see [`upstream/`](upstream/).

**Workaround today:** [`tools/repack_jbsh.py`](tools/repack_jbsh.py) downloads the official jb.sh, verifies its SHA-256,
re-packs the payload as gzip (only your platform), and produces a bundle that runs the *unmodified* rest of jb.sh
and refuses to continue if extraction is incomplete.

```bash
python3 tools/repack_jbsh.py --platform kindlepw2 out/
# copy out/ to the Kindle as /mnt/us/jb_lowmem/, then run as root:
sh /mnt/us/jb_lowmem/run.sh      # log: /mnt/us/jb_lowmem.log
```

---

## Problem 2 — gandalf loses setuid after reboot (FW 5.12.2.2)

With the payload installed, scriptlets worked — until the next reboot. After every reboot we found:

- jb.sh's **symlinks** `/var/local/kmc/{bin,lib}` and `/var/local/mkk/{gandalf,su}` **gone**;
- after replacing them with hard links, the links survived, but **gandalf had lost its setuid bit** and its group changed `root` → `javauser`
  (`-rwsr-sr-x root root` → `-rwxrwxr-x root javauser`). `su` then fails with `must be suid to work properly`;
- the launcher logs `appmgr_proc:execve_fail ... errno=2` (missing symlink) or the app times out → *Application Error*.

**Root cause: unknown.** It is not in jb.sh (`patch_system.sh`, `kmc_system_patcher`), nor in
`/etc/upstart/filesystems_var_local.conf`, `shutdown_special` or `/usr/bin/dmcc.sh` (checked). Help welcome.

### Workaround

[`device/kd_watch.sh`](device/kd_watch.sh) + [`device/kd_watch.conf`](device/kd_watch.conf): an upstart job (`start on framework_ready`)
that runs from `/var/local` (so it does not depend on `/mnt/us`), recreates the links as **hard links**, restores
`root:root` + `6755` on gandalf, and keeps checking (every 10 s for 15 min, then every 5 min). Install with
[`device/install_watch.sh`](device/install_watch.sh) as root. On our device KUAL opened ~1 min after boot and kept working.

Things that did **not** work reliably:

- `/mnt/us/emergency.sh` (run by jb.sh's `kmc.conf` at `framework_ready`): only runs when `/mnt/us` happens to be mounted in time — some boots yes, some no.
- `/var/local/system/fixup` (a firmware hook in `filesystems_var_local.conf`): never observed running.

---

## Pitfalls we hit (useful for anyone debugging a Kindle)

- **A process with an open file on `/mnt/us` blocks USB mass-storage mode.** The screen flickers between the home screen and "USB drive mode" and the computer keeps losing the volume. Run long-lived things from `/var/local`.
- **WinterBreak2's root command is a local file.** The exploit opens `/mnt/us/winterbreak2/dialoger.html` as a pillow dialog, whose `source_command` runs as root. We temporarily pointed it at our own scripts to run diagnostics before scriptlets worked. Notes:
  - the dialog is cached until reboot (edits are ignored until then);
  - `com.lab126.transfer` **retries** the request by itself every few minutes, and ignores a new one with the same `unique_id` until reboot.
- BusyBox 1.28 `timeout` uses the old syntax: `timeout -t SECONDS cmd`.
- `JAILBROKEN.txt` only means jb.sh reached its last step, not that anything was installed.

---

## Repo layout

```
tools/repack_jbsh.py      download + verify + repack jb.sh with a gzip payload
tools/xz_memtest.sh       on-device reproducer for Problem 1
device/kd_watch.sh        gandalf setuid/links watcher (Problem 2)
device/kd_watch.conf      upstart job for the watcher
device/install_watch.sh   installs the two files above (root)
device/emergency.sh       optional fallback for jb.sh's kmc.conf hook
device/diag.sh            read-only diagnostics
evidence/                 raw logs from the device (sanitized)
upstream/                 draft issue text for jb.sh / WinterBreak#64
```

## Disclaimer

Jailbreaking can brick your device. Everything here was tested on **one** PW2 on FW 5.12.2.2. Read the scripts before running them.

## Credits

- WinterBreak2: Scam.Net (discovery), Penguins184 (server) — https://github.com/KindleModding/Winterbreak2
- jb.sh / KMC / sh_integration: Hackerdude — https://github.com/KindleModding/jb.sh (MIT)
- KindleModding community — https://kindlemodding.org
- Investigation and write-up: **JavierG**, with help from Claude (Anthropic).

## License

MIT — see [LICENSE](LICENSE).
