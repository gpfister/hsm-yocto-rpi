#!/bin/bash
# ==============================================================================
# clock-setup.sh - Air-Gapped Login Clock Synchronization Prompt
# ==============================================================================

# Restore keyboard map if previously saved
if [[ -f "${HOME}/.keymap" ]] && command -v loadkeys >/dev/null 2>&1; then
    KEYMAP=$(cat "${HOME}/.keymap" 2>/dev/null || echo "us")
    loadkeys "${KEYMAP}" >/dev/null 2>&1 || true
fi

CURRENT_TIME=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
echo ""
echo "------------------------------------------------------------------"
echo "Air-Gapped Clock Notice:"
echo "Current System Time: ${CURRENT_TIME}"

RTC_PRESENT=0
if [[ -c /dev/rtc0 ]] || [[ -e /dev/rtc0 ]]; then
    RTC_PRESENT=1
    RTC_TIME=$(hwclock -u -r 2>/dev/null || true)
    echo "Hardware RTC detected (/dev/rtc0): active and synchronized"
    if [[ -n "${RTC_TIME}" ]]; then
        echo "Hardware RTC Time:   ${RTC_TIME}"
    fi
else
    echo "Hardware RTC (/dev/rtc0): not detected (uninitialized or disconnected)"
fi
echo "------------------------------------------------------------------"

if [[ ${RTC_PRESENT} -eq 1 ]]; then
    echo "Because this machine is air-gapped, the hardware RTC provides accurate"
    echo "time across power cycles. Press [Enter] to keep the current RTC time,"
    echo "or enter a new timestamp to adjust both system and hardware clocks."
else
    echo "Because this machine is strictly air-gapped without NTP network sync"
    echo "or battery-backed RTC, verify and update the system clock for"
    echo "accurate cryptographic certificate timestamps and audit logs."
fi
echo ""
read -r -p "Enter current UTC date/time [YYYY-MM-DD HH:MM:SS] (or Enter to keep): " USER_DATE

if [[ -n "${USER_DATE}" ]]; then
    if command -v hsm-set-date >/dev/null 2>&1; then
        hsm-set-date "${USER_DATE}"
    elif sudo -n true 2>/dev/null; then
        sudo date -u -s "${USER_DATE}" || echo "Failed to set date."
        if [[ ${RTC_PRESENT} -eq 1 ]]; then
            sudo hwclock -u -w 2>/dev/null || true
        fi
    elif command -v date >/dev/null 2>&1; then
        date -u -s "${USER_DATE}" 2>/dev/null || echo "Note: Root privileges required to adjust clock."
        if [[ ${RTC_PRESENT} -eq 1 ]] && command -v hwclock >/dev/null 2>&1; then
            hwclock -u -w 2>/dev/null || true
        fi
    fi

    # Fallback hwclock write to ensure hardware RTC sync
    if [[ ${RTC_PRESENT} -eq 1 ]] && command -v hwclock >/dev/null 2>&1; then
        hwclock -u -w 2>/dev/null || true
    fi

    echo "Updated System Time: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
fi
echo "------------------------------------------------------------------"
echo ""
