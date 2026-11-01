SUMMARY = "Out-of-tree Linux Kernel Driver for nRF52840 HSM Dongle"
DESCRIPTION = "Kernel character device driver exposing deterministic /dev/tty.hsm<ble_address><number> nodes with production AT interface filtering."
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://nrf52840_hsm.c;beginline=1;endline=10;md5=74bea7ac8085d514df64c426d3b511b8"

inherit module

SRC_URI = " \
    file://Makefile \
    file://nrf52840_hsm.c \
"

S = "${WORKDIR}"

HSM_DEV_MODE ??= "0"

KERNEL_MODULE_AUTOLOAD += "nrf52840_hsm"
module_conf_nrf52840_hsm = "options nrf52840_hsm hsm_dev_mode=${HSM_DEV_MODE}"

RPROVIDES:${PN} += "kernel-module-nrf52840-hsm"
