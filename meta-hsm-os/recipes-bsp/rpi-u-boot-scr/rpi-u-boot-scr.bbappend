FILESEXTRAPATHS:prepend:rauc-integration := "${THISDIR}/files:"

SRC_URI:append:rauc-integration = " file://boot.cmd.in"

# RAUC A/B integration (formerly provided by the community RAUC layer)
inherit rauc-integration
