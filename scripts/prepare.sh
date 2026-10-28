#!/usr/bin/env bash
set -Eeuo pipefail
source /workspace/scripts/lib.sh
load_board "$BOARD" /workspace
bsp=/workspace/downloads/${BSP_URL##*/}
rootfs=/workspace/downloads/${ROOTFS_URL##*/}
for f in "$bsp" "$rootfs"; do
  [[ -f $f ]] || { echo "Missing $f. Run: ./jetson-flash.sh download $BOARD" >&2; exit 1; }
done
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"
if [[ ! -f Linux_for_Tegra/flash.sh ]]; then
  echo "Extracting BSP: ${bsp##*/}"
  tar xf "$bsp"
fi
[[ -f Linux_for_Tegra/$BOARD_CONFIG.conf ]] || { echo "Board config $BOARD_CONFIG.conf missing. Check the BSP package." >&2; exit 1; }
if [[ ! -f Linux_for_Tegra/rootfs/etc/os-release ]]; then
  echo "Extracting sample rootfs: ${rootfs##*/}"
  tar xpf "$rootfs" -C Linux_for_Tegra/rootfs
fi
cd Linux_for_Tegra
install_prerequisites
./apply_binaries.sh
echo "Preparation finished. Next: ./jetson-flash.sh flash $BOARD"
