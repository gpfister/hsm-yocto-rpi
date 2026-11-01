#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
KEYS_DIR="${REPO_DIR}/keys"

CA_KEY="${KEYS_DIR}/rauc-ca.key.pem"
CA_CERT="${KEYS_DIR}/rauc-ca.cert.pem"
SIGN_KEY="${KEYS_DIR}/development-signing.key.pem"
SIGN_CERT="${KEYS_DIR}/development-signing.cert.pem"

mkdir -p "${KEYS_DIR}"

if [[ -f "${CA_CERT}" && -f "${SIGN_CERT}" && -f "${SIGN_KEY}" ]]; then
    echo "==> RAUC update keys and certificates already exist in ${KEYS_DIR}."
    exit 0
fi

echo "==> Generating RAUC Root CA & Signing Certificate (ECDSA prime256v1)..."

# 1. Generate Root CA Key & Certificate
if [[ ! -f "${CA_CERT}" ]]; then
    echo "  -> Generating RAUC Root CA key and certificate..."
    openssl ecparam -name prime256v1 -genkey -noout -out "${CA_KEY}"
    openssl req -new -x509 -key "${CA_KEY}" -days 3650 \
        -subj "/O=nRF52840 HSM OS/CN=RAUC Root CA" \
        -out "${CA_CERT}"
    chmod 600 "${CA_KEY}"
    chmod 644 "${CA_CERT}"
fi

# 2. Generate Development Signing Key & CSR
if [[ ! -f "${SIGN_CERT}" ]]; then
    echo "  -> Generating RAUC Development Signing key and certificate..."
    openssl ecparam -name prime256v1 -genkey -noout -out "${SIGN_KEY}"
    SIGN_CSR="${KEYS_DIR}/development-signing.csr"
    openssl req -new -key "${SIGN_KEY}" \
        -subj "/O=nRF52840 HSM OS/CN=RAUC Development Signer" \
        -out "${SIGN_CSR}"
    
    # Sign with Root CA
    openssl x509 -req -in "${SIGN_CSR}" -CA "${CA_CERT}" -CAkey "${CA_KEY}" \
        -CAcreateserial -days 1825 -out "${SIGN_CERT}"
    rm -f "${SIGN_CSR}"
    chmod 600 "${SIGN_KEY}"
    chmod 644 "${SIGN_CERT}"
fi

echo "==> RAUC PKI generation complete."
echo "    CA Certificate:      ${CA_CERT}"
echo "    Signing Certificate: ${SIGN_CERT}"
echo "    Signing Key:         ${SIGN_KEY}"
