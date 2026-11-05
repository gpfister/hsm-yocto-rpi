# meta-hsm-os/recipes-bsp/bootfiles/rpi-cmdline.bbappend
# Hardened and diagnostic kernel command line configurations based on HSM_DEV_MODE

CMDLINE_DEV = "console=serial0,115200 console=tty1 loglevel=7 debug earlyprintk"
CMDLINE_PROD = "quiet loglevel=0 console=tty1 fsck.mode=skip"

CMDLINE = "${@oe.utils.conditional('HSM_DEV_MODE', '1', '${CMDLINE_DEV}', '${CMDLINE_PROD}', d)}"
