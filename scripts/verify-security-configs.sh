#!/bin/bash
# ==============================================================================
# verify-security-configs.sh - Security Policy & Hardening Automated Verification
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ERRORS=0

log_pass() {
    echo "  [PASS] $1"
}

log_fail() {
    echo "  [FAIL] $1" >&2
    ERRORS=$((ERRORS + 1))
}

echo "=== 1. Checking kas-dev.yml and kas-prod.yml ==="
if grep -q 'HSM_DEV_MODE = "1"' "${REPO_DIR}/kas-dev.yml"; then
    log_pass "kas-dev.yml defines HSM_DEV_MODE = '1'"
else
    log_fail "kas-dev.yml missing HSM_DEV_MODE = '1'"
fi

if grep -q "APPEND" "${REPO_DIR}/kas-dev.yml"; then
    log_fail "kas-dev.yml contains obsolete APPEND variable"
else
    log_pass "kas-dev.yml has cleaned up obsolete APPEND variable"
fi

if grep -q 'HSM_DEV_MODE = "0"' "${REPO_DIR}/kas-prod.yml"; then
    log_pass "kas-prod.yml defines HSM_DEV_MODE = '0'"
else
    log_fail "kas-prod.yml missing HSM_DEV_MODE = '0'"
fi

if grep -q "APPEND" "${REPO_DIR}/kas-prod.yml"; then
    log_fail "kas-prod.yml contains obsolete APPEND variable"
else
    log_pass "kas-prod.yml has cleaned up obsolete APPEND variable"
fi

echo ""
echo "=== 2. Checking kas-project.yml ==="
if grep -q 'DISTRO_FEATURES:append = ".*pam' "${REPO_DIR}/kas-project.yml"; then
    log_pass "kas-project.yml enables pam in DISTRO_FEATURES"
else
    log_fail "kas-project.yml does not include pam in DISTRO_FEATURES"
fi

if grep -q 'DISTRO_FEATURES_OPTED_OUT' "${REPO_DIR}/kas-project.yml"; then
    log_pass "kas-project.yml uses DISTRO_FEATURES_OPTED_OUT for Yocto 6.1"
else
    log_fail "kas-project.yml does not use DISTRO_FEATURES_OPTED_OUT"
fi

echo ""
echo "=== 3. Checking rpi-cmdline.bbappend ==="
CMDLINE_BBAPPEND="${REPO_DIR}/meta-hsm-os/recipes-bsp/bootfiles/rpi-cmdline.bbappend"
if [[ -f "${CMDLINE_BBAPPEND}" ]]; then
    log_pass "rpi-cmdline.bbappend exists"
    if grep -q "console=serial0,115200 console=tty1 loglevel=7 debug earlyprintk" "${CMDLINE_BBAPPEND}"; then
        log_pass "CMDLINE_DEV contains console=serial0,115200 console=tty1 loglevel=7 debug earlyprintk"
    else
        log_fail "CMDLINE_DEV missing required dev boot arguments"
    fi

    if grep -q "quiet loglevel=0 console=tty1 fsck.mode=skip" "${CMDLINE_BBAPPEND}"; then
        log_pass "CMDLINE_PROD contains quiet loglevel=0 console=tty1 fsck.mode=skip"
    else
        log_fail "CMDLINE_PROD missing required prod boot arguments"
    fi
else
    log_fail "rpi-cmdline.bbappend not found"
fi

echo ""
echo "=== 4. Checking U-Boot Hardening & Kconfig Fragments ==="
SQUASHFS_CFG="${REPO_DIR}/meta-hsm-os/recipes-bsp/u-boot/files/squashfs.cfg"
SILENT_CFG="${REPO_DIR}/meta-hsm-os/recipes-bsp/u-boot/files/silent-boot.cfg"
UBOOT_BBAPPEND="${REPO_DIR}/meta-hsm-os/recipes-bsp/u-boot/u-boot_%.bbappend"
OLD_PATCH="${REPO_DIR}/meta-hsm-os/recipes-bsp/u-boot/files/rpi_arm64_defconfig.patch"

if [[ ! -f "${OLD_PATCH}" ]]; then
    log_pass "Brittle rpi_arm64_defconfig.patch removed"
else
    log_fail "rpi_arm64_defconfig.patch still exists"
fi

if grep -q "CONFIG_FS_SQUASHFS=y" "${SQUASHFS_CFG}" && grep -q "CONFIG_CMD_SQUASHFS=y" "${SQUASHFS_CFG}"; then
    log_pass "squashfs.cfg defines CONFIG_FS_SQUASHFS and CONFIG_CMD_SQUASHFS"
else
    log_fail "squashfs.cfg missing required config options"
fi

if grep -q "CONFIG_BOOTDELAY=-2" "${SILENT_CFG}" && grep -q "CONFIG_SILENT_CONSOLE=y" "${SILENT_CFG}" && \
   grep -q "CONFIG_SYS_DEVICE_NULLDEV=y" "${SILENT_CFG}" && grep -q "CONFIG_SILENT_U_BOOT_ONLY=y" "${SILENT_CFG}"; then
    log_pass "silent-boot.cfg defines CONFIG_BOOTDELAY=-2 and silence flags"
