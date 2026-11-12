#!/bin/bash
# ==============================================================================
# hsm-setup-volatile.sh - RAM-Only Volatile Overlays, Tmpfs, and Auth Persistence
# ==============================================================================
set -eu

# 1. Mount RAM tmpfs on /media for USB automount points
mkdir -p /media
if ! mountpoint -q /media; then
    mount -t tmpfs -o mode=0755,nodev,nosuid tmpfs /media
fi

# 2. Ensure /data is mounted
mkdir -p /data
if ! mountpoint -q /data; then
    mount LABEL=data /data 2>/dev/null || true
fi

# 3. Setup tmpfs overlay for /etc to allow volatile runtime state
mkdir -p /run/overlay/etc-upper /run/overlay/etc-work
if ! mountpoint -q /etc; then
    mount -t overlay overlay -o lowerdir=/etc,upperdir=/run/overlay/etc-upper,workdir=/run/overlay/etc-work /etc
fi

# 4. Targeted Auth Seeding & Restoration (/data/etc <-> /etc)
if mountpoint -q /data; then
    mkdir -p /data/etc
    chmod 0700 /data/etc
    chown root:root /data/etc

    AUTH_FILES=("shadow" "passwd" "group" "gshadow")

    if [ ! -s /data/etc/shadow ]; then
        # First-boot seeding: copy template files from rootfs into /data/etc
        for file in "${AUTH_FILES[@]}"; do
            if [ -f "/etc/${file}" ] && [ -s "/etc/${file}" ]; then
                cp -p "/etc/${file}" "/data/etc/${file}"
                if [ "${file}" = "shadow" ] || [ "${file}" = "gshadow" ]; then
                    chmod 0400 "/data/etc/${file}" 2>/dev/null || true
                    chown root:shadow "/data/etc/${file}" 2>/dev/null || chown root:root "/data/etc/${file}"
                else
                    chmod 0644 "/data/etc/${file}"
                    chown root:root "/data/etc/${file}"
                fi
            fi
        done
        sync
    else
        # Subsequent boots: validate integrity and restore into active /etc overlay
        if [ -s /data/etc/passwd ] && [ -s /data/etc/group ]; then
            for file in "${AUTH_FILES[@]}"; do
                if [ -f "/data/etc/${file}" ] && [ -s "/data/etc/${file}" ]; then
                    cp -p "/data/etc/${file}" "/etc/${file}"
                    if [ "${file}" = "shadow" ] || [ "${file}" = "gshadow" ]; then
                        chmod 0400 "/etc/${file}" 2>/dev/null || true
                        chown root:shadow "/etc/${file}" 2>/dev/null || chown root:root "/etc/${file}"
                    else
                        chmod 0644 "/etc/${file}"
                        chown root:root "/etc/${file}"
                    fi
                fi
            done
        else
            echo "==> [WARN] Corrupted auth database detected in /data/etc; falling back to rootfs template" >&2
        fi
    fi
fi

# 5. Setup home for operator hsmutil (preserve if /home is mounted from LABEL=homefs)
mkdir -p /home/hsmutil
if mountpoint -q /home; then
    chown -R 1000:100 /home/hsmutil
elif ! mountpoint -q /home/hsmutil; then
    mount -t tmpfs -o mode=0750,uid=1000,gid=100 tmpfs /home/hsmutil
    if [ -d /etc/skel ]; then
        cp -rT /etc/skel /home/hsmutil 2>/dev/null || true
    fi
    chown -R 1000:100 /home/hsmutil
fi
