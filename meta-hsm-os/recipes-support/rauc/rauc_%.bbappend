FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://system.conf \
    file://rauc-ca.cert.pem \
    file://rauc-usb-autoinstall.service \
    file://rauc-usb-autoinstall.sh \
"

do_install:append() {
    install -d ${D}${sysconfdir}/rauc
    install -m 0644 ${WORKDIR}/system.conf ${D}${sysconfdir}/rauc/system.conf
    install -m 0644 ${WORKDIR}/rauc-ca.cert.pem ${D}${sysconfdir}/rauc/ca.cert.pem

    install -d ${D}/usr/local/bin
    install -m 0755 ${WORKDIR}/rauc-usb-autoinstall.sh ${D}/usr/local/bin/rauc-usb-autoinstall.sh

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/rauc-usb-autoinstall.service ${D}${systemd_system_unitdir}/rauc-usb-autoinstall.service
}

SYSTEMD_SERVICE:${PN} += "rauc-usb-autoinstall.service"

FILES:${PN} += " \
    ${sysconfdir}/rauc/system.conf \
    ${sysconfdir}/rauc/ca.cert.pem \
    /usr/local/bin/rauc-usb-autoinstall.sh \
    ${systemd_system_unitdir}/rauc-usb-autoinstall.service \
"
