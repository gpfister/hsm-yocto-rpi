SUMMARY = "Dedicated hsmutil User Account Setup"
DESCRIPTION = "Creates standard unprivileged user hsmutil with access to tty, dialout, and storage."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit useradd

USERADD_PACKAGES = "${PN}"
GROUPADD_PARAM:${PN} = "-r storage"
# Initial password set to 'hsmutil' (SHA-512 crypt hash)
USERADD_PARAM:${PN} = "-m -d /home/hsmutil -s /bin/bash -g users -G dialout,tty,storage -p '\$6\$saltsalt\$4UgRT1VXQO8UhAjnMHotD/rZziVqEb9P2Sfknx.UX/EAkWueHmDmf9y.C86sypp41EE80ldu2XrL32sSal2zC1' hsmutil"

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

FILES:${PN} = "/home/hsmutil"
FILES:${PN} += "${@bb.utils.contains('HSM_DEV_MODE', '1', '${sysconfdir}/sudoers.d/hsmutil', '', d)}"
PREPROCESS_MAN_PAGES = ""
