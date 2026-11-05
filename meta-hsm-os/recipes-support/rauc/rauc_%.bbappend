FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://rauc-usb-autoinstall.service \
    file://rauc-usb-autoinstall.sh \
"

RDEPENDS:${PN} += "bash"

do_install:append() {
    install -d ${D}/usr/local/bin
    install -m 0755 ${UNPACKDIR}/rauc-usb-autoinstall.sh ${D}/usr/local/bin/rauc-usb-autoinstall.sh

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/rauc-usb-autoinstall.service ${D}${systemd_system_unitdir}/rauc-usb-autoinstall.service
}

SYSTEMD_SERVICE:${PN} += "rauc-usb-autoinstall.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

FILES:${PN} += " \
    /usr/local/bin/rauc-usb-autoinstall.sh \
    ${systemd_system_unitdir}/rauc-usb-autoinstall.service \
"
