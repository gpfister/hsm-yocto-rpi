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

# 1. Force Password Change with Complexity Verification
echo "------------------------------------------------------------------"
echo "Step 1: Set New Operator Password"
echo "------------------------------------------------------------------"
echo "You must now change the default password for account '$(whoami)'."
echo ""
echo "Password Complexity Requirements:"
echo "  1. Minimum length of 10 characters"
echo "  2. At least one numeric digit (0-9)"
echo "  3. At least one uppercase letter (A-Z)"
echo "  4. At least one special character (!@#\$%^&*...)"
echo "  5. No 2 consecutive identical characters (e.g. 'aa', '11', '!!')"
echo "  6. No 3 sequential monotonic characters (e.g. 'abc', '123', '321')"
echo ""

validate_password() {
    local pw="$1"
    local len="${#pw}"

    if [ "$len" -lt 10 ]; then
        echo "Password must be at least 10 characters long (currently $len)."
        return 1
    fi

    if ! [[ "$pw" =~ [0-9] ]]; then
        echo "Password must contain at least one numeric digit (0-9)."
        return 1
    fi

    if ! [[ "$pw" =~ [A-Z] ]]; then
        echo "Password must contain at least one uppercase letter (A-Z)."
        return 1
    fi

    if ! [[ "$pw" =~ [^a-zA-Z0-9] ]]; then
        echo "Password must contain at least one special character."
        return 1
    fi

    # Check for consecutive identical characters (maxrepeat = 1 -> no 2 identical consecutive characters)
    local i
    for (( i=0; i<len-1; i++ )); do
        local c1="${pw:$i:1}"
        local c2="${pw:$((i+1)):1}"
        if [ "$c1" = "$c2" ]; then
            echo "Password must not contain consecutive identical characters ('$c1$c2')."
            return 1
        fi
    done

    # Check for 3 sequential monotonic characters (maxsequence = 2 -> no 3 sequential characters)
    for (( i=0; i<len-2; i++ )); do
        local c1="${pw:$i:1}"
        local c2="${pw:$((i+1)):1}"
        local c3="${pw:$((i+2)):1}"

        local lc1=$(printf '%s' "$c1" | tr '[:upper:]' '[:lower:]')
        local lc2=$(printf '%s' "$c2" | tr '[:upper:]' '[:lower:]')
        local lc3=$(printf '%s' "$c3" | tr '[:upper:]' '[:lower:]')

        local a1=$(printf '%d' "'$lc1")
        local a2=$(printf '%d' "'$lc2")
        local a3=$(printf '%d' "'$lc3")

        local is_num=0
        local is_alpha=0
        if [[ "$lc1" =~ [0-9] && "$lc2" =~ [0-9] && "$lc3" =~ [0-9] ]]; then
            is_num=1
        elif [[ "$lc1" =~ [a-z] && "$lc2" =~ [a-z] && "$lc3" =~ [a-z] ]]; then
            is_alpha=1
        fi

        if [ $is_num -eq 1 ] || [ $is_alpha -eq 1 ]; then
            if [ $((a2 - a1)) -eq 1 ] && [ $((a3 - a2)) -eq 1 ]; then
                echo "Password must not contain monotonic sequential characters ('$c1$c2$c3')."
                return 1
            fi
            if [ $((a1 - a2)) -eq 1 ] && [ $((a2 - a3)) -eq 1 ]; then
                echo "Password must not contain monotonic sequential characters ('$c1$c2$c3')."
                return 1
            fi
        fi
    done

    return 0
}

while true; do
    read -s -r -p "Enter new password: " NEW_PW
    echo ""
    if [ -z "$NEW_PW" ]; then
        echo "Password cannot be empty. Please try again."
        continue
    fi

    if ! ERR_MSG=$(validate_password "$NEW_PW"); then
        echo "Password rejected: ${ERR_MSG}"
        echo "Please try again."
        echo ""
        continue
    fi

    read -s -r -p "Confirm new password: " CONFIRM_PW
    echo ""
    if [ "$NEW_PW" != "$CONFIRM_PW" ]; then
        echo "Passwords do not match. Please try again."
        echo ""
        continue
    fi

    # Update password
    if [ "$(id -u)" -eq 0 ] && command -v chpasswd >/dev/null 2>&1; then
        echo "$(whoami):${NEW_PW}" | chpasswd
        echo "Password updated successfully."
        break
    elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        echo "$(whoami):${NEW_PW}" | sudo chpasswd
        echo "Password updated successfully."
        break
    else
        if printf "%s\n%s\n" "${NEW_PW}" "${NEW_PW}" | passwd 2>/dev/null; then
            echo "Password updated successfully."
            break
        else
            echo "Direct password update failed. Starting interactive prompt..."
            if passwd; then
                echo "Password updated successfully."
                break
            else
                echo "Password update failed. Retrying..."
                sleep 1
            fi
        fi
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
