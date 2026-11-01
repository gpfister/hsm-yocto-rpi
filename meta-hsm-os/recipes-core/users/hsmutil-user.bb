SUMMARY = "Dedicated hsmutil User Account Setup"
DESCRIPTION = "Creates standard unprivileged user hsmutil with access to tty, dialout, and storage."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit useradd

USERADD_PACKAGES = "${PN}"
# Default initial password set to 'hsmutil' (encrypted sha512: $6$salty$gZ/0v4W44oA3G...) or plain via usermod
USERADD_PARAM:${PN} = "-m -d /home/hsmutil -s /bin/bash -g users -G dialout,tty,storage -p '\$6\$saltsalt\$G94p8Y1FzW2mN9bM9H1sT.j6d7e0f8r9s0t1u2v3w4x5y6z7a8b9c0d1e2f3g4h5i6j7k8l9m0n1o2p3q4r5' hsmutil"

HSM_DEV_MODE ??= "0"

do_install() {
    install -d ${D}/home/hsmutil
    chown -R 1000:100 ${D}/home/hsmutil

    if [ "${HSM_DEV_MODE}" = "1" ]; then
        install -d ${D}${sysconfdir}/sudoers.d
        echo "hsmutil ALL=(ALL) NOPASSWD: ALL" > ${D}${sysconfdir}/sudoers.d/hsmutil
        chmod 0440 ${D}${sysconfdir}/sudoers.d/hsmutil
    fi
}

FILES:${PN} += "/home/hsmutil ${sysconfdir}/sudoers.d/hsmutil"
PREPROCESS_MAN_PAGES = ""
