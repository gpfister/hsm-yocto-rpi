SUMMARY = "nRF52840 HSM Base Embedded Linux Image"
DESCRIPTION = "Air-gapped, read-only console system containing hsmutil and dedicated USB hardware support."
LICENSE = "MIT"

inherit core-image

IMAGE_FEATURES += "read-only-rootfs"

IMAGE_INSTALL:append = " \
    packagegroup-core-boot \
    kernel-modules \
    nrf52840-hsm-kmod \
    nftables \
    nftables-rules \
    hsmutil-user \
    init-wizard \
    hsmutil \
    usb-mount \
    rauc \
    bash \
    kbd \
    tzdata \
    util-linux \
    e2fsprogs \
    dosfstools \
"

# Set hostname to airgap-hsm
hostname:pn-base-files = "airgap-hsm"
