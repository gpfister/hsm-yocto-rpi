SUMMARY = "Air-gap journald logging configuration"
DESCRIPTION = "Enforces silent operation (Storage=none) in production and RAM logging (Storage=volatile) in development."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

HSM_DEV_MODE ??= "0"

SRC_URI = " \
    file://journald-prod.conf \
    file://journald-dev.conf \
"

do_install() {
    install -d ${D}${sysconfdir}/systemd/journald.conf.d
    if [ "${HSM_DEV_MODE}" = "1" ]; then
        install -m 0644 ${UNPACKDIR}/journald-dev.conf ${D}${sysconfdir}/systemd/journald.conf.d/airgap-logging.conf
    else
        install -m 0644 ${UNPACKDIR}/journald-prod.conf ${D}${sysconfdir}/systemd/journald.conf.d/airgap-logging.conf
    fi
}

FILES:${PN} += "${sysconfdir}/systemd/journald.conf.d/airgap-logging.conf"
