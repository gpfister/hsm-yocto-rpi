SUMMARY = "nRF52840 HSM Base Embedded Linux Image"
DESCRIPTION = "Air-gapped, read-only console system containing gphsm and dedicated USB hardware support."
LICENSE = "MIT"

inherit core-image

IMAGE_FEATURES += "read-only-rootfs"

IMAGE_INSTALL:append = " \
    packagegroup-core-boot \
    kernel-modules \
    nrf52840-hsm-kmod \
    volatile-storage \
    systemd-journald-airgap \
    hsmutil-user \
    init-wizard \
    gphsm \
    clean-console \
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
    i2c-tools \
"

# Set hostname to piKMS
hostname:pn-base-files = "piKMS"

# Produce uncompressed .img artifact by hardlinking the generated .wic output
IMAGE_TYPEDEP:img = "wic"
IMAGE_CMD:img () {
    ln -f "${IMGDEPLOYDIR}/${IMAGE_NAME}.wic" "${IMGDEPLOYDIR}/${IMAGE_NAME}.img"
}
