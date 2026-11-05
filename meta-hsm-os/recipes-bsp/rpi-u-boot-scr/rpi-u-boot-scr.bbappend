FILESEXTRAPATHS:prepend:rauc-integration := "${THISDIR}/files:"

SRC_URI:append:rauc-integration = " file://boot.cmd.in"

# RAUC A/B integration (formerly provided by the community RAUC layer)
inherit rauc-integration

HSM_DEV_MODE ??= "0"

do_compile() {
    if [ "${HSM_DEV_MODE}" = "1" ]; then
        sed -e 's/@@KERNEL_IMAGETYPE@@/${KERNEL_IMAGETYPE}/' \
            -e 's/@@KERNEL_BOOTCMD@@/${KERNEL_BOOTCMD}/' \
            -e 's/@@BOOT_MEDIA@@/${BOOT_MEDIA}/' \
            -e '/@@UBOOT_SILENT_BOOT@@/d' \
            -e 's/@@RAUC_ECHO_START@@//' \
            -e 's/@@RAUC_ECHO_END@@//' \
            "${UNPACKDIR}/boot.cmd.in" > "${WORKDIR}/boot.cmd"
    else
        sed -e 's/@@KERNEL_IMAGETYPE@@/${KERNEL_IMAGETYPE}/' \
            -e 's/@@KERNEL_BOOTCMD@@/${KERNEL_BOOTCMD}/' \
            -e 's/@@BOOT_MEDIA@@/${BOOT_MEDIA}/' \
            -e 's/@@UBOOT_SILENT_BOOT@@/setenv silent 1/' \
            -e '/@@RAUC_ECHO_START@@/d' \
            "${UNPACKDIR}/boot.cmd.in" > "${WORKDIR}/boot.cmd"
    fi
    mkimage -A ${@oe.kernel.map_uboot_arch(d)} -T script -C none -n "Boot script" -d "${WORKDIR}/boot.cmd" boot.scr
}
