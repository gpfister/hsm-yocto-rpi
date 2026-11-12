# Air-Gapped Embedded Linux OS for Hardware Security Modules (HSM)

This repository contains the Yocto Project 6.1 (`blacksail`, BitBake 2.20) build system and custom layer (`meta-hsm-os`) for building an ultra-hardened, air-gapped, 64-bit embedded Linux operating system. It serves as a dedicated offgrid, air-gapped appliance designed to perform sensitive cryptographic operations (such as Root CA operations, key ceremonies, and code signing) with connected HSM USB keys on Raspberry Pi hardware.

---

## 1. System Architecture

```text
+-------------------------------------------------------------------------+
|                  Air-Gapped Hardware Appliance (piKMS)                  |
|  Raspberry Pi Zero 2 W / 3 / 4 / 5 + Waveshare USB HAT (B) + HDMI       |
+------------------------------------+------------------------------------+
                                     |
+------------------------------------v------------------------------------+
|  U-Boot Bootloader (Dual-Slot A/B Partition Manager + Boot Counter)    |
|  - no-net.cfg: CONFIG_NET & network commands completely stripped       |
|  - Slot A: /dev/mmcblk0p2 (ext4 read-only)                             |
|  - Slot B: /dev/mmcblk0p3 (ext4 read-only)                             |
+------------------------------------+------------------------------------+
                                     |
+------------------------------------v------------------------------------+
|  Linux Kernel 6.12+ (Hardened Configuration)                            |
|  - WiFi, Bluetooth, Ethernet disabled at hardware/DTB & kernel level    |
|  - nftables 100% total-drop packet filter (zero in/out/routed traffic)  |
|  - Clean Console: logo.nologo, # CONFIG_LOGO is not set                 |
|  - Out-of-tree Driver: nrf52840-hsm-kmod                               |
|    -> Matches USB 0x1209:0x0001                                         |
|    -> Registers /dev/tty.hsm<ble_address><number>                       |
|    -> Production: Strictly binds AT channel (cdc_acm_uart1)             |
|    -> Dev: Binds both AT channel and debug console                      |
|  - Hardware RTC: Maxim DS3231SN on primary I2C-1 (Pins 1, 3, 5, 9)     |
|    -> In-kernel driver: rtc-ds1307 (CONFIG_RTC_DRV_DS1307=y)            |
|    -> Early boot clock synchronization via CONFIG_RTC_HCTOSYS (<50ms)   |
+------------------------------------+------------------------------------+
                                     |
+------------------------------------v------------------------------------+
|  Read-Only User Space (piKMS)                                           |
|  - System Identity: Standardized hostname piKMS                         |
|  - System User: hsmutil (dialout, tty, storage)                         |
|  - Native PAM First-Login Setup: sp_lstchg=0, loadkeys, UTC timezone     |
|  - Persistent Auth State: /data/etc synchronization (shadow, passwd)     |
|  - Clean Console: 10-clean-console.conf & 20-quiet-console.conf         |
|  - RTC-Aware Login Clock Setup: Status check, Enter-to-keep, SUID sync  |
|  - Application: /usr/local/bin/gphsm                                   |
|  - USB Storage Automount: rw access under /media/usb-* for key exports  |
|  - RAUC Service: Dual-slot x509-signed USB auto-installer (.raucb)     |
+-------------------------------------------------------------------------+
```

---

## 2. Security Hardening Specifications

