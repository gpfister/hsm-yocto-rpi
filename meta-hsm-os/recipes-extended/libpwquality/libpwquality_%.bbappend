FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://pwquality.conf \
    file://common-password \
"

do_install:append() {
    install -d ${D}${sysconfdir}/security
    install -m 0644 ${UNPACKDIR}/pwquality.conf ${D}${sysconfdir}/security/pwquality.conf

    install -d ${D}${sysconfdir}/pam.d
    install -m 0644 ${UNPACKDIR}/common-password ${D}${sysconfdir}/pam.d/common-password
}

FILES:${PN} += " \
    ${sysconfdir}/security/pwquality.conf \
    ${sysconfdir}/pam.d/common-password \
"
