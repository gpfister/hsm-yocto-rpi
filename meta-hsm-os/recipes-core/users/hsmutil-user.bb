SUMMARY = "Dedicated hsmutil User Account Setup"
DESCRIPTION = "Creates standard unprivileged user hsmutil with access to tty, dialout, and storage."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit useradd

USERADD_PACKAGES = "${PN}"
GROUPADD_PARAM:${PN} = "-r storage"
# Initial password set to 'password' (SHA-512 crypt hash)
USERADD_PARAM:${PN} = "-m -d /home/hsmutil -s /bin/bash -g users -G dialout,tty,storage -p '\$6\$saltsalt\$qFmFH.bQmmtXzyBY0s9v7Oicd2z4XSIecDzlB5KiA2/jctKu9YterLp8wwnSq.qc.eoxqOmSuNp2xS0ktL3nh/' hsmutil"

HSM_DEV_MODE ??= "0"

do_install() {
    install -d ${D}/home/hsmutil
    chown -R 1000:100 ${D}/home/hsmutil
}

pkg_postinst:${PN}() {
    if [ -n "$D" ]; then
        if [ -f "$D/etc/shadow" ]; then
            sed -i 's/^\(hsmutil:[^:]*:[^:]*:[^:]*:\)[^:]*\(.*\)/\190\2/' "$D/etc/shadow"
        fi
    fi
}

FILES:${PN} = "/home/hsmutil"
PREPROCESS_MAN_PAGES = ""