| Dimension | Specification | Production (`prod`) | Development (`dev`) |
| :--- | :--- | :--- | :--- |
| **System Identity** | Hostname | `piKMS` (`hostname:pn-base-files = "piKMS"`) | `piKMS-dev` (`hostname:pn-base-files = "piKMS-dev"`) |
| **Filesystem** | Root Filesystem | Read-only ext4 / squashfs | Read-only ext4 with overlayfs |
| **Networking** | Physical Interfaces | WiFi, BLE, Ethernet disabled in DTB / kernel configs | Same (strict air-gap) |
| **Network Stack** | Protocol Families | Stripped at kernel level (`# CONFIG_INET is not set`, `# CONFIG_IPV6 is not set`, Netfilter stripped) | Same (`CONFIG_UNIX=y`, `CONFIG_NET=y` retained for local IPC) |
| **U-Boot Network** | Bootloader Subsystem | Completely disabled (`CONFIG_NET=n`, `no-net.cfg`) | Completely disabled (`CONFIG_NET=n`, `no-net.cfg`) |
| **Shell History** | Command History | Deactivated (`HISTFILE=/dev/null`, `HISTSIZE=0`, `set +o history`) | Standard interactive history retained |
| **GPIOs** | Hardware Headers | Disabled in device tree overlay | Disabled / debugging header |
| **Root Account** | Superuser Access | Password unset, root login disabled | Password `root`, console access |
| **`hsmutil` User** | Privilege Escalation | Standard unprivileged user, no `sudo` | Sudoer with NOPASSWD |
| **Operator Credentials** | Password & Expiration | Default password `password`, native PAM forced first-login reset (`sp_lstchg=0`), 90-day expiry (`PASS_MAX_DAYS 90`), PAM `pam_pwquality` complexity | Same |
| **Authentication Persistence** | Credential Storage | Targeted sync to `/data/etc` via `hsm-persist-auth.path`, seeds on first boot, atomic restore on reboot | Same |
| **Boot Logos & Splash** | Framebuffer Graphic | Disabled (`# CONFIG_LOGO is not set`, `logo.nologo vt.global_cursor_default=1`, `disable_splash=1`) | Disabled (`# CONFIG_LOGO is not set`, `logo.nologo vt.global_cursor_default=1`) |
| **Console Hardening** | System & Kernel Logs | Silent monitor (`quiet loglevel=0 console=tty1 fsck.mode=skip`, `kernel.printk = 1 1 1 1`, systemd `ShowStatus=no`, `LogLevel=notice`, silent U-Boot) | Dual broadcast (`console=serial0,115200 console=tty1 loglevel=7 debug earlyprintk`, interactive U-Boot) |
| **HSM Device Ports** | Interface Exposure | Only AT command channel (`cdc_acm_uart1`) | Both AT command + debug log |
| **Application Tooling** | Management CLI | `/usr/local/bin/gphsm` (symlink eliminated) | Same |
| **SSH** | Remote Terminal | Completely absent from image | Completely absent from image |

### 2.1 Operator Authentication & Password Security Policy

- **Initial Operator Account**: `hsmutil`
- **Default Password**: `password` (SHA-512 crypt: `$6$saltsalt$qFmFH.bQmmtXzyBY0s9v7Oicd2z4XSIecDzlB5KiA2/jctKu9YterLp8wwnSq.qc.eoxqOmSuNp2xS0ktL3nh/`)
- **Native PAM First-Login Rotation**: Shadow expiration flag is set to `sp_lstchg = 0` via `shadow_%.bbappend`. On first login, Linux PAM (`pam_unix.so` / `pam_pwquality.so`) natively intercepts the session, prompts for immediate password change, and strictly enforces complexity criteria before opening the user shell.
- **Streamlined First-Login Setup Wizard** (`first-login-wizard.sh`): Deduplicated to focus exclusively on keyboard layout (`loadkeys`) and system locale/UTC timezone configuration without redundant password loops.
- **Password Expiration**: 90-day maximum lifetime enforced via `PASS_MAX_DAYS 90` in `/etc/login.defs` and `/etc/shadow`.
- **Password Complexity Rules** (enforced natively by `pam_pwquality.so`):
  1. Minimum length of 10 characters (`minlen = 10`)
  2. At least 1 numeric digit (`dcredit = -1`)
  3. At least 1 uppercase letter (`ucredit = -1`)
  4. At least 1 special character (`ocredit = -1`)
  5. No 2 consecutive identical characters (`maxrepeat = 1`, e.g. `aa`, `11`, `!!`)
  6. No 3 sequential monotonic characters (`maxsequence = 2`, e.g. `abc`, `123`, `cba`, `321`)
