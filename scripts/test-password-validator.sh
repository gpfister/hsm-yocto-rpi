#!/bin/bash
set -e

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

# Positive test cases (must pass)
pass_cases=(
    'Hsm#92K!pL4'
    'Str0ng#Sec!1'
    'A1@b2#C3$d4'
    'v3ry$S3cure!'
)

# Negative test cases (must fail)
fail_cases=(
    "Short1!"         # len < 10
    "nouppercase1!"   # no uppercase
    "NoDigitsHere!"   # no digits
    "NoSpecialChar1"  # no special
    "Passw0rd!!a"     # consecutive identical (!!)
    "Paa1!bcdefg"     # consecutive identical (aa)
    "Abcdefgh1!"      # sequential chars (abc/bcd)
    "12345678A!"      # sequential digits (123)
    "98765432A!"      # reverse sequential digits (987)
    "Fedcba98!1"      # reverse sequential letters (fed)
)

echo "=== Running Password Complexity Validator Tests ==="
failed=0

for pw in "${pass_cases[@]}"; do
    if validate_password "$pw" > /dev/null; then
        echo "PASS (Accepted valid): $pw"
    else
        echo "FAIL (Incorrectly rejected): $pw"
        failed=$((failed + 1))
    fi
done

for pw in "${fail_cases[@]}"; do
    if ! err=$(validate_password "$pw"); then
        echo "PASS (Properly rejected): $pw -> $err"
    else
        echo "FAIL (Incorrectly accepted): $pw"
        failed=$((failed + 1))
    fi
done

if [ $failed -eq 0 ]; then
    echo "=== ALL PASSWORD VALIDATOR TESTS PASSED ==="
    exit 0
else
    echo "=== $failed TESTS FAILED ==="
    exit 1
fi
