SUMMARY = "nRF52840 HSM CLI and Management Tool (gphsm)"
DESCRIPTION = "Cross-platform Go command line utility and TUI dashboard for interacting with nRF52840 HSM dongles."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

HSM_DEV_MODE ??= "0"

SRC_URI = "${@oe.utils.conditional('HSM_DEV_MODE', '1', \
    'file://gphsm-arm64', \
    'git://github.com/gpfister/hsm-cli.git;protocol=https;branch=main file://gphsm-arm64', d)}"

SRCREV = "${@oe.utils.conditional('HSM_DEV_MODE', '1', '', '${AUTOREV}', d)}"

S = "${@oe.utils.conditional('HSM_DEV_MODE', '1', '${UNPACKDIR}', '${WORKDIR}/git', d)}"

INSANE_SKIP:${PN} += "already-stripped ldflags file-rdeps"
INHIBIT_PACKAGE_STRIP = "1"
INHIBIT_PACKAGE_DEBUG_SPLIT = "1"

do_compile() {
    if [ "${HSM_DEV_MODE}" = "0" ] && [ -d "${S}/cmd/gphsm" ] && command -v go >/dev/null 2>&1; then
        cd "${S}"
        CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -ldflags="-s -w" -o "${B}/gphsm" ./cmd/gphsm || true
    fi
}

do_install() {
    install -d ${D}/usr/local/bin
    if [ "${HSM_DEV_MODE}" = "1" ]; then
        install -m 0755 ${UNPACKDIR}/gphsm-arm64 ${D}/usr/local/bin/gphsm
    else
        if [ -f "${B}/gphsm" ]; then
            install -m 0755 ${B}/gphsm ${D}/usr/local/bin/gphsm
        else
            install -m 0755 ${UNPACKDIR}/gphsm-arm64 ${D}/usr/local/bin/gphsm
        fi
    fi
}

FILES:${PN} = "/usr/local/bin/gphsm"
