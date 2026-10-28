# Shared helpers, sourced on the host and inside the container.

# load_board <name> <project root>: source the board profile and its release.
load_board() {
  local board=$1 root=$2
  if [[ -z $board || ! -f $root/boards/$board.conf ]]; then
    echo "Unknown board '${board}'. List boards with: ./jetson-flash.sh boards" >&2
    exit 2
  fi
  # shellcheck source=/dev/null
  source "$root/boards/$board.conf"
  # shellcheck source=/dev/null
  source "$root/releases/$RELEASE.conf"
  WORK_DIR=$root/work/$RELEASE
  L4T_DIR=$WORK_DIR/Linux_for_Tegra
}

# find_recovery_device: print the first of RECOVERY_IDS visible on USB.
find_recovery_device() {
  local id
  for id in "${RECOVERY_IDS[@]}"; do
    if lsusb -d "$id" >/dev/null 2>&1; then
      echo "$id"
      return 0
    fi
  done
  return 1
}

# install_prerequisites: run from Linux_for_Tegra inside the container. The image
# already has most packages; this catches anything a newer BSP adds. It must run in
# every container that needs them, because each `docker compose run --rm` starts clean.
install_prerequisites() {
  [[ -f tools/l4t_flash_prerequisites.sh ]] || return 0
  bash tools/l4t_flash_prerequisites.sh \
    || echo 'Warning: l4t_flash_prerequisites.sh failed; continuing with packages baked into the image.' >&2
}
