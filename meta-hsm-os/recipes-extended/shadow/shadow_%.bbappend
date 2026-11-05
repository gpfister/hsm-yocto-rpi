# Enforce 90-day password expiration policy across all user accounts
do_install:append:class-target() {
    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS\t90/' ${D}${sysconfdir}/login.defs
    if ! grep -q "^PASS_MAX_DAYS" ${D}${sysconfdir}/login.defs; then
        echo "PASS_MAX_DAYS\t90" >> ${D}${sysconfdir}/login.defs
    fi
}
