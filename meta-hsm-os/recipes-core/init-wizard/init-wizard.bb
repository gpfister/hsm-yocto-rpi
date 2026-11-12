SUMMARY = "Operator First-Login Setup Wizard and Clock Calibration"
DESCRIPTION = "Enforces initial operator password change, keyboard selection, and clock synchronization on air-gapped systems."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://first-login-wizard.sh \
    file://clock-setup.sh \
    file://hsm-profile.sh \
    file://hsm-set-date.c \
"

RDEPENDS:${PN} += "bash kbd util-linux tzdata"

HSM_DEV_MODE ??= "0"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} ${UNPACKDIR}/hsm-set-date.c -o ${B}/hsm-set-date
}

do_install() {
    install -d ${D}/usr/local/bin
    install -m 0755 ${UNPACKDIR}/first-login-wizard.sh ${D}/usr/local/bin/first-login-wizard.sh
    install -m 0755 ${UNPACKDIR}/clock-setup.sh ${D}/usr/local/bin/clock-setup.sh
    install -m 4755 ${B}/hsm-set-date ${D}/usr/local/bin/hsm-set-date

    install -d ${D}${sysconfdir}/profile.d
    install -m 0644 ${UNPACKDIR}/hsm-profile.sh ${D}${sysconfdir}/profile.d/hsm-login.sh

    if [ "${HSM_DEV_MODE}" = "0" ]; then
        cat << 'EOF' > ${D}${sysconfdir}/profile.d/99-hsm-history.sh
# Production mode: Disable bash history retention
export HISTFILE=/dev/null
export HISTSIZE=0
export HISTFILESIZE=0
set +o history 2>/dev/null || true
EOF
        chmod 0644 ${D}${sysconfdir}/profile.d/99-hsm-history.sh
    fi
}

INSANE_SKIP:${PN}-dbg += "buildpaths"
INSANE_SKIP:${PN} += "buildpaths"

FILES:${PN} += " \
    /usr/local/bin/first-login-wizard.sh \
    /usr/local/bin/clock-setup.sh \
    /usr/local/bin/hsm-set-date \
    ${sysconfdir}/profile.d/*.sh \
"