- **Targeted Authentication State Persistence (`/data/etc`)**:
  - The root filesystem remains 100% read-only with an ephemeral RAM tmpfs overlay over `/etc`.
  - On first boot, `hsm-setup-volatile.sh` seeds `/data/etc` (`0700 root:root`) from the rootfs template with strict permissions (`0400 root:shadow` for shadow/gshadow, `0644 root:root` for passwd/group).
  - On subsequent boots, valid credentials from `/data/etc` are restored into the active `/etc` overlay, eliminating repetitive PAM password change prompts across reboots. Empty or corrupted files automatically fall back to the rootfs template.
  - A real-time systemd path unit (`hsm-persist-auth.path`) and oneshot service (`hsm-persist-auth.service`) monitor `/etc/{shadow,passwd,group,gshadow}`, atomically synchronizing updates via `hsm-sync-auth.sh` (using temporary files, `.bak` backups, and POSIX atomic renames) with `sync` flush.
  - Persistent home directory mounting (`LABEL=homefs` on `/home`) preserves operator dotfiles (`.wizard_completed`, `.keymap`) across power cycles without ephemeral tmpfs masking.

### 2.2 Boot Visibility, Console Noise Suppression & U-Boot Network Hardening

- **Complete Kernel Network Protocol Stripping**:
  - All IPv4 (`# CONFIG_INET is not set`) and IPv6 (`# CONFIG_IPV6 is not set`) protocol families and Netfilter packet filtering (`# CONFIG_NETFILTER is not set`, `# CONFIG_NF_TABLES is not set`) are completely stripped from the kernel defconfig fragment `hardened.cfg`.
  - Base socket infrastructure (`CONFIG_NET=y`) and UNIX domain sockets (`CONFIG_UNIX=y`) are preserved for local `systemd` and `udev` IPC.
  - Any call to `socket(AF_INET, ...)` returns `EAFNOSUPPORT`. Obsolete user-space `nftables` utilities are purged from image recipes.
- **Complete U-Boot Network Subsystem Deactivation (`no-net.cfg`)**:
  - In `recipes-bsp/u-boot/files/no-net.cfg`, `CONFIG_NET` and all network commands (`CONFIG_CMD_DHCP`, `CONFIG_CMD_PING`, `CONFIG_CMD_TFTPBOOT`, `CONFIG_CMD_NFS`, `CONFIG_CMD_NET`, `CONFIG_NETDEVICES`) are completely compiled out of U-Boot.
  - Eliminates network attack surface during bootloader initialization, enforcing the zero-network physical air-gap continuously from power-on through OS runtime.
- **Framebuffer Boot Logo Suppression**:
  - Unsets `# CONFIG_LOGO is not set` in kernel defconfig fragment `hardened.cfg`.
  - Injects `logo.nologo vt.global_cursor_default=1` into kernel cmdline across both dev and prod images.
  - Suppresses VideoCore splash via `disable_splash=1` and `DISABLE_RPI_BOOT_LOGO = "1"`.
- **Clean Console Hardening (`clean-console.bb`)**:
  - Installs `/etc/systemd/system.conf.d/10-clean-console.conf` (`LogLevel=notice`, `LogTarget=journal`, `ShowStatus=no`, `LogColor=no`) suppressing systemd service startup notifications and watchdog chatter on physical monitor `tty1`.
  - Installs `/etc/sysctl.d/20-quiet-console.conf` enforcing `kernel.printk = 1 1 1 1`, silencing all non-emergency kernel messages.
