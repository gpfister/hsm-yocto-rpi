#!/usr/bin/env bash
# ==============================================================================
# flash-sd.sh: Flash generated WIC image to an SD card block device
# ==============================================================================
set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <image.wic | image.wic.bz2> <target_block_device>"
    echo "Example (raw .wic):       $0 build/deploy/images/raspberrypi0-2w-64/hsm-image-prod-raspberrypi0-2w-64.rootfs.wic /dev/rdisk4"
    echo "Example (compressed):     $0 build/deploy/images/raspberrypi0-2w-64/hsm-image-prod-raspberrypi0-2w-64.rootfs.wic.bz2 /dev/rdisk4"
    exit 1
fi

IMAGE_PATH="$1"
TARGET_DEV="$2"

if [[ ! -f "${IMAGE_PATH}" ]]; then
    echo "Error: Image file '${IMAGE_PATH}' not found." >&2
    exit 1
fi

if [[ ! -b "${TARGET_DEV}" && ! -c "${TARGET_DEV}" ]]; then
    echo "Warning: '${TARGET_DEV}' is not a standard block or raw character device." >&2
fi

echo "=================================================================="
echo "                   CAUTION: DESTRUCTIVE FLASH OPERATION           "
echo "=================================================================="
echo "  Source Image:  ${IMAGE_PATH}"
echo "  Target Device: ${TARGET_DEV}"
echo "=================================================================="
read -r -p "Are you sure you want to completely OVERWRITE ${TARGET_DEV}? (yes/NO): " CONFIRM
if [[ "${CONFIRM}" != "yes" ]]; then
    echo "Aborted by operator."
    exit 0
fi

# Configure platform-specific dd flags (macOS BSD dd vs Linux GNU dd)
HOST_OS="$(uname -s)"
if [[ "${HOST_OS}" == "Darwin" ]]; then
    DD_FLAGS=(bs=4m status=progress)
else
    DD_FLAGS=(bs=4M status=progress conv=fsync)
fi

# Detect bzip2 compressed WIC
if [[ "${IMAGE_PATH}" == *.bz2 ]]; then
    echo "==> Decompressing and streaming to ${TARGET_DEV}..."
    if command -v bzip2 >/dev/null 2>&1; then
        bzip2 -dc "${IMAGE_PATH}" | sudo dd of="${TARGET_DEV}" "${DD_FLAGS[@]}"
    elif command -v pbzip2 >/dev/null 2>&1; then
        pbzip2 -dc "${IMAGE_PATH}" | sudo dd of="${TARGET_DEV}" "${DD_FLAGS[@]}"
    else
        echo "Error: bzip2 or pbzip2 required." >&2
        exit 1
    fi
else
    echo "==> Writing raw image to ${TARGET_DEV}..."
    sudo dd if="${IMAGE_PATH}" of="${TARGET_DEV}" "${DD_FLAGS[@]}"
fi

echo "==> Flashing complete. Syncing disks..."
sync
echo "==> SD card is ready for air-gapped boot."
