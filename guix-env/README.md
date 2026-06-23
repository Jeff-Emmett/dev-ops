# guix-env — portable, content-addressed computing environment

The desktop as **declarative code**. One source of truth (`config.scm` +
`channels.scm`); every portability mode is a *derived artifact*. Carry the repo,
`reconfigure` on the far end → bit-for-bit identical environment. The VM image is
a cache, not the truth.

This is the system-level instance of the content-addressing pattern rspace-online
already runs at the app layer (KOI bundles, JMJMJ morph-paths). See
`jmjmj-channel/` for the bridge. Tracked under **TASK-83**.

## Files

| File | Role |
|------|------|
| `channels.scm` | Pinned package universe (guix + nonguix; add `jmjmj` later) |
| `config.scm` | Desktop OS → bare-metal **or** portable qcow2, same source |
| `home.scm` | User env — portable to **any** distro incl. WSL2 |
| `manifest.scm` | Dev toolchain (`guix shell -m`) |
| `jmjmj-channel/` | Forge pantheon engines as content-addressed packages |
| `examples/guix-pack-rspace.sh` | Reproducible OCI images, no Dockerfile (Netcup) |

## Host roles

| Host | Guix role | Notes |
|------|-----------|-------|
| Local x86 daily driver | **full Guix System** (`config.scm`) | only host with GPU + spare RAM |
| Any machine, on the move | **qcow2** from `config.scm` | `guix system image -t qcow2` |
| Netcup | **package manager only** (foreign install) | `guix pack` + `guix challenge`; NOT a full Guix System — it already runs the Docker stack |
| GX10 | headless build/compute | NVIDIA-on-Guix (GB10) is bleeding-edge — no GPU desktop yet |

## Phased path (low-regret order)

**1 — Guix Home on the current box (today, reversible).**
Works on the existing foreign distro / WSL2. Get the *user* env declarative with
zero commitment.
```sh
# install Guix the package manager first (foreign-distro installer), then:
guix home reconfigure home.scm
```

**2 — Iterate the desktop in a throwaway VM.**
```sh
guix system vm config.scm        # boots in QEMU, shares host store (fast loop)
guix system build config.scm     # validate without applying
```

**3 — Produce the portable artifact / go bare-metal.**
```sh
guix system image -t qcow2 config.scm     # portable VM, run anywhere with KVM
sudo guix system reconfigure config.scm   # bare-metal daily driver
```

**4 — Package the pantheon (the deep integration).**
Start with one engine, prove reproducibility, then grow `jmjmj-forge-toolchain`.
```sh
guix build     -L jmjmj-channel jmjmj-forge-toolchain
guix challenge -L jmjmj-channel jmjmj-forge-toolchain   # tamper-evidence
```

## Pin for reproducibility (do this after the first `guix pull`)

```sh
guix describe -f channels > channels.scm   # stamps exact commit hashes
guix time-machine -C channels.scm -- system reconfigure config.scm
```

## Honest caveats

- **NVIDIA / GX10 GB10** desktop accel on Guix ≈ nonexistent today. Keep GPU
  desktop on local x86; use GX10/Netcup headless.
- **Cross-arch** (x86 ⇄ ARM): don't emulate — cross-build a native aarch64 image
  from the *same* source.
- **Linux-libre default** has no proprietary drivers — `nonguix` (in
  `channels.scm`) provides the mainline kernel + firmware.
- Configs here are **authored, not yet applied** — validate with
  `guix system build config.scm` once Guix is installed.
- Guix store is **input-addressed** by default (hash over recipe+inputs), not
  output-content-addressed; full CA derivations are still experimental. The
  verifiability story (`guix challenge`, generations, `time-machine`) is the real
  superpower, not output-CA.
