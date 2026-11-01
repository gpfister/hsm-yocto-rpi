#!/usr/bin/env bash
# ==============================================================================
# run-kas.sh: Containerized Kas execution wrapper for rpi-z2w-yocto-hsm
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

KAS_IMAGE="${KAS_IMAGE:-ghcr.io/siemens/kas/kas:latest}"
CONTAINER_ENGINE="${CONTAINER_ENGINE:-$(which podman 2>/dev/null || which docker 2>/dev/null || echo docker)}"
KAS_MACHINE="${KAS_MACHINE:-raspberrypi0-2w-64}"

if ! command -v "${CONTAINER_ENGINE}" >/dev/null 2>&1; then
    echo "Error: Container engine '${CONTAINER_ENGINE}' not found. Please install Docker or Podman." >&2
    exit 1
fi

echo "==> Running Kas via ${CONTAINER_ENGINE} (${KAS_IMAGE})..."
echo "    Target Machine: ${KAS_MACHINE}"
echo "    Working Dir:    ${REPO_DIR}"

mkdir -p "${REPO_DIR}/build" "${REPO_DIR}/downloads" "${REPO_DIR}/sstate-cache"

# Ensure case-sensitive ext4 Docker volume for BitBake TMPDIR (macOS APFS compatibility)
TMP_VOLUME="${TMP_VOLUME:-rpi_yocto_hsm_tmp}"
"${CONTAINER_ENGINE}" run --rm -v "${TMP_VOLUME}:/v" alpine chown -R "$(id -u):$(id -g)" /v

# Build container run arguments
INTERACTIVE_FLAGS=()
if [ -t 0 ] && [ -t 1 ]; then
    INTERACTIVE_FLAGS=(-it)
else
    INTERACTIVE_FLAGS=(-i)
fi

CONTAINER_ARGS=(
    run --rm "${INTERACTIVE_FLAGS[@]}"
    --user "$(id -u):$(id -g)"
    -v "${REPO_DIR}:/repo:rw"
    -v "${TMP_VOLUME}:/repo/build/tmp:rw"
    -v "${REPO_DIR}/downloads:/downloads:rw"
    -v "${REPO_DIR}/sstate-cache:/sstate-cache:rw"
    -w /repo
    -e "KAS_MACHINE=${KAS_MACHINE}"
    -e "DL_DIR=/downloads"
    -e "SSTATE_DIR=/sstate-cache"
    "${KAS_IMAGE}"
)

exec "${CONTAINER_ENGINE}" "${CONTAINER_ARGS[@]}" kas "$@"
