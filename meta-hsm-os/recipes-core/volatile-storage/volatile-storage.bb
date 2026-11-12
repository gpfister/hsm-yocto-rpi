SUMMARY = "RAM-Only Volatile Overlays, Ephemeral Storage, and Auth Persistence"
DESCRIPTION = "Provides early boot tmpfs and overlayfs mounts for /media, /home/hsmutil, and /etc on read-only rootfs with persistent authentication syncing."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = " \
    file://hsm-volatile-storage.service \
    file://hsm-setup-volatile.sh \
    file://hsm-sync-auth.sh \
    file://hsm-persist-auth.service \
    file://hsm-persist-auth.path \
"

RDEPENDS:${PN} += "bash"

SYSTEMD_SERVICE:${PN} = " \
    hsm-volatile-storage.service \
    hsm-persist-auth.path \
    hsm-persist-auth.service \
"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    install -d ${D}/usr/local/bin
    install -m 0755 ${UNPACKDIR}/hsm-setup-volatile.sh ${D}/usr/local/bin/hsm-setup-volatile.sh
    install -m 0755 ${UNPACKDIR}/hsm-sync-auth.sh ${D}/usr/local/bin/hsm-sync-auth.sh

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/hsm-volatile-storage.service ${D}${systemd_system_unitdir}/hsm-volatile-storage.service
    install -m 0644 ${UNPACKDIR}/hsm-persist-auth.service ${D}${systemd_system_unitdir}/hsm-persist-auth.service
    install -m 0644 ${UNPACKDIR}/hsm-persist-auth.path ${D}${systemd_system_unitdir}/hsm-persist-auth.path
}

FILES:${PN} += " \
    /usr/local/bin/hsm-setup-volatile.sh \
    /usr/local/bin/hsm-sync-auth.sh \
    ${systemd_system_unitdir}/hsm-volatile-storage.service \
    ${systemd_system_unitdir}/hsm-persist-auth.service \
    ${systemd_system_unitdir}/hsm-persist-auth.path \
"
