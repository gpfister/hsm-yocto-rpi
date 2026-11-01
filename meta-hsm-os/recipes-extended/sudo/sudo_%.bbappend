# Sudoers configuration for hsmutil in development builds
do_install:append() {
    install -d -m 0750 ${D}${sysconfdir}/sudoers.d
    echo "hsmutil ALL=(ALL) NOPASSWD: ALL" > ${D}${sysconfdir}/sudoers.d/01-hsmutil
    chmod 0440 ${D}${sysconfdir}/sudoers.d/01-hsmutil
}

FILES:${PN}-lib += "${sysconfdir}/sudoers.d/01-hsmutil"
