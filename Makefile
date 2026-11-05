# ==============================================================================
# rpi-z2w-yocto-hsm Sub-Repository Makefile
# Yocto Project 6.1 (Blacksail) Air-Gapped HSM Operating System
# ==============================================================================

SHELL := /bin/bash

# Configuration
KAS_IMAGE ?= ghcr.io/siemens/kas/kas:latest
CONTAINER_ENGINE ?= $(shell which podman 2>/dev/null || which docker 2>/dev/null || echo docker)
MACHINE ?= raspberrypi0-2w-64
BUILD_DIR ?= build

.PHONY: help build-dev build-prod bundle clean shell keys check-docker

help:
	@echo "=================================================================="
	@echo "     rpi-z2w-yocto-hsm: Air-Gapped Embedded Linux OS (Yocto 6.1) "
	@echo "=================================================================="
	@echo "Build Targets:"
	@echo "  make build-dev     Build development OS image (hsm-image-dev)"
	@echo "  make build-prod    Build production air-gapped OS image (hsm-image-prod)"
	@echo "  make bundle        Create signed RAUC A/B update bundle (.raucb)"
	@echo "  make shell         Launch interactive Kas shell inside build container"
	@echo "  make clean         Remove build directory (preserves downloads/sstate)"
	@echo "  make keys          Generate self-signed RAUC update keys if missing"
	@echo ""
	@echo "Options:"
	@echo "  MACHINE=<name>     Override target machine (default: raspberrypi0-2w-64)"
	@echo "                     Supported: raspberrypi0-2w-64, raspberrypi3-64,"
	@echo "                                raspberrypi4-64, raspberrypi5"
	@echo "=================================================================="

check-docker:
	@which $(CONTAINER_ENGINE) >/dev/null 2>&1 || (echo "Error: Docker or Podman is required to run Kas container." && exit 1)

keys:
	@./scripts/generate-rauc-keys.sh

build-dev: check-docker keys
	@echo "==> Building Development OS Image with Kas (MACHINE=$(MACHINE))..."
	@KAS_MACHINE=$(MACHINE) ./scripts/run-kas.sh build kas-dev.yml

build-prod: check-docker keys
	@echo "==> Building Production OS Image with Kas (MACHINE=$(MACHINE))..."
	@KAS_MACHINE=$(MACHINE) ./scripts/run-kas.sh build kas-prod.yml

bundle: check-docker keys
	@echo "==> Creating Signed RAUC A/B Update Bundle..."
	@./scripts/create-rauc-bundle.sh

shell: check-docker keys
	@echo "==> Launching interactive Kas shell..."
	@KAS_MACHINE=$(MACHINE) ./scripts/run-kas.sh shell kas-dev.yml

clean:
	@echo "==> Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)/tmp
	@echo "Clean completed."
