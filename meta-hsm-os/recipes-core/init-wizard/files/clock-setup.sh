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
echo "------------------------------------------------------------------"
echo "Because this machine is strictly air-gapped without NTP network sync"
echo "or battery-backed RTC, verify and update the system clock for"
echo "accurate cryptographic certificate timestamps and audit logs."
echo ""
read -r -p "Enter current UTC date/time [YYYY-MM-DD HH:MM:SS] (or Enter to keep): " USER_DATE

if [[ -n "${USER_DATE}" ]]; then
    if sudo -n true 2>/dev/null; then
        sudo date -u -s "${USER_DATE}" || echo "Failed to set date."
    elif command -v date >/dev/null 2>&1; then
        date -u -s "${USER_DATE}" 2>/dev/null || echo "Note: Root privileges required to adjust clock."
    fi
    echo "Updated System Time: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
fi
echo "------------------------------------------------------------------"
echo ""