- **Development Build (`dev`, `HSM_DEV_MODE = "1"`)**:
  - Dual-console kernel boot logging on HDMI and UART:
    `console=serial0,115200 console=tty1 loglevel=7 debug earlyprintk logo.nologo vt.global_cursor_default=1`
  - Interactive U-Boot console (`CONFIG_BOOTDELAY=2`) with RAUC boot diagnostics and autoboot countdown prompt.
- **Production Air-Gapped Build (`prod`, `HSM_DEV_MODE = "0"`)**:
  - Silent kernel boot on HDMI suppressing serial UART output:
    `quiet loglevel=0 console=tty1 fsck.mode=skip logo.nologo vt.global_cursor_default=1`
  - Hardened non-interactive silent U-Boot (`CONFIG_BOOTDELAY=-2`, `CONFIG_SILENT_CONSOLE=y`, `CONFIG_SYS_DEVICE_NULLDEV=y`, `CONFIG_SILENT_U_BOOT_ONLY=y`, `silent=1`), suppressing all RAUC diagnostic echo messages.

### 2.3 Hardware Real-Time Clock (HW-084 / DS3231) & Time Synchronization

Because the appliance operates in strict physical network isolation, Network Time Protocol (NTP) cannot function. To maintain reliable UTC time for X.509 certificates, RAUC bundle verification, audit logs, and PKCS#11 keys, the system integrates the **HW-084 (Maxim DS3231SN)** high-precision TCXO Real-Time Clock module over primary hardware I2C-1.

#### Hardware Pinout (Raspberry Pi 40-Pin Header via Waveshare HAT Passthrough)

| HW-084 Pin | Physical Pin | BCM GPIO / Function | Signal Type | Description |
| :--- | :--- | :--- | :--- | :--- |
| **VCC** | **Pin 1** | `3V3 Power` | 3.3V DC Power | Regulated 3.3V supply from PMIC |
| **GND** | **Pin 9** | `Ground` | 0V Reference | Common system ground |
| **SDA** | **Pin 3** | `GPIO 2 / I2C1_SDA` | I2C Data | Serial data with 1.8kΩ hardware pull-up |
| **SCL** | **Pin 5** | `GPIO 3 / I2C1_SCL` | I2C Clock | Serial clock with 1.8kΩ hardware pull-up |

#### Kernel & Firmware Configuration
- **Kernel Subsystem (`hardened.cfg`)**: `CONFIG_RTC_CLASS=y`, `CONFIG_RTC_DRV_DS1307=y`, `CONFIG_RTC_HCTOSYS=y`, `CONFIG_RTC_HCTOSYS_DEVICE="rtc0"`, `CONFIG_I2C=y`, `CONFIG_I2C_CHARDEV=y`, `CONFIG_I2C_BCM2835=y`.
- **Firmware Overlays (`rpi-config_%.bbappend`)**: `ENABLE_I2C = "1"` (`dtparam=i2c_arm=on`) and `dtoverlay=i2c-rtc,ds3231`.
- **Hardware Diagnostics**: `i2c-tools` is included in image recipes; verify via `i2cdetect -y 1` (`UU` at address `0x68`).

#### RTC-Aware Login Clock Setup (`clock-setup.sh`)
- On console login, `clock-setup.sh` inspects `/dev/rtc0` via `hwclock -u -r`.
- If healthy: Displays `[OK] Hardware RTC detected (/dev/rtc0): active and synchronized` and prompts `(or Enter to keep)`. Pressing `[Enter]` retains the hardware time without typing.
- If uninitialized or drifted: Typing a timestamp `YYYY-MM-DD HH:MM:SS` invokes setuid root helper `/usr/local/bin/hsm-set-date`, atomically updating the kernel clock (`settimeofday`) and the hardware DS3231 registers (`ioctl(RTC_SET_TIME)`).

### 2.4 Appliance Identity, History Conditioning & Tooling Alignment (gphsm)

