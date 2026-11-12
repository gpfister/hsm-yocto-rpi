#!/bin/bash
# ==============================================================================
# hsm-sync-auth.sh - Atomic Synchronization of Auth Databases to /data/etc
# ==============================================================================
set -eu

TARGET_DIR="/data/etc"

# 1. Verify /data is mounted and writable
if ! mountpoint -q /data; then
    exit 0
fi

mkdir -p "${TARGET_DIR}"
chmod 0700 "${TARGET_DIR}"
chown root:root "${TARGET_DIR}"

PID=$$
AUTH_FILES=("shadow" "passwd" "group" "gshadow")

for file in "${AUTH_FILES[@]}"; do
    src="/etc/${file}"
    dst="${TARGET_DIR}/${file}"
    tmp="${TARGET_DIR}/.${file}.tmp.${PID}"
    bak="${TARGET_DIR}/${file}.bak"

    if [ -f "${src}" ] && [ -s "${src}" ]; then
        # Copy to temp file
        cp -p "${src}" "${tmp}"

        # Set strict permissions
        if [ "${file}" = "shadow" ] || [ "${file}" = "gshadow" ]; then
            chmod 0400 "${tmp}"
            chown root:shadow "${tmp}" 2>/dev/null || chown root:root "${tmp}"
        else
            chmod 0644 "${tmp}"
            chown root:root "${tmp}"
        fi

        # Rotate backup if target exists
        if [ -f "${dst}" ]; then
            cp -p "${dst}" "${bak}" 2>/dev/null || true
        fi

        # Atomic rename
        mv -f "${tmp}" "${dst}"
    fi
done

# Flush dirty filesystem buffers to MMC storage
sync
