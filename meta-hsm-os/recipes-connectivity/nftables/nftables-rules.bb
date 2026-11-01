SUMMARY = "Strict Total-Drop Air-Gap nftables Configuration"
DESCRIPTION = "Enforces zero ingress, egress, or forwarding packet policy on all network interfaces."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = " \
    file://nftables.conf \
    file://nftables-load.service \
"

RDEPENDS:${PN} += "nftables"

SYSTEMD_SERVICE:${PN} = "nftables-load.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    install -d ${D}${sysconfdir}
    install -m 0600 ${WORKDIR}/nftables.conf ${D}${sysconfdir}/nftables.conf

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/nftables-load.service ${D}${systemd_system_unitdir}/nftables-load.service
}

FILES:${PN} += " \
    ${sysconfdir}/nftables.conf \
    ${systemd_system_unitdir}/nftables-load.service \
"
