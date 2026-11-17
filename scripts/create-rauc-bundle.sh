#!/usr/bin/env bash
# ==============================================================================
# create-rauc-bundle.sh: Build signed RAUC A/B update bundle
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

MACHINE="${MACHINE:-${KAS_MACHINE:-raspberrypi0-2w-64}}"
export KAS_MACHINE="${MACHINE}"

OUTPUT_DIR="${REPO_DIR}/build/deploy/bundles"
DEPLOY_DIR="${REPO_DIR}/build/deploy/images/${MACHINE}"

"${SCRIPT_DIR}/generate-rauc-keys.sh"

echo "==> Building RAUC update bundle for machine ${MACHINE} using Kas..."
"${SCRIPT_DIR}/run-kas.sh" build kas-bundle.yml

echo "==> Verifying generated update bundle in ${DEPLOY_DIR}..."
if [[ ! -d "${DEPLOY_DIR}" ]]; then
    echo "ERROR: Deploy directory ${DEPLOY_DIR} does not exist." >&2
    exit 1
fi

BUNDLE_FILES=()
while IFS= read -r -d '' file; do
    BUNDLE_FILES+=("$file")
done < <(find "${DEPLOY_DIR}" -maxdepth 1 -name "*.raucb" -type f -print0 2>/dev/null || true)

if [[ ${#BUNDLE_FILES[@]} -eq 0 ]]; then
    echo "ERROR: No RAUC update bundle (*.raucb) found in ${DEPLOY_DIR}" >&2
    exit 1
fi

LATEST_BUNDLE="${BUNDLE_FILES[0]}"
for b in "${BUNDLE_FILES[@]}"; do
    if [[ "$b" -nt "$LATEST_BUNDLE" ]]; then
        LATEST_BUNDLE="$b"
    fi
done

mkdir -p "${OUTPUT_DIR}"
CANONICAL_BUNDLE="${OUTPUT_DIR}/update-bundle.raucb"
cp -f "${LATEST_BUNDLE}" "${CANONICAL_BUNDLE}"

echo "==> RAUC update bundle successfully created:"
echo "    Source:    ${LATEST_BUNDLE}"
echo "    Canonical: ${CANONICAL_BUNDLE}"
echo "    Size:      $(ls -lh "${CANONICAL_BUNDLE}" | awk '{print $5}')"
echo "    Timestamp: $(date -r "${CANONICAL_BUNDLE}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || stat -c "%y" "${CANONICAL_BUNDLE}" 2>/dev/null || stat -f "%Sm" "${CANONICAL_BUNDLE}" 2>/dev/null || date)"
echo "==> Update bundle packaging process complete."
