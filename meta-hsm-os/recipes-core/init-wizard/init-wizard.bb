SUMMARY = "Operator First-Login Setup Wizard and Clock Calibration"
DESCRIPTION = "Enforces initial operator password change, keyboard selection, and clock synchronization on air-gapped systems."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://first-login-wizard.sh \
    file://clock-setup.sh \
    file://hsm-profile.sh \
"

RDEPENDS:${PN} += "bash kbd util-linux tzdata"

do_install() {
    install -d ${D}/usr/local/bin
    install -m 0755 ${WORKDIR}/first-login-wizard.sh ${D}/usr/local/bin/first-login-wizard.sh
    install -m 0755 ${WORKDIR}/clock-setup.sh ${D}/usr/local/bin/clock-setup.sh

    install -d ${D}${sysconfdir}/profile.d
    install -m 0644 ${WORKDIR}/hsm-profile.sh ${D}${sysconfdir}/profile.d/hsm-login.sh
}

FILES:${PN} += " \
    /usr/local/bin/first-login-wizard.sh \
    /usr/local/bin/clock-setup.sh \
    ${sysconfdir}/profile.d/hsm-login.sh \
"
