#!/bin/bash
# ==============================================================================
# usb-mount.sh - USB Mass Storage Partition Auto-Mount Manager
# ==============================================================================
set -euo pipefail

ACTION="${1:-add}"
DEVBASE="${2:-}"

if [[ -z "${DEVBASE}" ]]; then
    exit 1
fi

DEVICE="/dev/${DEVBASE}"
MOUNT_POINT="/media/usb-${DEVBASE}"

case "${ACTION}" in
    add)
        mkdir -p "${MOUNT_POINT}"
        # Determine filesystem type
        FSTYPE=$(blkid -o value -s TYPE "${DEVICE}" 2>/dev/null || echo "")

        case "${FSTYPE}" in
            vfat|fat|msdos)
                mount -t "${FSTYPE}" -o uid=1000,gid=100,umask=0007 "${DEVICE}" "${MOUNT_POINT}"
                ;;
            ext2|ext3|ext4)
                mount -t "${FSTYPE}" -o rw "${DEVICE}" "${MOUNT_POINT}"
                chown -R 1000:100 "${MOUNT_POINT}" || true
                chmod -R 0770 "${MOUNT_POINT}" || true
                ;;
            *)
                mount -o rw "${DEVICE}" "${MOUNT_POINT}" || true
                chown -R 1000:100 "${MOUNT_POINT}" || true
                ;;
        esac
        echo "Mounted ${DEVICE} at ${MOUNT_POINT} (user hsmutil rw)"

        # Check for RAUC update bundle on newly mounted device
        shopt -s nullglob
        BUNDLES=("${MOUNT_POINT}"/*.raucb)
        if [[ ${#BUNDLES[@]} -gt 0 ]]; then
            echo "RAUC update bundle detected on ${MOUNT_POINT}, triggering auto-install service..."
            systemctl start rauc-usb-autoinstall.service || true
        fi
        ;;

    remove)
        if mountpoint -q "${MOUNT_POINT}"; then
            umount -l "${MOUNT_POINT}" || true
        fi
        rm -rf "${MOUNT_POINT}"
        echo "Unmounted ${MOUNT_POINT}"
        ;;
esac
