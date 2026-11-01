#!/bin/bash
# ==============================================================================
# hsm-setup-volatile.sh - RAM-Only Volatile Overlays and Tmpfs
# ==============================================================================
set -eu

# 1. Mount RAM tmpfs on /media for USB automount points
mkdir -p /media
if ! mountpoint -q /media; then
    mount -t tmpfs -o mode=0755,nodev,nosuid tmpfs /media
fi

# 2. Setup tmpfs overlay for /etc to allow volatile runtime state (shadow updates)
mkdir -p /run/overlay/etc-upper /run/overlay/etc-work
if ! mountpoint -q /etc; then
    mount -t overlay overlay -o lowerdir=/etc,upperdir=/run/overlay/etc-upper,workdir=/run/overlay/etc-work /etc
fi

# 3. Setup volatile writable home for operator hsmutil
mkdir -p /home/hsmutil
if ! mountpoint -q /home/hsmutil; then
    mount -t tmpfs -o mode=0750,uid=1000,gid=100 tmpfs /home/hsmutil
    if [ -d /etc/skel ]; then
        cp -rT /etc/skel /home/hsmutil 2>/dev/null || true
    fi
    chown -R 1000:100 /home/hsmutil
fi