- **Environment-Conditioned Hostnames**:
  - Production builds (`hsm-image-prod.bb`) configure `hostname:pn-base-files = "piKMS"` (prompt: `hsmutil@piKMS:~$`).
  - Development builds (`hsm-image-dev.bb`) configure `hostname:pn-base-files = "piKMS-dev"` (prompt: `hsmutil@piKMS-dev:~$`).
  - Sets `/etc/hostname` and loopback entries in `/etc/hosts` to eliminate operational environment ambiguity.
- **Session History Deactivation**:
  - In production mode (`HSM_DEV_MODE=0`), `/etc/profile.d/99-hsm-history.sh` enforces `HISTFILE=/dev/null`, `HISTSIZE=0`, `HISTFILESIZE=0`, and `set +o history` to eliminate forensic command, credential, or PIN leakage.
  - Development mode (`HSM_DEV_MODE=1`) retains standard interactive bash history logging in `/home/hsmutil/.bash_history`.
- **Canonical CLI Tooling (`gphsm`)**:
  - Packaged via `recipes-support/gphsm/gphsm.bb` into `/usr/local/bin/gphsm` as the primary host CLI/TUI management utility with dual local/git build workflows.
  - The legacy `hsmutil` symlink has been permanently eliminated from `/usr/local/bin` and package metadata.
  - The operator account remains `hsmutil:users` with home directory `/home/hsmutil`, preserving user permissions and automated script paths.

---

## 3. Directory Layout

```text
hsm-yocto-offgrid-rpi/
├── Makefile                      # Build orchestration targets
├── kas-project.yml               # Base Kas configuration (Blacksail layers, hostname: piKMS)
├── kas-dev.yml                   # Dev image overlay (sudo, debug ports)
├── kas-prod.yml                  # Hardened production image overlay
├── LICENSE                       # MIT License
├── README.md                     # This file
├── build/                        # Encapsulated build output (git-ignored)
│   ├── downloads/                # BitBake source archives
│   ├── repos/                    # Cloned Kas layer repositories
│   ├── sstate-cache/             # Shared state cache
│   └── tmp/                      # Case-sensitive APFS/ext4 temporary build dir
├── keys/                         # RAUC update signing certificates & keys
│   ├── rauc-ca.cert.pem          # Public CA embedded into target image
│   ├── rauc-ca.key.pem           # CA private key (git-ignored)
│   ├── development-signing.cert.pem
│   ├── development-signing.key.pem
│   └── README.md
├── meta-hsm-os/                  # Custom Yocto Layer
│   ├── conf/
│   │   └── layer.conf            # Layer configuration (blacksail compatibility)
│   ├── classes/
│   │   └── rauc-integration.bbclass # Raspberry Pi RAUC A/B integration class
│   ├── recipes-bsp/
│   │   ├── bootfiles/            # rpi-cmdline.bbappend, rpi-config_%.bbappend
│   │   ├── rpi-u-boot-scr/       # U-Boot dual-slot boot script (boot.cmd.in)
│   │   └── u-boot/               # u-boot_%.bbappend (no-net.cfg, silent-boot.cfg, squashfs.cfg)
│   ├── recipes-core/
│   │   ├── base-files/           # base-files_%.bbappend (hostname: piKMS, /data fstab)
│   │   ├── clean-console/        # 10-clean-console.conf & 20-quiet-console.conf (systemd & printk silence)
│   │   ├── images/               # hsm-image-base, hsm-image-dev, hsm-image-prod
│   │   ├── init-wizard/          # First-login wizard (loadkeys, timezone) & date prompt
│   │   ├── systemd-journald-airgap/ # Silent journald configuration
│   │   ├── udev/                 # raspberrypi-rauc.rules (RAUC slot symlinks)
│   │   ├── users/                # hsmutil user configuration
│   │   └── volatile-storage/     # Ephemeral tmpfs & /data/etc targeted auth persistence (hsm-sync-auth)
│   ├── recipes-extended/
│   │   ├── libpwquality/         # PAM pwquality configuration & complexity rules
│   │   ├── pam/                  # libpam_%.bbappend (pam configuration)
│   │   ├── shadow/               # shadow / shadow-sysroot (sp_lstchg=0, PASS_MAX_DAYS 90)
│   │   └── sudo/                 # sudoers privilege configuration for dev
│   ├── recipes-kernel/
│   │   ├── linux/                # Kernel defconfig hardening fragment (hardened.cfg, rauc.cfg)
│   │   └── nrf52840-hsm-kmod/    # Dedicated out-of-tree kernel driver (Linux 6.12+ llseek compat)
│   ├── recipes-rauc/
│   │   └── bundles/              # RAUC update bundle recipe (.raucb)
│   ├── recipes-support/
│   │   ├── gphsm/                # Bitbake recipe packaging gphsm binary & hsmutil symlink
│   │   ├── rauc/                 # RAUC system.conf and USB installer service
│   │   └── usb-mount/            # Automount udev rules for storage
│   └── wic/
│       └── sdimage-dual-raspberrypi.wks.in # Dual-slot A/B WIC partition template
└── scripts/
    ├── run-kas.sh                # Containerized Kas launcher
    ├── create-rauc-bundle.sh     # Offline signed bundle builder
    ├── flash-sd.sh               # SD card raw flasher
    ├── generate-rauc-keys.sh     # Key generation script
    ├── test-password-validator.sh # Password complexity validator test suite (14 test cases)
    └── verify-security-configs.sh # Security configuration assertions (19 checks)
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

### Workspace Cleanliness & Teardown

```bash
# Clean compilation output directory (preserves downloads, sstate-cache, and cloned layers)
make clean

