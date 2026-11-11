FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append:rpi = " \
    file://squashfs.cfg \
    file://no-net.cfg \
    ${@oe.utils.conditional('HSM_DEV_MODE', '1', '', 'file://silent-boot.cfg', d)} \
"
