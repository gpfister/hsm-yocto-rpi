# RAUC Cryptographic Update Keys

This directory contains the x509 PKI certificates and signing keys used by RAUC (Robust Auto-Update Controller) to cryptographically authenticate and verify `.raucb` update bundles.

---

## 1. File Descriptions

| File | Type | Purpose | Security Policy |
| :--- | :--- | :--- | :--- |
| `rauc-ca.cert.pem` | Public X509 CA Certificate | Embedded in rootfs under `/etc/rauc/ca.cert.pem` (keyring) to verify update bundles. | Public. Safe to commit. |
| `rauc-ca.key.pem` | Private Key (ECDSA P-256) | CA private key used to issue developer or production bundle signing certificates. | **RESTRICTED.** Do NOT commit! Ignored by `.gitignore`. |
| `development-signing.cert.pem` | Public X509 Signer Certificate | Included in the RAUC bundle to establish certificate chain back to Root CA. | Public. Safe to commit. |
| `development-signing.key.pem` | Private Signer Key (ECDSA P-256) | Used during `rauc bundle` to generate cryptographic signatures. | **RESTRICTED.** Do NOT commit! Ignored by `.gitignore`. |

---

## 2. Key Generation & Management

To regenerate development keys:
```bash
./scripts/generate-rauc-keys.sh
```

### Production Signing Ceremonies
In production environments, bundle signing MUST take place on an air-gapped station or using the nRF52840 HSM itself via PKCS#11 provider (`libnrf52840_pkcs11`), ensuring the signing key never touches an untrusted or networked host filesystem.
