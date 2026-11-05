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
    volatile-storage \
    systemd-journald-airgap \
    hsmutil-user \
    init-wizard \
    hsmutil \
    usb-mount \
    rauc \
    libubootenv-bin \
    bash \
    kbd \
    tzdata \
    util-linux \
    e2fsprogs \
    dosfstools \
    libpwquality \
"

# Set hostname to airgap-hsm
hostname:pn-base-files = "airgap-hsm"

# Produce uncompressed .img artifact by renaming the generated .wic output
IMAGE_TYPEDEP:img = "wic"
IMAGE_CMD:img () {
    mv "${IMGDEPLOYDIR}/${IMAGE_NAME}.wic" "${IMGDEPLOYDIR}/${IMAGE_NAME}.img"
    rm -f "${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.wic"
}
