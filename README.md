# Jetson Docker Flasher

Flash or recover NVIDIA Jetson boards (Xavier, Orin and Thor) from **any modern Linux host**. NVIDIA's flashing tools run inside a Docker container that uses the Ubuntu version each Jetson Linux release supports, so you don't need a matching Ubuntu install or SDK Manager.

> **Tested only on the Jetson AGX Xavier Developer Kit** (internal eMMC, Jetson Linux 35.6.5 / JetPack 5.1.7), flashed from an Ubuntu 26.04 x86-64 host. The other board profiles follow NVIDIA's documented flash commands but have **not been tested**. Reports and fixes for other boards are welcome.

**Warning:** flashing erases everything on the target storage.

## TL;DR

```bash
# 1. Once per host boot: let the host kernel run ARM64 binaries
docker run --privileged --rm tonistiigi/binfmt --install arm64

# 2. Put the Jetson in recovery mode, connect its flashing USB-C port, then find your board
./jetson-flash.sh detect          # or: ./jetson-flash.sh boards

# 3. Download, prepare and flash (replace agx-xavier with your board)
./jetson-flash.sh download agx-xavier
./jetson-flash.sh prepare agx-xavier
./jetson-flash.sh flash agx-xavier    # ERASES the board; asks you to type the board name
```

Then complete Ubuntu's first-boot setup on the Jetson (HDMI + keyboard, or the USB serial console).

## Supported boards

| Board | Device and storage | Jetson Linux (JetPack) | Container | Tested |
|---|---|---|---|---|
| `agx-xavier` | Jetson AGX Xavier Developer Kit, internal eMMC | 35.6.5 (5.1.7) | Ubuntu 20.04 | **Yes** |
| `xavier-nx` | Jetson Xavier NX Developer Kit, SD card module | 35.6.5 (5.1.7) | Ubuntu 20.04 | No |
| `xavier-nx-emmc` | Jetson Xavier NX eMMC module on the developer kit carrier | 35.6.5 (5.1.7) | Ubuntu 20.04 | No |
| `agx-orin` | Jetson AGX Orin Developer Kit, internal eMMC | 39.2.1 (7.2.1) | Ubuntu 22.04 | No |
| `agx-orin-nvme` | Jetson AGX Orin Developer Kit, NVMe SSD | 39.2.1 (7.2.1) | Ubuntu 22.04 | No |
| `orin-nano` | Orin Nano / Orin NX on the Orin Nano Developer Kit, NVMe SSD | 39.2.1 (7.2.1) | Ubuntu 22.04 | No |
| `orin-nano-super` | As `orin-nano`, with the Super (MAXN SUPER) power configuration | 39.2.1 (7.2.1) | Ubuntu 22.04 | No |
| `orin-nano-sd` | Orin Nano / Orin NX on the Orin Nano Developer Kit, SD card | 39.2.1 (7.2.1) | Ubuntu 22.04 | No |
| `agx-thor` | Jetson AGX Thor Developer Kit (T5000), NVMe SSD | 39.2.1 (7.2.1) | Ubuntu 22.04 | No |
| `thor-t4000` | Jetson T4000 on the AGX Thor Developer Kit carrier, NVMe SSD | 39.2.1 (7.2.1) | Ubuntu 22.04 | No |

Each profile is a short file in [boards/](boards/) that names its release in [releases/](releases/). Xavier stops at JetPack 5; Orin and Thor use the newest release that supports them.

## Requirements

- An x86-64 Linux host with Docker Engine and the Compose v2 plugin. Your user must be able to run `docker` (for example by being in the `docker` group).
- `curl`, and `bzip2` or `lbzip2`, on the host for downloads.
- Free disk space: roughly **50 GB** for Xavier and **100 GB** for Orin/Thor. Downloads and extracted files stay in this folder.
- A USB data cable straight to the Jetson's flashing port. Avoid USB hubs.

## Step by step

### 1. Register ARM64 emulation on the host

`prepare` runs NVIDIA's `apply_binaries.sh`, which executes ARM64 programs inside the Jetson root filesystem. The container shares the host kernel, so the emulator must be registered **on the host**:

```bash
docker run --privileged --rm tonistiigi/binfmt --install arm64
cat /proc/sys/fs/binfmt_misc/qemu-aarch64   # expect "enabled" and a flags line containing F
```

This does not survive a reboot. You can use your distribution's QEMU user-mode binfmt package instead. `prepare` refuses to start if the emulator isn't registered.

### 2. Put the board in recovery mode

Connect power and a USB data cable to the board's flashing port (see your developer kit's user guide), then enter Force Recovery Mode:

- **AGX Xavier, AGX Orin and AGX Thor developer kits:** hold the RECOVERY button, press and release RESET (or power on), then release RECOVERY.
- **Xavier NX and Orin Nano/NX developer kits:** with power off, connect the FC REC pin to GND on the button header, power on, then remove the jumper.

Check what the host sees:

```bash
./jetson-flash.sh detect
```

This lists the board profiles whose recovery USB ID (`0955:xxxx`, shown by `lsusb` as `NVIDIA Corp. APX`) is connected. The debug serial interface (an FTDI chip on some kits) is not the recovery interface.

