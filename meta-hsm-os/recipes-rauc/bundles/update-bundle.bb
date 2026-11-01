SUMMARY = "Air-Gapped Signed RAUC A/B Firmware Update Bundle"
DESCRIPTION = "Packages production rootfs image into an x509-signed RAUC update bundle (.raucb)."
LICENSE = "MIT"

inherit bundle

RAUC_BUNDLE_COMPATIBLE = "nrf52840-hsm-os"
RAUC_BUNDLE_VERSION = "1.0.0"
RAUC_BUNDLE_DESCRIPTION = "nRF52840 HSM OS A/B Release Bundle"

RAUC_BUNDLE_SLOTS = "rootfs"
RAUC_SLOT_rootfs = "hsm-image-prod"
RAUC_SLOT_rootfs[type] = "image"

RAUC_KEY_FILE ?= "${TOPDIR}/../keys/development-signing.key.pem"
RAUC_CERT_FILE ?= "${TOPDIR}/../keys/development-signing.cert.pem"
RAUC_KEYRING_FILE ?= "${TOPDIR}/../keys/rauc-ca.cert.pem"
