# `rpi-z2w-yocto-hsm` — Air-Gapped Embedded Linux OS for nRF52840 HSM

This repository contains the Yocto Project 6.1 (`blacksail`, BitBake 2.20) build system and custom layer (`meta-hsm-os`) for building an ultra-hardened, air-gapped, 64-bit embedded Linux operating system tailored for sensitive cryptographic operations with the nRF52840 USB Dongle (`PCA10059`) and Raspberry Pi hardware.

---

## 1. System Architecture

```text
+-------------------------------------------------------------------------+
|                  Air-Gapped Hardware Appliance                          |
|  Raspberry Pi Zero 2 W / 3 / 4 / 5 + Waveshare USB HAT (B) + HDMI       |
+------------------------------------+------------------------------------+
                                     |
+------------------------------------v------------------------------------+
|  U-Boot Bootloader (Dual-Slot A/B Partition Manager + Boot Counter)    |
|  - Slot A: /dev/mmcblk0p2 (ext4 read-only)                              |
|  - Slot B: /dev/mmcblk0p3 (ext4 read-only)                              |
+------------------------------------+------------------------------------+
                                     |
+------------------------------------v------------------------------------+
|  Linux Kernel 6.12+ (Hardened Configuration)                            |
|  - WiFi, Bluetooth, Ethernet disabled at hardware/DTB & kernel level    |
|  - nftables 100% total-drop packet filter (zero in/out/routed traffic)  |
|  - Out-of-tree Driver: nrf52840-hsm-kmod                               |
|    -> Matches USB 0x1209:0x0001                                         |
|    -> Registers /dev/tty.hsm<ble_address><number>                       |
|    -> Production: Strictly binds AT channel (cdc_acm_uart1)             |
|    -> Dev: Binds both AT channel and debug console                      |
+------------------------------------+------------------------------------+
                                     |
+------------------------------------v------------------------------------+
|  Read-Only User Space                                                   |
|  - System User: hsmutil (dialout, tty, storage)                         |
|  - First-Login Setup Wizard: Forced password reset, loadkeys, locale    |
|  - Every-Login Clock Prompt: Operator UTC timestamp synchronization     |
|  - Application: /usr/local/bin/hsmutil (Cobra CLI / BubbleTea TUI)      |
|  - USB Storage Automount: rw access under /media/usb-* for key exports  |
|  - RAUC Service: Dual-slot x509-signed USB auto-installer (.raucb)     |
+-------------------------------------------------------------------------+
```

---

## 2. Security Hardening Specifications

| Dimension | Specification | Production (`prod`) | Development (`dev`) |
| :--- | :--- | :--- | :--- |
| **Filesystem** | Root Filesystem | Read-only ext4 / squashfs | Read-only ext4 with overlayfs |
| **Networking** | Physical Interfaces | WiFi, BLE, Ethernet disabled in DTB / kernel configs | Same (strict air-gap) |
| **Firewall** | Packet Filter | `nftables` default drop all inbound, outbound, forward | Same (strict air-gap) |
| **GPIOs** | Hardware Headers | Disabled in device tree overlay | Disabled / debugging header |
| **Root Account** | Superuser Access | Password unset, root login disabled | Password `root`, console access |
| **`hsmutil` User** | Privilege Escalation | Standard unprivileged user, no `sudo` | Sudoer with NOPASSWD |
| **Logging** | System & Kernel Logs | Disabled (`quiet`, no disk logging) | Stored in RAM / journald |
| **Dongle Ports** | Interface Exposure | Only AT command channel (`cdc_acm_uart1`) | Both AT command + debug log |
| **SSH** | Remote Terminal | Completely absent from image | Completely absent from image |

---

## 3. Directory Layout