else
    log_fail "silent-boot.cfg missing required silence options"
fi

if grep -q "silent-boot.cfg" "${UBOOT_BBAPPEND}" && grep -q "squashfs.cfg" "${UBOOT_BBAPPEND}"; then
    log_pass "u-boot_%.bbappend references squashfs.cfg and silent-boot.cfg conditionally"
else
    log_fail "u-boot_%.bbappend does not properly reference config fragments"
fi

echo ""
echo "=== 5. Checking rpi-u-boot-scr and boot.cmd.in ==="
BOOT_CMD_IN="${REPO_DIR}/meta-hsm-os/recipes-bsp/rpi-u-boot-scr/files/boot.cmd.in"
SCR_BBAPPEND="${REPO_DIR}/meta-hsm-os/recipes-bsp/rpi-u-boot-scr/rpi-u-boot-scr.bbappend"

if grep -q "@@UBOOT_SILENT_BOOT@@" "${BOOT_CMD_IN}" && grep -q "@@RAUC_ECHO_START@@" "${BOOT_CMD_IN}"; then
    log_pass "boot.cmd.in contains silence and echo substitution placeholders"
else
    log_fail "boot.cmd.in missing placeholders"
fi

if grep -q "setenv silent 1" "${SCR_BBAPPEND}"; then
    log_pass "rpi-u-boot-scr.bbappend injects 'setenv silent 1' in production mode"
else
    log_fail "rpi-u-boot-scr.bbappend does not inject 'setenv silent 1'"
fi

echo ""
echo "=== 6. Checking Operator Account and Default Password ==="
USER_BB="${REPO_DIR}/meta-hsm-os/recipes-core/users/hsmutil-user.bb"
EXPECTED_HASH="qFmFH.bQmmtXzyBY0s9v7Oicd2z4XSIecDzlB5KiA2/jctKu9YterLp8wwnSq.qc.eoxqOmSuNp2xS0ktL3nh/"

if grep -q "${EXPECTED_HASH}" "${USER_BB}"; then
    log_pass "hsmutil-user.bb contains SHA-512 hash for default password 'password'"
else
    log_fail "hsmutil-user.bb missing expected password hash"
fi

echo ""
echo "=== 7. Checking 90-Day Password Expiration (shadow) ==="
SHADOW_BBAPPEND="${REPO_DIR}/meta-hsm-os/recipes-extended/shadow/shadow_%.bbappend"
SHADOW_SYSROOT_BBAPPEND="${REPO_DIR}/meta-hsm-os/recipes-extended/shadow/shadow-sysroot_%.bbappend"

if [[ -f "${SHADOW_BBAPPEND}" ]] && grep -q "PASS_MAX_DAYS.*90" "${SHADOW_BBAPPEND}"; then
    log_pass "shadow_%.bbappend enforces PASS_MAX_DAYS 90"
else
    log_fail "shadow_%.bbappend does not configure PASS_MAX_DAYS 90"
fi

if [[ -f "${SHADOW_SYSROOT_BBAPPEND}" ]] && grep -q "PASS_MAX_DAYS.*90" "${SHADOW_SYSROOT_BBAPPEND}"; then
    log_pass "shadow-sysroot_%.bbappend enforces PASS_MAX_DAYS 90"
else
    log_fail "shadow-sysroot_%.bbappend does not configure PASS_MAX_DAYS 90"
fi

echo ""
echo "=== 8. Checking Password Complexity (libpwquality) ==="
IMAGE_BASE_BB="${REPO_DIR}/meta-hsm-os/recipes-core/images/hsm-image-base.bb"
PWQUALITY_CONF="${REPO_DIR}/meta-hsm-os/recipes-extended/libpwquality/files/pwquality.conf"
PAM_COMMON_PW="${REPO_DIR}/meta-hsm-os/recipes-extended/libpwquality/files/common-password"

if grep -q "libpwquality" "${IMAGE_BASE_BB}"; then
    log_pass "hsm-image-base.bb includes libpwquality in IMAGE_INSTALL"
else
    log_fail "hsm-image-base.bb missing libpwquality in IMAGE_INSTALL"
fi

if [[ -f "${PWQUALITY_CONF}" ]]; then
    log_pass "pwquality.conf exists"
    for rule in "minlen = 10" "dcredit = -1" "ucredit = -1" "ocredit = -1" "maxrepeat = 1" "maxsequence = 2" "difok = 1" "enforce_for_root"; do
        if grep -q "${rule}" "${PWQUALITY_CONF}"; then
            log_pass "pwquality.conf enforces ${rule}"
        else
            log_fail "pwquality.conf missing ${rule}"
        fi
    done
else
    log_fail "pwquality.conf not found"
fi

if [[ -f "${PAM_COMMON_PW}" ]] && grep -q "pam_pwquality.so" "${PAM_COMMON_PW}"; then
    log_pass "common-password configures pam_pwquality.so"
else
    log_fail "common-password missing pam_pwquality.so configuration"
fi

echo ""
echo "=== Verification Summary ==="
if [ $ERRORS -eq 0 ]; then
    echo "All security configurations verified successfully! (0 errors)"
    exit 0
else
    echo "Verification encountered $ERRORS errors." >&2
    exit 1
fi