# Nuclear distclean: completely purges build/, downloads/, sstate-cache/, checked-out
# Kas layer repositories, and forcefully removes container volume rpi_yocto_hsm_tmp
make distclean
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

---

## 7. Automated Security & Configuration Verification

The repository includes automated test suites to verify password complexity enforcement and security configurations prior to image builds:

```bash
# 1. Run the interactive password validator test suite (14 test cases)
./scripts/test-password-validator.sh

# 2. Run the security configuration verifier (19 automated assertions)
./scripts/verify-security-configs.sh
```

---

## 8. Architecture Decision Records (ADRs) & Knowledge Vault

Key architectural decisions governing this repository are formalized in the central Obsidian vault [`hsm-obsidian`](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian):

- [ADR-0005: Custom BitBake img Image Type via WIC Rename](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Architecture/Decisions/ADR-0005%20-%20Custom%20BitBake%20img%20Image%20Type%20via%20WIC%20Rename.md)
- [ADR-0007: Decompose Poky into openembedded-core, meta-yocto and bitbake](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Architecture/Decisions/ADR-0007%20-%20Decompose%20Poky%20into%20openembedded-core%20meta-yocto%20and%20bitbake.md)
- [ADR-0008: Internalize RPi RAUC Integration into meta-hsm-os](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Architecture/Decisions/ADR-0008%20-%20Internalize%20RPi%20RAUC%20Integration%20into%20meta-hsm-os.md)
- [ADR-0009: Kernel Driver llseek Version Guard and UNPACKDIR Migration](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Architecture/Decisions/ADR-0009%20-%20Kernel%20Driver%20llseek%20Version%20Guard%20and%20UNPACKDIR%20Migration.md)
- [ADR-0010: Kernel Boot Console Multiplexing and Command Line Specialization](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Architecture/Decisions/ADR-0010%20-%20Kernel%20Boot%20Console%20Multiplexing%20and%20Command%20Line%20Specialization.md)
- [ADR-0011: Silent Non-Interactive U-Boot Bootloader Hardening](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Architecture/Decisions/ADR-0011%20-%20Silent%20Non-Interactive%20U-Boot%20Bootloader%20Hardening.md)
- [ADR-0012: PAM pwquality Password Complexity and Expiration Policy](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Architecture/Decisions/ADR-0012%20-%20PAM%20pwquality%20Password%20Complexity%20and%20Expiration%20Policy.md)
- [ADR-0021: Hardware I2C-1 Bus Mapping for HW-084 DS3231 RTC Module](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Architecture/Decisions/ADR-0021%20-%20Hardware%20I2C-1%20Bus%20Mapping%20for%20HW-084%20DS3231%20RTC%20Module.md)
- [ADR-0022: RTC-Aware Informational Login Prompt with Transactional Hardware Clock Sync](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Architecture/Decisions/ADR-0022%20-%20RTC-Aware%20Informational%20Login%20Prompt%20with%20Transactional%20Hardware%20Clock%20Sync.md)
- [ADR-0023: Container Volume and Workspace Cache Purging during Distclean](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Architecture/Decisions/ADR-0023%20-%20Container%20Volume%20and%20Workspace%20Cache%20Purging%20during%20Distclean.md)
- [ADR-0024: Native Shadow PAM Password Expiration vs First-Login Wizard Deduplication](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Architecture/Decisions/ADR-0024%20-%20Native%20Shadow%20PAM%20Password%20Expiration%20vs%20First-Login%20Wizard%20Deduplication.md)
- [ADR-0025: Complete U-Boot Network Subsystem Deactivation in Air-Gapped Appliance](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Architecture/Decisions/ADR-0025%20-%20Complete%20U-Boot%20Network%20Subsystem%20Deactivation%20in%20Air-Gapped%20Appliance.md)
- [ADR-0026: HDMI Console Noise Suppression and Log Level Hardening](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Architecture/Decisions/ADR-0026%20-%20HDMI%20Console%20Noise%20Suppression%20and%20Log%20Level%20Hardening.md)
- [ADR-0027: Appliance Identity Standardization to piKMS and CLI Packaging Alignment to gphsm](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Architecture/Decisions/ADR-0027%20-%20Appliance%20Identity%20Standardization%20to%20piKMS%20and%20CLI%20Packaging%20Alignment%20to%20gphsm.md)
- [ADR-0028: Complete Kernel Network Protocol Stripping (Elimination of PF_INET and PF_INET6)](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Architecture/Decisions/ADR-0028%20-%20Complete%20Kernel%20Network%20Protocol%20Stripping.md)
- [ADR-0029: Production Session History Suppression and Environment-Conditioned Hostnames](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Architecture/Decisions/ADR-0029%20-%20Production%20Session%20History%20Suppression%20and%20Environment-Conditioned%20Hostnames.md)
- [ADR-0030: Sub-Repository Workspace Cleanliness via Encapsulated Build Directory](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Architecture/Decisions/ADR-0030%20-%20Sub-Repository%20Workspace%20Cleanliness%20via%20Encapsulated%20Build%20Directory.md)
- [ADR-0031: gphsm Packaging Lifecycle and Complete Deprecation of hsmutil Symlink](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Architecture/Decisions/ADR-0031%20-%20gphsm%20Packaging%20Lifecycle%20and%20Complete%20Deprecation%20of%20hsmutil%20Symlink.md)
- [Air-Gapped RPi HSM OS Architecture](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Architecture/07%20-%20Air-Gapped%20RPi%20HSM%20OS%20Architecture.md)
- [Air-Gapped Time Synchronization and Hardware RTC Architecture](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Architecture/08%20-%20Air-Gapped%20Time%20Synchronization%20and%20Hardware%20RTC%20Architecture.md)
- [Build Lifecycle and Workspace Clean Routines](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Architecture/Build%20Lifecycle%20and%20Workspace%20Clean%20Routines.md)
- [HW-084 DS3231 Real-Time Clock Module Specification](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Hardware/HW-084%20DS3231%20Real-Time%20Clock%20Module.md)
- [Feature: Kernel Network Stripping, Clean Subrepo Architecture, Environment Conditioning, and gphsm Workflow](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/features/yocto-network-strip-clean-layout.md)
- [Feature: HSM Yocto OS Hardening, Clean Console, U-Boot Network Deactivation, and gphsm CLI Alignment](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/features/yocto-hardening-clean-console-pikms.md)
- [Feature: Yocto 6.1 (Blacksail), HW-084 (DS3231) RTC & Workspace Distclean](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/features/yocto-blacksail-rtc-and-distclean.md)
- [Technical Specification: Kernel Network Stripping, Clean Subrepo Architecture, Environment Conditioning, and gphsm Workflow](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Specification/Kernel%20Network%20Stripping,%20Clean%20Subrepo%20Architecture,%20Environment%20Conditioning,%20and%20gphsm%20Workflow.md)
- [Technical Specification: HSM Yocto OS Hardening, Clean Console, U-Boot Network Deactivation, and gphsm CLI Alignment](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Specification/HSM%20Yocto%20OS%20Hardening,%20Clean%20Console,%20U-Boot%20Network%20Deactivation,%20and%20gphsm%20CLI%20Alignment.md)
- [Technical Specification: Yocto 6.1 Blacksail Upgrade, HW-084 DS3231 RTC Integration and Workspace Distclean](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Specification/Yocto%206.1%20Blacksail%20Upgrade,%20HW-084%20DS3231%20RTC%20Integration%20and%20Workspace%20Distclean.md)
- [Implementation Plan: Kernel Network Stripping, Clean Subrepo Architecture, Environment Conditioning, and gphsm Workflow](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Plan/Kernel%20Network%20Stripping,%20Clean%20Subrepo%20Architecture,%20Environment%20Conditioning,%20and%20gphsm%20Workflow%20Implementation%20Plan.md)
- [Implementation Plan: HSM Yocto OS Hardening, Clean Console, U-Boot Network Deactivation, and gphsm CLI Alignment](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Plan/HSM%20Yocto%20OS%20Hardening,%20Clean%20Console,%20U-Boot%20Network%20Deactivation,%20and%20gphsm%20CLI%20Alignment%20Implementation%20Plan.md)
- [Implementation Plan: Yocto 6.1 Blacksail Upgrade, HW-084 DS3231 RTC Integration and Workspace Distclean](file:///Users/gpfister/Development/Projects/gpfister/nrf52840-hsm/hsm-obsidian/Plan/Yocto%206.1%20Blacksail%20Upgrade,%20HW-084%20DS3231%20RTC%20Integration%20and%20Workspace%20Distclean%20Implementation%20Plan.md)

---

## 9. Migration Note: Yocto 5.0 (Scarthgap) → 6.1 (Blacksail)

- `poky` was replaced by `openembedded-core`, `bitbake` (2.20) and `meta-yocto` in `kas-project.yml`.
- `meta-lts-mixins` and `meta-rauc-community` were dropped; the Raspberry Pi RAUC A/B integration (WIC layout, U-Boot patch/boot script, kernel `rauc.cfg`, `/data` fstab, udev ignore list) now lives inside `meta-hsm-os`.
- `meta-raspberrypi` and `meta-rauc` track `master` (no `blacksail` branch yet) with `LAYERSERIES_COMPAT` overrides in `kas-project.yml`.
- Deprecated `*_OPTED_OUT` variables have been eliminated in favor of strict `:remove` overrides (`DISTRO_FEATURES:remove = "sysvinit"`).
- Recipes use `${UNPACKDIR}` instead of `${WORKDIR}`; `debug-tweaks` was replaced by `allow-root-login post-install-logging` in the dev image.
- `nrf52840_hsm.c` guards `.llseek = noop_llseek` for kernels older than 6.12.
- After upgrading or modifying layer manifests, execute `make distclean` to atomically purge all stale layer checkouts, caches, and container volumes (`rpi_yocto_hsm_tmp`).
