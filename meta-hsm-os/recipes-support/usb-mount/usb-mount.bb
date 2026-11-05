SUMMARY = "USB Storage Auto-Mount Handler for hsmutil"
DESCRIPTION = "Udev rules and systemd service to automatically mount USB storage media with write access for user hsmutil."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = " \
    file://99-usb-storage-mount.rules \
    file://usb-mount@.service \
    file://usb-mount.sh \
"

RDEPENDS:${PN} += "bash udev util-linux e2fsprogs dosfstools"

do_install() {
    install -d ${D}${sysconfdir}/udev/rules.d
    install -m 0644 ${UNPACKDIR}/99-usb-storage-mount.rules ${D}${sysconfdir}/udev/rules.d/99-usb-storage-mount.rules

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/usb-mount@.service ${D}${systemd_system_unitdir}/usb-mount@.service

    install -d ${D}/usr/local/bin
    install -m 0755 ${UNPACKDIR}/usb-mount.sh ${D}/usr/local/bin/usb-mount.sh

    install -d ${D}/media
}

FILES:${PN} += " \
    ${sysconfdir}/udev/rules.d/99-usb-storage-mount.rules \
    ${systemd_system_unitdir}/usb-mount@.service \
    /usr/local/bin/usb-mount.sh \
    /media \
"
