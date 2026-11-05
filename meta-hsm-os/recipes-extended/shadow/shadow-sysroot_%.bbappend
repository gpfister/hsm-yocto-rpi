# Enforce 90-day password expiration policy during sysroot useradd operations
do_install:append() {
    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS\t90/' ${D}${sysconfdir}/login.defs
    if ! grep -q "^PASS_MAX_DAYS" ${D}${sysconfdir}/login.defs; then
        echo "PASS_MAX_DAYS\t90" >> ${D}${sysconfdir}/login.defs
    fi
}
