SUMMARY = "Systemd and Kernel Console Quiet Configuration"
DESCRIPTION = "Deploys systemd and sysctl drop-in configs to eliminate watchdog and kernel chatter on tty1."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://10-clean-console.conf \
    file://20-quiet-console.conf \
"

S = "${UNPACKDIR}"

do_install() {
    install -d ${D}${sysconfdir}/systemd/system.conf.d
    install -m 0644 ${UNPACKDIR}/10-clean-console.conf ${D}${sysconfdir}/systemd/system.conf.d/10-clean-console.conf

    install -d ${D}${sysconfdir}/sysctl.d
    install -m 0644 ${UNPACKDIR}/20-quiet-console.conf ${D}${sysconfdir}/sysctl.d/20-quiet-console.conf
}

FILES:${PN} += " \
    ${sysconfdir}/systemd/system.conf.d/10-clean-console.conf \
    ${sysconfdir}/sysctl.d/20-quiet-console.conf \
"
