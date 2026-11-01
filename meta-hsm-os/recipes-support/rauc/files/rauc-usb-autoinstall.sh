#!/bin/bash
# ==============================================================================
# rauc-usb-autoinstall.sh - Offline USB RAUC Bundle Ingestion Service
# ==============================================================================
set -euo pipefail

echo "==> Scanning mounted USB media for signed RAUC update bundles..."

shopt -s nullglob
BUNDLES=(/media/usb-*/*.raucb)

if [[ ${#BUNDLES[@]} -eq 0 ]]; then
    echo "No .raucb bundles found on connected USB devices."
    exit 0
fi

for BUNDLE in "${BUNDLES[@]}"; do
    echo "=================================================================="
    echo "Found RAUC Update Bundle: ${BUNDLE}"
    echo "=================================================================="
    echo "Verifying cryptographic signatures and installing to inactive slot..."

    if rauc info "${BUNDLE}"; then
        echo "Bundle verification succeeded. Triggering RAUC install..."
        if rauc install "${BUNDLE}"; then
            echo ""
            echo "******************************************************************"
            echo " SUCCESS: Update installed into inactive partition slot.         "
            echo " Reboot the system to activate the new OS release.               "
            echo "******************************************************************"
            wall "RAUC Update installed successfully from USB drive. Please reboot to activate." || true
        else
            echo "Error: RAUC install failed!" >&2
        fi
    else
        echo "Error: Bundle verification failed! Untrusted or corrupt image." >&2
    fi
done
