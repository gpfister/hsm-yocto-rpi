# Avoid file collision with libpwquality which provides the hardened common-password
do_install:append() {
    rm -f ${D}${sysconfdir}/pam.d/common-password
}