```text
rpi-z2w-yocto-hsm/
├── Makefile                      # Build orchestration targets
├── kas-project.yml               # Base Kas configuration (Blacksail layers)
├── kas-dev.yml                   # Dev image overlay (sudo, debug ports)
├── kas-prod.yml                  # Hardened production image overlay
├── LICENSE                       # MIT License
├── README.md                     # This file
├── keys/                         # RAUC update signing certificates & keys
│   ├── rauc-ca.cert.pem          # Public CA embedded into target image
│   ├── rauc-ca.key.pem           # CA private key (git-ignored)
│   ├── development-signing.cert.pem
│   ├── development-signing.key.pem
│   └── README.md
├── meta-hsm-os/                  # Custom Yocto Layer
│   ├── conf/
│   │   └── layer.conf
│   ├── recipes-bsp/
│   │   ├── bootfiles/            # config.txt overlays (disable wifi/bt)
│   │   └── rpi-u-boot-scr/       # U-Boot dual-slot boot script
│   ├── recipes-connectivity/
│   │   └── nftables/             # Strict total-drop firewall rules
│   ├── recipes-core/
│   │   ├── images/               # hsm-image-base, hsm-image-dev, hsm-image-prod
│   │   ├── init-wizard/          # First-login wizard & date prompt scripts
│   │   └── users/                # hsmutil user configuration
│   ├── recipes-kernel/
│   │   ├── linux/                # Kernel defconfig hardening fragment
│   │   └── nrf52840-hsm-kmod/    # Dedicated out-of-tree kernel driver
│   ├── recipes-rauc/
│   │   └── bundles/              # RAUC update bundle recipe (.raucb)
│   └── recipes-support/
│       ├── hsmutil/              # Bitbake recipe packaging hsmutil binary
│       ├── rauc/                 # RAUC system.conf and USB installer service
│       └── usb-mount/            # Automount udev rules for storage
└── scripts/
    ├── run-kas.sh                # Containerized Kas launcher
    ├── create-rauc-bundle.sh     # Offline signed bundle builder
    ├── flash-sd.sh               # SD card raw flasher
    └── generate-rauc-keys.sh     # Key generation script
```

---

## 4. Quick Start & Build Instructions

### Prerequisites
- Docker or Podman installed on the host.
- At least 50 GB free disk space.

### Building OS Images

```bash
# Build development image (hsm-image-dev) for default machine (raspberrypi0-2w-64)
make build-dev

# Build production air-gapped image (hsm-image-prod)
make build-prod

# Target specific Raspberry Pi model (Pi 3, Pi 4, Pi 5)
make build-prod MACHINE=raspberrypi4-64
```

### Interactive Kas Shell

```bash
make shell
```

---

## 5. Flashing to SD Card

Use the provided flashing script to flash the generated `.img` or `.wic.bz2` image:

```bash
# Warning: Destructive operation! Verify block device carefully.
# Flash uncompressed .img image directly:
./scripts/flash-sd.sh build/deploy/images/raspberrypi0-2w-64/hsm-image-prod-raspberrypi0-2w-64.rootfs.img /dev/rdisk4

# Or stream compressed .wic.bz2 image on the fly:
./scripts/flash-sd.sh build/deploy/images/raspberrypi0-2w-64/hsm-image-prod-raspberrypi0-2w-64.rootfs.wic.bz2 /dev/rdisk4
```

---

## 6. Offline RAUC A/B Firmware Updates

1. **Build signed update bundle**:
   ```bash
   make bundle
   ```
2. **Deploy to USB Flash Drive**:
   - Copy the generated `.raucb` bundle file to the root of a FAT32 or ext4 formatted USB drive.
3. **Plug into Air-Gapped Appliance**:
   - Insert the USB drive into the Waveshare USB HAT (B).
   - `rauc-usb-autoinstall.service` automatically verifies the cryptographic signature against embedded `rauc-ca.cert.pem` and streams the image into the inactive partition slot.
4. **Reboot**:
   - U-Boot activates the new partition on next reboot.

## Migration Note: Yocto 5.0 (Scarthgap) → 6.1 (Blacksail)

- `poky` was replaced by `openembedded-core`, `bitbake` (2.20) and `meta-yocto` in `kas-project.yml`.
- `meta-lts-mixins` and `meta-rauc-community` were dropped; the Raspberry Pi RAUC A/B integration (WIC layout, U-Boot patch/boot script, kernel `rauc.cfg`, `/data` fstab, udev ignore list) now lives inside `meta-hsm-os`.
- `meta-raspberrypi` and `meta-rauc` track `master` (no `blacksail` branch yet) with `LAYERSERIES_COMPAT` overrides in `kas-project.yml`.
- Recipes use `${UNPACKDIR}` instead of `${WORKDIR}`; `debug-tweaks` was replaced by `allow-root-login post-install-logging` in the dev image.
- `nrf52840_hsm.c` guards `.llseek = noop_llseek` for kernels older than 6.12.
- After upgrading, run `make yocto-clean` and remove the stale `poky/`, `meta-lts-mixins/` and `meta-rauc-community/` clones.
