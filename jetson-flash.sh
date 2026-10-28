#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$(readlink -f "$0")")"
source scripts/lib.sh
usage() {
cat <<'HELP'
Usage: ./jetson-flash.sh <command> [board]

  boards            List supported board profiles
  detect            Show which profiles match a Jetson connected in recovery mode
  download <board>  Download NVIDIA's BSP and sample rootfs into downloads/ (host only)
  build <board>     Build the Docker image for the board's Jetson Linux release
  check <board>     Check the board is visible in recovery mode inside the container
  prepare <board>   Extract the BSP and rootfs into work/ and apply NVIDIA binaries
  flash <board>     DESTRUCTIVE: erase and flash the board
  shell <board>     Open a shell in the board's container, in Linux_for_Tegra

Typical run: download, prepare, flash. See README.md.
HELP
}
require_docker() {
  command -v docker >/dev/null || { echo 'Docker is not installed.' >&2; exit 1; }
  docker compose version >/dev/null || { echo 'Docker Compose v2 is required.' >&2; exit 1; }
}
# apply_binaries.sh runs ARM64 binaries in a chroot. The container shares the host
# kernel, so qemu-aarch64 must be registered there; installing it in the image is not enough.
require_arm64_binfmt() {
  local entry=/proc/sys/fs/binfmt_misc/qemu-aarch64
  if [[ ! -r $entry ]] || ! grep -q '^enabled' "$entry"; then
    echo 'ARM64 binfmt (qemu-aarch64) is not registered on the host kernel.' >&2
    echo 'Register it, then retry:  docker run --privileged --rm tonistiigi/binfmt --install arm64' >&2
    exit 1
  fi
  grep -q '^flags:.*F' "$entry" || echo 'Warning: qemu-aarch64 binfmt lacks the F flag; chroot into the rootfs may fail.' >&2
}
list_boards() {
  local f
  printf '  %-16s %-9s %s\n' BOARD RELEASE DESCRIPTION
  for f in boards/*.conf; do
    (
      source "$f"
      printf '  %-16s %-9s %s%s\n' "$(basename "$f" .conf)" "$RELEASE" "$DESCRIPTION" "${TESTED:+  [tested]}"
    )
  done
}
detect() {
  local f matches
  matches=$(for f in boards/*.conf; do
    (
      source "$f"
      for id in "${RECOVERY_IDS[@]}"; do
        if lsusb -d "$id" >/dev/null 2>&1; then
          printf '  %-16s %s  %s\n' "$(basename "$f" .conf)" "$id" "$DESCRIPTION"
        fi
      done
    )
  done)
  if [[ -n $matches ]]; then
    echo 'Jetson in recovery mode found. Matching board profiles:'
    echo "$matches"
    return 0
  fi
  echo 'No Jetson in recovery mode found.' >&2
  if lsusb -d 0955:7020 >/dev/null 2>&1; then
    echo 'A running Jetson (0955:7020) is connected: put it in recovery mode first.' >&2
  fi
  return 1
}
# Each Jetson Linux release gets its own image, built from the Ubuntu version it supports.
run_container() {
  export UBUNTU_VERSION
  docker compose build -q flasher
  docker compose run --rm -e BOARD="$board" flasher "$@"
}

command=${1:-}
board=${2:-}
case "$command" in
  boards) list_boards; exit 0 ;;
  detect) detect; exit ;;
  download|build|check|prepare|flash|shell) load_board "$board" "$PWD" ;;
  *) usage; exit 2 ;;
esac
[[ $command == download ]] && exec bash scripts/download.sh "$board"
require_docker
case "$command" in
  build) export UBUNTU_VERSION; docker compose build flasher ;;
  check) run_container bash /workspace/scripts/check.sh ;;
  prepare)
    require_arm64_binfmt
    run_container bash /workspace/scripts/prepare.sh ;;
  flash)
    echo "WARNING: This ERASES all data on the ${DESCRIPTION}."
    read -r -p "Type the board name ($board) to confirm: " answer
    [[ "$answer" == "$board" ]] || { echo 'Cancelled'; exit 1; }
    run_container bash /workspace/scripts/flash.sh ;;
  shell) run_container bash -c "cd '${L4T_DIR/#$PWD//workspace}' 2>/dev/null || cd /workspace; exec bash" ;;
esac