### 3. Download NVIDIA's files

```bash
./jetson-flash.sh download <board>
```

This fetches the release's **Driver Package (BSP)** and **Sample Root Filesystem** from NVIDIA (no login required) into `downloads/`. NVIDIA publishes no checksums, so the script checks each file's size against the server's and runs a bzip2 integrity test. If the download is interrupted, re-run the command to resume it.

### 4. Prepare

```bash
./jetson-flash.sh prepare <board>
```

This builds the container image for the release, extracts the BSP and rootfs into `work/<release>/Linux_for_Tegra/`, installs NVIDIA's flash prerequisites, and runs `apply_binaries.sh`. Boards that share a release share this folder, so you only prepare once per release.

### 5. Flash (erases the board)

```bash
./jetson-flash.sh check <board>   # optional: confirms the container can see the board
./jetson-flash.sh flash <board>
```

You must type the board name to confirm. The script then runs the profile's NVIDIA command inside the container. Xavier uses `flash.sh`; Orin and Thor use `l4t_initrd_flash.sh`. Output is saved to `logs/<board>-flash-<timestamp>.log`. Keep USB and power connected until it reports success.

### 6. First boot

The board reboots by itself after flashing. Complete Ubuntu's first-boot setup with a display and keyboard attached. With no display, the setup runs on the USB serial console. On the host:

```bash
picocom -b 115200 /dev/ttyACM0
```

Then check the release on the Jetson:

```bash
cat /etc/nv_tegra_release
uname -r
```

## Troubleshooting

- **`Exec format error` during `prepare`:** ARM64 emulation isn't registered on the host, or was lost after a reboot. Repeat step 1.
- **Board visible on the host but not in `check`:** make sure Docker can run privileged containers and that nothing else (a VM, another flashing tool) is holding the USB device.
- **`Cannot find an unused loop device`:** on the host, run `sudo modprobe loop` and check `/dev/loop-control` exists.
- **USB disconnects or timeouts:** use a direct, known-good data cable and avoid hubs. The board re-enumerates during flashing, which is expected.
- **Orin/Thor flash stalls waiting for the device:** `l4t_initrd_flash.sh` boots the board into a temporary initrd and flashes over a USB network link. If the host's NetworkManager grabs that interface, stop it from managing it: find the interface with `ip link` while the flash is waiting, then run `nmcli device set <interface> managed no`.
- **A missing tool or Perl/Python module:** add the Ubuntu package to the [Dockerfile](Dockerfile) list. The image installs only names that exist in its Ubuntu release, so one list serves 20.04 and 22.04.
- **Repeated failures:** flash from a native Ubuntu host that NVIDIA supports for that release. A container doesn't change the host kernel or its USB behaviour.

## Adding a board or release

Board profile, for example `boards/my-board.conf`:

```bash
DESCRIPTION='Human-readable name and storage'
RELEASE=r39.2.1                       # a file in releases/
RECOVERY_IDS=(0955:7023)              # recovery-mode USB IDs from NVIDIA's Quick Start
BOARD_CONFIG=jetson-agx-orin-devkit   # must exist as Linux_for_Tegra/<name>.conf
FLASH_CMD=(./l4t_initrd_flash.sh --erase-all jetson-agx-orin-devkit internal)
```

Release, for example `releases/r36.5.2.conf`: set `L4T_VERSION`, `JETPACK`, `UBUNTU_VERSION` (a host Ubuntu version NVIDIA supports for that release), `BSP_URL` and `ROOTFS_URL`. Take the flash commands and USB IDs from that release's Developer Guide Quick Start.

## How it works

- `jetson-flash.sh` runs on the host and starts a privileged container with the host's `/dev` and `/run/udev` bound in. Binding `/dev` keeps the board visible when it re-enumerates mid-flash, and host networking lets `l4t_initrd_flash.sh` reach the board over USB.
- One image per Ubuntu version (`jetson-docker-flash:ubuntu-20.04`, `:ubuntu-22.04`) is built on demand.
- The container runs as root with `USER=root` set, because NVIDIA's `flash.sh` checks `$USER` rather than the uid.
- NVIDIA's `l4t_flash_prerequisites.sh` runs in the same container as `prepare` and `flash`, because each `docker compose run --rm` starts from a clean image.
- Files in `work/` are owned by root, because the root filesystem must keep its ownership. Delete them with `sudo rm -rf work/`.
- This is **not an officially supported NVIDIA host configuration**. It works because the flashing tools are mostly userspace, but the container shares the host kernel, USB stack and loop devices.
- The container is privileged and has full access to host devices: use only NVIDIA's own downloads.

## References

- Jetson Linux archive: https://developer.nvidia.com/embedded/jetson-linux-archive
- Jetson Linux 35.6.5 Developer Guide: https://docs.nvidia.com/jetson/archives/r35.6.5/DeveloperGuide/index.html
- Jetson Linux 39.2.1 Quick Start: https://docs.nvidia.com/jetson/archives/r39.2.1/DeveloperGuide/IN/QuickStart.html
