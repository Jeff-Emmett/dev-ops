#!/usr/bin/env bash
# guix-pack-rspace.sh — the Netcup payoff: reproducible OCI images, no Dockerfile.
#
# `guix pack -f docker` builds a bit-reproducible Docker image from a manifest.
# Same inputs -> same image hash, every time. No `chown -R` layer bloat, no
# base-image drift, no "works on my machine". Load the result with `docker load`.
#
# Run this on a host with Guix installed as a package manager (foreign-distro
# install is fine — Netcup does NOT need to become a full Guix System).
set -euo pipefail

# Example 1: pack the forge toolchain into a Docker image.
#   --root pins a GC root so the build isn't garbage-collected.
guix pack -f docker \
  -L "$(dirname "$0")/../jmjmj-channel" \
  --root=./forge-toolchain.tar.gz \
  jmjmj-forge-toolchain

echo "Load it:   docker load < forge-toolchain.tar.gz"

# Example 2: relocatable tarball (-RR) — runs on any distro, no Guix needed
# on the target. Useful for shipping a tool to a box you don't control.
#
#   guix pack -RR -S /opt/forge/bin=bin jmjmj-forge-toolchain
#
# Verify reproducibility / detect tampering on any engine:
#   guix challenge -L ../jmjmj-channel jmjmj-forge-toolchain
