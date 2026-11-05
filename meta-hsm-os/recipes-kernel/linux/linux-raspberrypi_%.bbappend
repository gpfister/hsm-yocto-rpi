FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://hardened.cfg \
"

# RAUC A/B integration (formerly provided by the community RAUC layer)
inherit rauc-integration

SRC_URI:append:rauc-integration = " file://rauc.cfg"
CMDLINE:remove:rauc-integration = "root=/dev/mmcblk0p2"
