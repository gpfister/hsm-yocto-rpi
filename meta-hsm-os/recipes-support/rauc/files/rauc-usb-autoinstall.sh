#!/bin/sh
# ==============================================================================
# rauc-usb-autoinstall.sh - Offline USB RAUC Bundle Ingestion Service
# ==============================================================================
set -eu

echo "==> Scanning mounted USB media for signed RAUC update bundles..."

found=0
for BUNDLE in /media/usb-*/*.raucb; do
    [ -f "${BUNDLE}" ] || continue
    found=1
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

if [ "${found}" -eq 0 ]; then
    echo "No .raucb bundles found on connected USB devices."
fi
exit 0
