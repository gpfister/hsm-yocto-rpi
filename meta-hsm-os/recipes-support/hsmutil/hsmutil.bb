SUMMARY = "nRF52840 HSM CLI and Management Tool"
DESCRIPTION = "Cross-platform Go command line utility and TUI dashboard for interacting with nRF52840 HSM dongles."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://hsmutil-arm64 \
"

S = "${UNPACKDIR}"

INSANE_SKIP:${PN} += "already-stripped ldflags file-rdeps"
INHIBIT_PACKAGE_STRIP = "1"
INHIBIT_PACKAGE_DEBUG_SPLIT = "1"

do_install() {
    install -d ${D}/usr/local/bin
    install -m 0755 ${UNPACKDIR}/hsmutil-arm64 ${D}/usr/local/bin/hsmutil
}

FILES:${PN} += "/usr/local/bin/hsmutil"
