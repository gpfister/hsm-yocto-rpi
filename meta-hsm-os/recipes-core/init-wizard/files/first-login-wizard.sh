#!/bin/bash
# ==============================================================================
# first-login-wizard.sh - Mandatory Initial Operator Setup Wizard
# ==============================================================================
set -e

MARKER_FILE="${HOME}/.wizard_completed"

if [[ -f "${MARKER_FILE}" ]]; then
    exit 0
fi

clear
echo "=================================================================="
echo "          nRF52840 HSM AIR-GAPPED APPLIANCE INITIAL SETUP         "
echo "=================================================================="
echo ""
echo "Welcome! This appliance is running an immutable air-gapped Linux OS."
echo "Before proceeding, initial operator configuration is required."
echo ""

# 1. Force Password Change
echo "------------------------------------------------------------------"
echo "Step 1: Set New Operator Password"
echo "------------------------------------------------------------------"
echo "You must now change the default password for account '$(whoami)'."
while true; do
    if passwd; then
        echo "Password updated successfully."
        break
    else
        echo "Password change failed. Retrying..."
        sleep 1
    fi
done

# 2. Keyboard Layout Selection
echo ""
echo "------------------------------------------------------------------"
echo "Step 2: Keyboard Layout Selection"
echo "------------------------------------------------------------------"
echo "Select your physical keyboard layout:"
echo "  1) US English (us)"
echo "  2) French (fr)"
echo "  3) German (de)"
echo "  4) UK English (uk)"
echo "  5) Swiss French (fr_CH)"
echo "  6) Swiss German (sg)"
read -r -p "Enter choice [1-6] (default: 1): " KB_CHOICE

case "${KB_CHOICE}" in
    2) KEYMAP="fr" ;;
    3) KEYMAP="de" ;;
    4) KEYMAP="uk" ;;
    5) KEYMAP="fr_CH" ;;
    6) KEYMAP="sg" ;;
    *) KEYMAP="us" ;;
esac

if command -v loadkeys >/dev/null 2>&1; then
    loadkeys "${KEYMAP}" 2>/dev/null || true
    echo "Keyboard layout set to: ${KEYMAP}"
fi
echo "${KEYMAP}" > "${HOME}/.keymap"

# 3. Timezone / Locale Selection
echo ""
echo "------------------------------------------------------------------"
echo "Step 3: Locale & Timezone"
echo "------------------------------------------------------------------"
echo "Air-gapped operation uses UTC system time as the baseline standard."
export TZ="UTC"
echo "export TZ=UTC" >> "${HOME}/.profile"

# Mark completed
touch "${MARKER_FILE}"
echo ""
echo "=================================================================="
echo "          INITIAL SETUP COMPLETE. PROCEEDING TO OPERATOR CONSOLE   "
echo "=================================================================="
sleep 2
