SUMMARY = "RAM-Only Volatile Overlays and Ephemeral Storage"
DESCRIPTION = "Provides early boot tmpfs and overlayfs mounts for /media, /home/hsmutil, and /etc on read-only rootfs."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = " \
    file://hsm-volatile-storage.service \
    file://hsm-setup-volatile.sh \
"

RDEPENDS:${PN} += "bash"

SYSTEMD_SERVICE:${PN} = "hsm-volatile-storage.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    install -d ${D}/usr/local/bin
    install -m 0755 ${UNPACKDIR}/hsm-setup-volatile.sh ${D}/usr/local/bin/hsm-setup-volatile.sh

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/hsm-volatile-storage.service ${D}${systemd_system_unitdir}/hsm-volatile-storage.service
}

FILES:${PN} += " \
    /usr/local/bin/hsm-setup-volatile.sh \
    ${systemd_system_unitdir}/hsm-volatile-storage.service \
"
